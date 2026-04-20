import SwiftUI
import UIKit
@preconcurrency import WebKit

final class WebState: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var currentURL: URL?
    @Published var title: String = ""
    @Published var topColor: UIColor = .white

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

        let userScript = WKUserScript(source: Coordinator.probeJS,
                                      injectionTime: .atDocumentEnd,
                                      forMainFrameOnly: true)
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(context.coordinator, name: "topColor")

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

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
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

        func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "topColor",
                  let str = message.body as? String,
                  let color = UIColor.fromCSS(str) else { return }
            DispatchQueue.main.async { self.state.topColor = color }
        }

        static let probeJS = """
        (function() {
          function readColor() {
            var meta = document.querySelector('meta[name="theme-color"]');
            if (meta && meta.content) return meta.content;
            var el = document.elementFromPoint(window.innerWidth/2, 2) || document.body;
            while (el) {
              var c = getComputedStyle(el).backgroundColor;
              if (c && c !== 'rgba(0, 0, 0, 0)' && c !== 'transparent') return c;
              el = el.parentElement;
            }
            return getComputedStyle(document.body).backgroundColor || 'rgb(255,255,255)';
          }
          function send() {
            try { window.webkit.messageHandlers.topColor.postMessage(readColor()); } catch(e) {}
          }
          send();
          window.addEventListener('scroll', send, { passive: true });
          window.addEventListener('load', send);
          var mo = new MutationObserver(send);
          mo.observe(document.documentElement, { attributes: true, childList: true, subtree: false });
          setInterval(send, 800);
        })();
        """
    }
}

extension UIColor {
    static func fromCSS(_ str: String) -> UIColor? {
        let s = str.trimmingCharacters(in: .whitespaces).lowercased()
        if s.hasPrefix("#") {
            var hex = String(s.dropFirst())
            if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
            guard hex.count == 6, let v = UInt32(hex, radix: 16) else { return nil }
            return UIColor(red: CGFloat((v >> 16) & 0xFF)/255,
                           green: CGFloat((v >> 8) & 0xFF)/255,
                           blue: CGFloat(v & 0xFF)/255, alpha: 1)
        }
        if s.hasPrefix("rgb") {
            let nums = s.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
                .split(separator: ",").map { Double($0) ?? 0 }
            guard nums.count >= 3 else { return nil }
            let a = nums.count >= 4 ? CGFloat(nums[3]) : 1
            return UIColor(red: CGFloat(nums[0])/255, green: CGFloat(nums[1])/255,
                           blue: CGFloat(nums[2])/255, alpha: a)
        }
        return nil
    }

    var isLight: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299*r + 0.587*g + 0.114*b
        return luminance > 0.6
    }
}
