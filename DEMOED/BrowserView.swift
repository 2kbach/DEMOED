import SwiftUI
import UIKit
@preconcurrency import WebKit

struct BrowserView: View {
    let url: URL
    let mode: DemoMode
    var onExit: () -> Void

    @StateObject private var web = WebState()
    @StateObject private var capture = CaptureController()
    @State private var showControls = true
    @State private var isTakingScreenshot = false
    @State private var showStartHint = false
    @State private var toastOpacity: Double = 0

    private var statusBarBackground: Color {
        mode == .fullscreen ? Color(web.topColor) : .black
    }
    private var statusBarTint: Color {
        mode == .fullscreen
            ? Color(web.topColor.isLight ? UIColor.black : UIColor.white)
            : .white
    }

    var body: some View {
        ZStack(alignment: .top) {
            content
                .ignoresSafeArea()

            FakeStatusBar(tint: statusBarTint, background: statusBarBackground)
                .animation(.easeInOut(duration: 0.25), value: web.topColor)
                .contentShape(Rectangle())
                .onTapGesture {
                    if capture.isRecording { capture.stopRecording() }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .ignoresSafeArea(.all, edges: .top)

            if showControls && !capture.isRecording && !isTakingScreenshot {
                captureControls
                    .padding(.trailing, 12)
                    .padding(.top, 76)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .transition(.opacity)
            }

            if showStartHint {
                toastPill(text: "Tap 9:41 to stop recording")
                    .padding(.top, 80)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .transition(.opacity)
            }

            if !capture.isRecording && !isTakingScreenshot && !showStartHint,
               let msg = capture.lastMessage {
                toastPill(text: msg)
                    .opacity(toastOpacity)
                    .padding(.top, 80)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .onChange(of: capture.lastMessage) { _, _ in
                        withAnimation(.easeOut(duration: 0.2)) { toastOpacity = 1 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeIn(duration: 0.4)) { toastOpacity = 0 }
                        }
                    }
            }
        }
        .onTapGesture(count: 2) {
            withAnimation { showControls.toggle() }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { web.preferredTopInset = 62 }
    }

    @ViewBuilder
    private var content: some View {
        if mode == .fullscreen {
            WebView(initialURL: url, state: web)
        } else {
            SafariView(url: url, onDone: onExit)
        }
    }

    private var captureControls: some View {
        VStack(spacing: 10) {
            Button(action: takeScreenshot) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
            Button(action: startRecording) {
                Image(systemName: "record.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
        }
    }

    private func toastPill(text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.8))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    // MARK: - Screenshot

    private func takeScreenshot() {
        isTakingScreenshot = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard let window = UIApplication.shared.keyWindow else {
                isTakingScreenshot = false
                return
            }
            if mode == .fullscreen, let wk = web.webView {
                snapshotFullscreen(webView: wk, window: window)
            } else {
                capture.saveScreenshot(image: renderWindow(window))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isTakingScreenshot = false
                }
            }
        }
    }

    @MainActor
    private func snapshotFullscreen(webView: WKWebView, window: UIWindow) {
        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = true
        // snapshotWidth nil = use webView's actual width for native resolution
        webView.takeSnapshot(with: config) { [statusBarTint, statusBarBackground] snapshot, _ in
            let scale = window.screen.scale
            let windowSize = window.bounds.size

            // Render fake status bar into a UIImage at native scale
            let barRenderer = ImageRenderer(
                content: FakeStatusBar(tint: statusBarTint, background: statusBarBackground)
                    .frame(width: windowSize.width, height: 62)
            )
            barRenderer.scale = scale
            let barImage = barRenderer.uiImage

            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.opaque = true
            format.preferredRange = .extended
            let renderer = UIGraphicsImageRenderer(size: windowSize, format: format)
            let composed = renderer.image { _ in
                // Draw the webview snapshot filling the whole window (it was
                // already sized to fit under the status bar)
                if let snapshot {
                    let origin = CGPoint(x: 0, y: webView.frame.origin.y)
                    snapshot.draw(in: CGRect(origin: origin, size: webView.bounds.size))
                }
                // Draw the fake status bar at the top
                barImage?.draw(in: CGRect(x: 0, y: 0, width: windowSize.width, height: 62))
            }
            capture.saveScreenshot(image: composed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isTakingScreenshot = false
            }
        }
    }

    private func renderWindow(_ window: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        format.opaque = true
        format.preferredRange = .extended
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        return renderer.image { ctx in
            window.layer.render(in: ctx.cgContext)
        }
    }

    private func startRecording() {
        withAnimation(.easeOut(duration: 0.2)) { showStartHint = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.3)) { showStartHint = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                capture.startRecording()
            }
        }
    }
}

extension UIApplication {
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}
