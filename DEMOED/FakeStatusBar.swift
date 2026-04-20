import SwiftUI

struct FakeStatusBar: View {
    var tint: Color = .primary

    var body: some View {
        HStack(alignment: .center) {
            Text("9:41")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.leading, 28)
            Spacer()
            HStack(spacing: 6) {
                signalBars
                wifiIcon
                batteryIcon
            }
            .foregroundStyle(tint)
            .padding(.trailing, 20)
        }
        .frame(height: 54)
        .padding(.top, 4)
    }

    private var signalBars: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: 3, height: CGFloat(4 + i * 2))
            }
        }
    }

    private var wifiIcon: some View {
        Image(systemName: "wifi")
            .font(.system(size: 15, weight: .semibold))
    }

    private var batteryIcon: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .stroke(lineWidth: 1)
                .frame(width: 24, height: 11)
            RoundedRectangle(cornerRadius: 1.5)
                .frame(width: 20, height: 7)
                .padding(.leading, 1.5)
            Rectangle()
                .frame(width: 1.5, height: 4)
                .offset(x: 24.5)
        }
    }
}
