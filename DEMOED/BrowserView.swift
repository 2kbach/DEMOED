import SwiftUI
import UIKit

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

    // For adaptive status bar (fullscreen mode only, can't inject JS into SFSafari)
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
            Color.black.ignoresSafeArea()

            // Content (webview or native Safari)
            VStack(spacing: 0) {
                // Spacer under the fake status bar — 62pt matches FakeStatusBar height
                Color.clear.frame(height: 62)
                content
            }
            .ignoresSafeArea(.container, edges: [.top, .bottom])

            // Fake status bar — pinned to top, overrides safe area
            FakeStatusBar(tint: statusBarTint, background: statusBarBackground)
                .animation(.easeInOut(duration: 0.25), value: web.topColor)
                .contentShape(Rectangle())
                .onTapGesture {
                    if capture.isRecording { capture.stopRecording() }
                }
                .ignoresSafeArea(.container, edges: .top)
                .frame(maxWidth: .infinity, alignment: .top)

            // Capture UI — hidden during recording AND during screenshot capture
            if showControls && !capture.isRecording && !isTakingScreenshot {
                captureControls
                    .padding(.trailing, 12)
                    .padding(.top, 76)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .transition(.opacity)
            }

            // Pre-record hint (shows before recording actually starts)
            if showStartHint {
                Text("Tap 9:41 to stop recording")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.8))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.top, 80)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .transition(.opacity)
            }

            // Toast — hidden during recording, screenshot, and while hint is showing
            if !capture.isRecording && !isTakingScreenshot && !showStartHint, let msg = capture.lastMessage {
                Text(msg)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.75))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
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
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if mode == .fullscreen {
            WebView(initialURL: url, state: web)
        } else {
            SafariView(url: url, onDone: onExit)
        }
    }

    // MARK: - Capture controls

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

    private func takeScreenshot() {
        isTakingScreenshot = true
        // Give SwiftUI a run loop tick to remove overlays before rendering.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if let window = UIApplication.shared.keyWindow {
                let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
                let image = renderer.image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                capture.saveScreenshot(image: image)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isTakingScreenshot = false
            }
        }
    }

    private func startRecording() {
        // Show the hint BEFORE recording begins so it doesn't appear in the video.
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
    var topViewController: UIViewController? {
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
