import SwiftUI
import UIKit

struct BrowserView: View {
    let url: URL
    let mode: DemoMode
    var onExit: () -> Void

    @StateObject private var web = WebState()
    @StateObject private var capture = CaptureController()
    @State private var addressText: String = ""
    @State private var editingAddress = false
    @State private var showControls = true
    @State private var toastOpacity: Double = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                FakeStatusBar()
                    .background(Color(.systemBackground))

                ZStack(alignment: .top) {
                    WebView(initialURL: url, state: web)
                        .ignoresSafeArea(edges: .bottom)

                    if web.isLoading {
                        ProgressView(value: web.progress)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                            .frame(height: 2)
                    }
                }

                if mode == .withChrome {
                    safariChrome
                        .background(.ultraThinMaterial)
                }
            }

            if showControls && !capture.isRecording {
                captureControls
                    .padding(.trailing, 12)
                    .padding(.top, 60)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
            }

            if capture.isRecording {
                Button(action: { capture.stopRecording() }) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 16, height: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                        )
                }
                .padding(.top, 66)
                .padding(.trailing, 18)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let msg = capture.lastMessage {
                Text(msg)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.75))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .opacity(toastOpacity)
                    .padding(.top, 70)
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
        .onAppear {
            addressText = url.absoluteString
        }
        .onChange(of: web.currentURL) { _, new in
            if !editingAddress, let new { addressText = new.absoluteString }
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
            Button(action: { capture.startRecording() }) {
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
        // Hide the capture controls before snapping so they don't appear in the image.
        withAnimation(.none) { showControls = false }
        DispatchQueue.main.async {
            if let window = UIApplication.shared.keyWindow {
                let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
                let image = renderer.image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                capture.saveScreenshot(image: image)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation { showControls = true }
            }
        }
    }

    private var safariChrome: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14, weight: .semibold))
                TextField("Search or enter website", text: $addressText, onEditingChanged: { editing in
                    editingAddress = editing
                    if editing { addressText = web.currentURL?.absoluteString ?? addressText }
                }, onCommit: submitAddress)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.go)
                    .foregroundStyle(.primary)
                if web.isLoading {
                    Button(action: { web.stop() }) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button(action: { web.reload() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
            .padding(.top, 8)

            HStack {
                Button(action: { web.goBack() }) {
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                }.disabled(!web.canGoBack)
                Spacer()
                Button(action: { web.goForward() }) {
                    Image(systemName: "chevron.right").font(.system(size: 20, weight: .semibold))
                }.disabled(!web.canGoForward)
                Spacer()
                Button(action: share) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 20, weight: .semibold))
                }
                Spacer()
                Image(systemName: "book").font(.system(size: 20, weight: .semibold)).foregroundStyle(.secondary.opacity(0.4))
                Spacer()
                Image(systemName: "square.on.square").font(.system(size: 20, weight: .semibold)).foregroundStyle(.secondary.opacity(0.4))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
    }

    private func submitAddress() {
        var s = addressText.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return }
        if !s.lowercased().hasPrefix("http") {
            if s.contains(" ") || !s.contains(".") {
                s = "https://www.google.com/search?q=" + (s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s)
            } else {
                s = "https://" + s
            }
        }
        if let u = URL(string: s) { web.load(u) }
        editingAddress = false
    }

    private func share() {
        guard let u = web.currentURL else { return }
        let av = UIActivityViewController(activityItems: [u], applicationActivities: nil)
        UIApplication.shared.topViewController?.present(av, animated: true)
    }
}

extension CaptureController {
    func saveScreenshot(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        Task { @MainActor in self.lastMessage = "Screenshot saved" }
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
