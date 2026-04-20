import Foundation
import ReplayKit
import UIKit
import Photos

@MainActor
final class CaptureController: ObservableObject {
    @Published var isRecording = false
    @Published var lastMessage: String?

    private let recorder = RPScreenRecorder.shared()

    func startRecording() {
        guard !recorder.isRecording else { return }
        recorder.isMicrophoneEnabled = false
        recorder.startRecording { error in
            let msg = error.map { "Record failed: \($0.localizedDescription)" } ?? "Recording…"
            let started = error == nil
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if started { self.isRecording = true }
                    self.lastMessage = msg
                }
            }
        }
    }

    func stopRecording() {
        guard recorder.isRecording else { return }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DEMOED-\(Int(Date().timeIntervalSince1970)).mov")
        try? FileManager.default.removeItem(at: outputURL)
        recorder.stopRecording(withOutput: outputURL) { error in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.isRecording = false
                    if let error {
                        self.lastMessage = "Save failed: \(error.localizedDescription)"
                    } else {
                        self.saveVideoToPhotos(outputURL)
                    }
                }
            }
        }
    }

    private func saveVideoToPhotos(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self.lastMessage = "Photos access denied" }
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                let msg = success
                    ? "Video saved to Photos"
                    : "Video save error: \(error?.localizedDescription ?? "unknown")"
                try? FileManager.default.removeItem(at: url)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self.lastMessage = msg }
                }
            }
        }
    }

    func saveScreenshot(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        self.lastMessage = "Screenshot saved"
    }
}
