import SwiftUI

// Dimensions pulled directly from Figma status bar component (node 1720:1721):
// 402x62 frame, 21pt top / 19pt bottom / 16pt horizontal padding,
// 154pt gap between Time (flex-1) and Levels (flex-1), each side centered,
// SF Pro Semibold 17pt / 22pt line-height.
struct FakeStatusBar: View {
    var tint: Color = .white
    var background: Color = .black

    var body: some View {
        ZStack {
            background
            HStack(spacing: 154) {
                // Time side
                Text("9:41")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 22)

                // Levels side
                HStack(spacing: 7) {
                    cellularIcon
                    wifiIcon
                    batteryIcon
                }
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 22)
            }
            .padding(.horizontal, 16)
            .padding(.top, 21)
            .padding(.bottom, 19)
        }
        .frame(height: 62)
    }

    // 19.2 x 12.226 — four ascending bars
    private var cellularIcon: some View {
        HStack(alignment: .bottom, spacing: 2) {
            bar(height: 4)
            bar(height: 6.5)
            bar(height: 9)
            bar(height: 12)
        }
        .frame(width: 19.2, height: 12.226)
    }

    private func bar(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 0.8)
            .frame(width: 3, height: height)
    }

    // 17.142 x 12.328
    private var wifiIcon: some View {
        Image(systemName: "wifi")
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 17.142, height: 12.328)
    }

    // 27.328 x 13 — body with cap on right
    private var batteryIcon: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(lineWidth: 1)
                    .opacity(0.4)
                RoundedRectangle(cornerRadius: 2)
                    .padding(1.5)
            }
            .frame(width: 25, height: 13)

            RoundedRectangle(cornerRadius: 0.5)
                .frame(width: 1.5, height: 4.5)
                .opacity(0.4)
        }
        .frame(width: 27.328, height: 13)
    }
}
