import SwiftUI

enum DemoMode: String, CaseIterable, Identifiable {
    case withChrome = "With Safari UI"
    case fullscreen = "Fullscreen (No UI)"
    var id: String { rawValue }
}

struct RootView: View {
    @State private var session: DemoSession?

    var body: some View {
        ZStack {
            if let session {
                BrowserView(url: session.url, mode: session.mode) {
                    self.session = nil
                }
                .transition(.opacity)
            } else {
                LaunchView { url, mode in
                    withAnimation { session = DemoSession(url: url, mode: mode) }
                }
                .transition(.opacity)
            }
        }
    }
}

struct DemoSession: Equatable {
    let url: URL
    let mode: DemoMode
}

#Preview { RootView() }
