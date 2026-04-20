import SwiftUI

// Measurements match iPhone 15/16 Pro Dynamic Island status bar:
// Total top safe-area height ≈ 59pt. Clock/icons row sits on a ~44pt baseline
// centered to the Dynamic Island. Time font is SF Pro 17pt semibold.
struct FakeStatusBar: View {
    var tint: Color = .black
    var background: Color = .white

    var body: some View {
        ZStack {
            background.ignoresSafeArea(edges: .top)

            HStack {
                Text("9:41")
                    .font(.system(size: 17, weight: .semibold))
                    .kerning(0.2)
                    .foregroundStyle(tint)
                    .padding(.leading, 34)
                    .frame(width: 110, alignment: .center)

                Spacer()

                HStack(spacing: 5) {
                    signalBars
                    wifiIcon
                    batteryIcon
                }
                .foregroundStyle(tint)
                .padding(.trailing, 22)
                .frame(width: 110, alignment: .center)
            }
            .frame(height: 22)
            .offset(y: 4) // aligns with Dynamic Island vertical center
        }
        .frame(height: 54)
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
            RoundedRectangle(cornerRadius: 2.5)
                .stroke(lineWidth: 1)
                .opacity(0.35)
                .frame(width: 25, height: 12)
            RoundedRectangle(cornerRadius: 1.5)
                .frame(width: 21, height: 8)
                .padding(.leading, 2)
            Rectangle()
                .frame(width: 1.5, height: 4)
                .opacity(0.35)
                .offset(x: 25.5)
        }
    }
}
