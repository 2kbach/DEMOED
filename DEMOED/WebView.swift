import SwiftUI
@preconcurrency import WebKit

final class WebState: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var currentURL: URL?
    @Published var title: String = ""

    weak var webView: WKWebView?

    func load(_ url: URL) { webView?.load(URLRequest(url: url)) }
    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func stop() { webView?.stopLoading() }
}

struct WebView: UIViewRepresentable {
    let initialURL: URL
    @ObservedObject var state: WebState

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let web = WKWebView(frame: .zero, configuration: config)
        web.allowsBackForwardNavigationGestures = true
        web.navigationDelegate = context.coordinator
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.showsVerticalScrollIndicator = false
        state.webView = web
        context.coordinator.observe(web)
        web.load(URLRequest(url: initialURL))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let state: WebState
        private var obs: [NSKeyValueObservation] = []

        init(state: WebState) { self.state = state }

        func observe(_ web: WKWebView) {
            obs.append(web.observe(\.canGoBack, options: [.new]) { [weak self] _, c in
                DispatchQueue.main.async { self?.state.canGoBack = c.newValue ?? false }
            })
            obs.append(web.observe(\.canGoForward, options: [.new]) { [weak self] _, c in
                DispatchQueue.main.async { self?.state.canGoForward = c.newValue ?? false }
            })
            obs.append(web.observe(\.isLoading, options: [.new]) { [weak self] _, c in
                DispatchQueue.main.async { self?.state.isLoading = c.newValue ?? false }
            })
            obs.append(web.observe(\.estimatedProgress, options: [.new]) { [weak self] _, c in
                DispatchQueue.main.async { self?.state.progress = c.newValue ?? 0 }
            })
            obs.append(web.observe(\.url, options: [.new]) { [weak self] _, c in
                DispatchQueue.main.async { self?.state.currentURL = c.newValue ?? nil }
            })
            obs.append(web.observe(\.title, options: [.new]) { [weak self] _, c in
                DispatchQueue.main.async { self?.state.title = (c.newValue ?? nil) ?? "" }
            })
        }
    }
}
