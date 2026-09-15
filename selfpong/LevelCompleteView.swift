import SwiftUI

struct LevelCompleteView: View {
    let replay: () -> Void
    let nextLevel: () -> Void
    @State private var celebrates = false

    var body: some View {
        ZStack {
            SkyBackground()
            celebration
            VStack(spacing: 20) {
                Spacer()
                PaddleMark(size: 128).scaleEffect(celebrates ? 1 : 0.65)
                Text("LEVEL COMPLETE!")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(ArcadeTheme.navy).multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "star.fill").font(.system(size: 42))
                            .foregroundStyle(ArcadeTheme.gold)
                            .rotationEffect(.degrees(celebrates ? 0 : -25))
                            .scaleEffect(celebrates ? 1 : 0.2)
                            .animation(.spring(response: 0.55, dampingFraction: 0.62)
                                .delay(Double(index) * 0.12), value: celebrates)
                    }
                }
                VStack(spacing: 5) {
                    Text("3 / 3 HITS").font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(ArcadeTheme.mint)
                    Text("You learned the straight-up pop.")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(ArcadeTheme.navy.opacity(0.66))
                }
                .padding(20).frame(maxWidth: .infinity).arcadeGlass(cornerRadius: 26, opacity: 0.90)
                Spacer()
                Button("BACK TO LEVELS", action: nextLevel).buttonStyle(ArcadePrimaryButtonStyle())
                Button("Replay Level 1", action: replay)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(ArcadeTheme.navy).frame(minHeight: 48)
            }
            .padding(.horizontal, 24).safeAreaPadding(.vertical, 18)
        }
        .onAppear { celebrates = true }
    }

    private var celebration: some View {
        GeometryReader { geometry in
            ForEach(0..<22, id: \.self) { index in
                let x = CGFloat((index * 47) % 100) / 100 * geometry.size.width
                let y = CGFloat((index * 83) % 100) / 100 * geometry.size.height
                RoundedRectangle(cornerRadius: 3)
                    .fill([ArcadeTheme.orange, ArcadeTheme.mint, ArcadeTheme.gold,
                           ArcadeTheme.coral][index % 4])
                    .frame(width: 8, height: 18).rotationEffect(.degrees(Double(index * 31)))
                    .position(x: x, y: celebrates ? y : -30).opacity(0.75)
                    .animation(.easeOut(duration: 0.8).delay(Double(index % 7) * 0.05),
                               value: celebrates)
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
