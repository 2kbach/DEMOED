import Foundation
import UIKit
import Photos

final class CaptureController: ObservableObject {
    @Published var isRecording = false
    @Published var lastMessage: String?

    private let recorder = DisplayLinkRecorder()

    private func post(_ msg: String?, recording: Bool? = nil) {
        DispatchQueue.main.async {
            if let msg { self.lastMessage = msg }
            if let r = recording { self.isRecording = r }
        }
    }

    // MARK: - Recording (CADisplayLink + AVAssetWriter at native resolution)

    func startRecording() {
        guard !recorder.isRecording else { return }
        recorder.windowProvider = {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }
        }
        do {
            _ = try recorder.start()
            post("Recording at native resolution", recording: true)
        } catch {
            post("Record failed: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard recorder.isRecording else { return }
        recorder.stop { [weak self] url, error in
            guard let self else { return }
            self.post(nil, recording: false)
            if let url {
                self.saveVideoToPhotos(url)
            } else {
                self.post("Stop failed: \(error?.localizedDescription ?? "unknown")")
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

    // MARK: - Screenshot

    func saveScreenshot(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        post("Screenshot saved")
    }
}
