import SwiftUI

struct HomeView: View {
    let levelOneCompleted: Bool
    let play: () -> Void
    let showSettings: () -> Void

    @State private var heroIsFloating = false

    var body: some View {
        ZStack {
            SkyBackground()

            VStack(spacing: 0) {
                HStack {
                    SwingPongBrand()
                    Spacer()
                    ArcadeIconButton(symbol: "gearshape.fill", label: "Settings", action: showSettings)
                }
                .padding(.horizontal, 20)

                Text("YOUR PHONE IS THE PADDLE")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(ArcadeTheme.navy)
                    .padding(.horizontal, 18)
                    .frame(height: 38)
                    .background(.white.opacity(0.78), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.9)))
                    .padding(.top, 24)

                Spacer(minLength: 12)

                hero
                    .offset(y: heroIsFloating ? -8 : 8)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                               value: heroIsFloating)

                Spacer(minLength: 16)

                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("LEVEL 1")
                                .font(.system(.caption, design: .rounded, weight: .heavy))
                                .foregroundStyle(ArcadeTheme.orange)
                            Text("First Pop")
                                .font(.system(.title2, design: .rounded, weight: .heavy))
                                .foregroundStyle(ArcadeTheme.navy)
                            Text("Goal: 3 gentle hits")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(ArcadeTheme.navy.opacity(0.65))
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { index in
                                Image(systemName: levelOneCompleted || index == 0 ? "star.fill" : "star")
                                    .foregroundStyle(levelOneCompleted || index == 0
                                                     ? ArcadeTheme.gold
                                                     : ArcadeTheme.navy.opacity(0.18))
                            }
                        }
                    }
                    .padding(20)
                    .arcadeGlass(cornerRadius: 26)

                    Button(action: play) {
                        HStack(spacing: 14) {
                            Text(levelOneCompleted ? "PLAY AGAIN" : "PLAY")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(ArcadePrimaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                Label("Hold flat • Pop upward to hit", systemImage: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(ArcadeTheme.navy.opacity(0.64))
                    .padding(.bottom, 4)
            }
            .safeAreaPadding(.vertical, 8)
        }
        .onAppear { heroIsFloating = true }
    }

    private var hero: some View {
        ZStack {
            Ellipse()
                .fill(ArcadeTheme.navy.opacity(0.10))
                .frame(width: 190, height: 34)
                .blur(radius: 9)
                .offset(y: 126)

            PaddleMark(size: 245, showsBall: false)

            Circle()
                .fill(
                    LinearGradient(colors: [ArcadeTheme.coral, ArcadeTheme.orange],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(alignment: .topLeading) {
                    Capsule().fill(.white.opacity(0.75)).frame(width: 25, height: 11)
                        .rotationEffect(.degrees(-28)).padding(12)
                }
                .overlay(Circle().stroke(ArcadeTheme.navy, lineWidth: 5))
                .frame(width: 72, height: 72)
                .shadow(color: ArcadeTheme.orange.opacity(0.42), radius: 16, y: 8)
                .offset(x: 92, y: -102)

            Path { path in
                path.move(to: CGPoint(x: 118, y: 76))
                path.addQuadCurve(to: CGPoint(x: 195, y: 14),
                                  control: CGPoint(x: 165, y: 70))
            }
            .trim(from: 0, to: 1)
            .stroke(ArcadeTheme.mint,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [8, 10]))
            .frame(width: 245, height: 210)
            .offset(x: -3, y: -17)
        }
        .frame(height: 300)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("An orange ping-pong paddle and bouncing ball")
    }
}

