import SwiftUI

struct LaunchView: View {
    @State private var urlText: String = "https://"
    @State private var mode: DemoMode = .withChrome
    @State private var history: [String] = URLHistory.load()
    @FocusState private var focused: Bool
    var onStart: (URL, DemoMode) -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)
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

                    if !history.isEmpty {
                        recentList
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
                             ? "Shows a native Safari UI with address bar and nav."
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

                    Spacer(minLength: 12)
                    Text("v1.3.0")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear { focused = true }
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !history.isEmpty {
                    Button("Clear") {
                        URLHistory.clear()
                        history = []
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 6) {
                ForEach(history, id: \.self) { item in
                    Button { urlText = item } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text(URLHistory.displayHost(item))
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                URLHistory.remove(item)
                                history = URLHistory.load()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
        URLHistory.add(u)
        onStart(u, mode)
    }
}
