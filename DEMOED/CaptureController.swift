import Foundation
import ReplayKit
import UIKit
import Photos
import AVFoundation

@MainActor
final class CaptureController: ObservableObject {
    @Published var isRecording = false
    @Published var lastMessage: String?

    private let recorder = RPScreenRecorder.shared()

    func startRecording() {
        guard !recorder.isRecording else { return }
        recorder.isMicrophoneEnabled = false
        recorder.startRecording { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.lastMessage = "Record failed: \(error.localizedDescription)"
                } else {
                    self?.isRecording = true
                    self?.lastMessage = "Recording…"
                }
            }
        }
    }

    func stopRecording() {
        guard recorder.isRecording else { return }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DEMOED-\(Int(Date().timeIntervalSince1970)).mov")
        try? FileManager.default.removeItem(at: outputURL)
        recorder.stopRecording(withOutput: outputURL) { [weak self] error in
            Task { @MainActor in
                self?.isRecording = false
                if let error {
                    self?.lastMessage = "Save failed: \(error.localizedDescription)"
                    return
                }
                self?.saveVideoToPhotos(outputURL)
            }
        }
    }

    private func saveVideoToPhotos(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in self?.lastMessage = "Photos access denied" }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                Task { @MainActor in
                    if success {
                        self?.lastMessage = "Video saved to Photos"
                    } else {
                        self?.lastMessage = "Video save error: \(error?.localizedDescription ?? "unknown")"
                    }
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    func takeScreenshot(of view: UIView) {
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        saveImageToPhotos(image)
    }

    private func saveImageToPhotos(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in self?.lastMessage = "Photos access denied" }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                Task { @MainActor in
                    if success {
                        self?.lastMessage = "Screenshot saved"
                    } else {
                        self?.lastMessage = "Screenshot error: \(error?.localizedDescription ?? "unknown")"
                    }
                }
            }
        }
    }
}
