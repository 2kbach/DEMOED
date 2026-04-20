import SwiftUI

struct LaunchView: View {
    @State private var urlText: String = "https://"
    @State private var mode: DemoMode = .withChrome
    @FocusState private var focused: Bool
    var onStart: (URL, DemoMode) -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 8) {
                    Text("DEMOED")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .tracking(2)
                    Text("Capture clean website demos")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("URL")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("https://example.com", text: $urlText)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focused)
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mode")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Mode", selection: $mode) {
                        ForEach(DemoMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(mode == .withChrome
                         ? "Shows a Safari-style address bar and nav buttons."
                         : "Pure webview, just the 9:41 status bar on top.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button(action: start) {
                    Text("Start Demo")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canStart ? Color.accentColor : Color.gray.opacity(0.4))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canStart)

                Spacer()
                Text("v1.0.0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
        }
        .onAppear { focused = true }
    }

    private var canStart: Bool { parsedURL != nil }

    private var parsedURL: URL? {
        var s = urlText.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, s != "https://", s != "http://" else { return nil }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "https://" + s
        }
        guard let u = URL(string: s), u.host != nil else { return nil }
        return u
    }

    private func start() {
        guard let u = parsedURL else { return }
        onStart(u, mode)
    }
}
