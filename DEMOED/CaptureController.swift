import Foundation
import ReplayKit
import UIKit
import Photos
import AVFoundation

final class CaptureController: ObservableObject {
    @Published var isRecording = false
    @Published var lastMessage: String?

    private let recorder = RPScreenRecorder.shared()
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var sessionStarted = false
    private var outputURL: URL?
    private let writeQueue = DispatchQueue(label: "com.demoed.writer")

    private func post(_ msg: String?, recording: Bool? = nil) {
        DispatchQueue.main.async {
            if let msg { self.lastMessage = msg }
            if let r = recording { self.isRecording = r }
        }
    }

    func startRecording() {
        guard !recorder.isRecording else { return }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DEMOED-\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: fileURL)
        self.outputURL = fileURL
        self.sessionStarted = false
        self.writer = nil
        self.videoInput = nil

        recorder.isMicrophoneEnabled = false
        recorder.startCapture { [weak self] buffer, type, error in
            guard let self, error == nil, type == .video else { return }
            guard CMSampleBufferDataIsReady(buffer) else { return }
            self.writeQueue.async {
                if self.writer == nil {
                    self.createWriter(for: buffer)
                }
                guard let w = self.writer, let input = self.videoInput else { return }
                if !self.sessionStarted {
                    if w.startWriting() {
                        w.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(buffer))
                        self.sessionStarted = true
                    } else { return }
                }
                if input.isReadyForMoreMediaData {
                    input.append(buffer)
                }
            }
        } completionHandler: { [weak self] error in
            guard let self else { return }
            if let error {
                self.post("Record failed: \(error.localizedDescription)")
            } else {
                self.post("Recording…", recording: true)
            }
        }
    }

    // Lazily create writer using the first buffer's actual pixel dimensions.
    // This ensures we write at whatever resolution ReplayKit delivers,
    // with no downscaling or letterboxing.
    private func createWriter(for buffer: CMSampleBuffer) {
        guard let fileURL = outputURL,
              let fmt = CMSampleBufferGetFormatDescription(buffer) else { return }
        let dims = CMVideoFormatDescriptionGetDimensions(fmt)
        let width = Int(dims.width)
        let height = Int(dims.height)

        do {
            let w = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
            let compression: [String: Any] = [
                AVVideoAverageBitRateKey: 50_000_000,
                AVVideoExpectedSourceFrameRateKey: 60,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ]
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: compression,
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true
            if w.canAdd(input) { w.add(input) }
            self.writer = w
            self.videoInput = input
        } catch {
            post("Writer setup failed: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard recorder.isRecording else { return }
        recorder.stopCapture { [weak self] _ in
            guard let self else { return }
            self.writeQueue.async {
                self.videoInput?.markAsFinished()
                guard let w = self.writer else {
                    self.post("No recording", recording: false)
                    return
                }
                w.finishWriting { [weak self] in
                    guard let self else { return }
                    let url = self.outputURL
                    self.writer = nil
                    self.videoInput = nil
                    self.outputURL = nil
                    if w.status == .completed, let url {
                        self.post(nil, recording: false)
                        self.saveVideoToPhotos(url)
                    } else {
                        self.post("Write failed: \(w.error?.localizedDescription ?? "unknown")", recording: false)
                    }
                }
            }
        }
    }

    private func saveVideoToPhotos(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard let self else { return }
            guard status == .authorized || status == .limited else {
                self.post("Photos access denied")
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                try? FileManager.default.removeItem(at: url)
                let msg = success
                    ? "Video saved to Photos"
                    : "Save error: \(error?.localizedDescription ?? "unknown")"
                self.post(msg)
            }
        }
    }

    func saveScreenshot(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        post("Screenshot saved")
    }
}
