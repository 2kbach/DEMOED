import Foundation
import UIKit
import AVFoundation
import QuartzCore

// Records the key window at native device resolution by snapshotting on each
// CADisplayLink tick and feeding frames into AVAssetWriter. Bypasses ReplayKit's
// 1920px system cap.
final class DisplayLinkRecorder: NSObject {
    enum RecorderError: Error {
        case noWindow
        case writerSetupFailed
        case writerStartFailed
    }

    var windowProvider: () -> UIWindow? = { nil }

    private var displayLink: CADisplayLink?
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var pixelSize: CGSize = .zero
    private var scale: CGFloat = 1
    private var started = false
    private var startTime: CFTimeInterval = 0

    var isRecording: Bool { displayLink != nil }

    func start() throws -> URL {
        guard let window = windowProvider() else { throw RecorderError.noWindow }
        let s = window.screen.scale
        let size = CGSize(
            width: floor(window.bounds.width * s),
            height: floor(window.bounds.height * s)
        )

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DEMOED-\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: fileURL)

        let w = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
        let compression: [String: Any] = [
            AVVideoAverageBitRateKey: 50_000_000,
            AVVideoExpectedSourceFrameRateKey: 60,
            AVVideoMaxKeyFrameIntervalKey: 60,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ]
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: compression,
        ]
        let inp = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        inp.expectsMediaDataInRealTime = true

        let bufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary,
        ]
        let ad = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: inp,
            sourcePixelBufferAttributes: bufferAttrs
        )
        guard w.canAdd(inp) else { throw RecorderError.writerSetupFailed }
        w.add(inp)

        guard w.startWriting() else {
            throw w.error ?? RecorderError.writerStartFailed
        }
        w.startSession(atSourceTime: .zero)

        self.writer = w
        self.input = inp
        self.adaptor = ad
        self.pixelSize = size
        self.scale = s
        self.started = false
        self.startTime = 0

        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        self.displayLink = link

        return fileURL
    }

    func stop(completion: @escaping (URL?, Error?) -> Void) {
        displayLink?.invalidate()
        displayLink = nil
        guard let writer, let input else {
            completion(nil, RecorderError.writerSetupFailed)
            return
        }
        input.markAsFinished()
        let url = writer.outputURL
        writer.finishWriting { [weak self] in
            DispatchQueue.main.async {
                let status = writer.status
                let err = writer.error
                self?.writer = nil
                self?.input = nil
                self?.adaptor = nil
                if status == .completed {
                    completion(url, nil)
                } else {
                    completion(nil, err)
                }
            }
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard let adaptor, let input, input.isReadyForMoreMediaData,
              let window = windowProvider(),
              let pool = adaptor.pixelBufferPool else { return }

        if !started {
            startTime = link.timestamp
            started = true
        }
        let elapsed = link.timestamp - startTime
        let pts = CMTime(seconds: elapsed, preferredTimescale: 600)

        var maybeBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &maybeBuffer)
        guard let buffer = maybeBuffer else { return }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue

        guard let ctx = CGContext(
            data: base,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return }

        // UIKit coords are top-left origin; CGContext is bottom-left. Flip & scale.
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: scale, y: -scale)

        UIGraphicsPushContext(ctx)
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        UIGraphicsPopContext()

        adaptor.append(buffer, withPresentationTime: pts)
    }
}
