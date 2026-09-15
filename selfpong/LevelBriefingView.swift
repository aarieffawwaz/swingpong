import SwiftUI

struct LevelBriefingView: View {
    let close: () -> Void
    let start: () -> Void

    var body: some View {
        ZStack {
            SkyBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    HStack {
                        SwingPongBrand(compact: true)
                        Spacer()
                        Text("LEVEL 1")
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .foregroundStyle(ArcadeTheme.navy)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(.white.opacity(0.78), in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("BEGINNER • 3 HITS")
                                    .font(.system(.caption, design: .rounded, weight: .heavy))
                                    .foregroundStyle(ArcadeTheme.mint)
                                Text("First Pop")
                                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                                    .foregroundStyle(ArcadeTheme.navy)
                                Text("Learn one gentle upward motion. The ball waits for you.")
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .foregroundStyle(ArcadeTheme.navy.opacity(0.70))
                            }
                            Spacer()
                            Button(action: close) {
                                Image(systemName: "xmark")
                                    .font(.headline.bold())
                                    .foregroundStyle(ArcadeTheme.navy)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .background(.white.opacity(0.82), in: Circle())
                            .accessibilityLabel("Close level")
                        }

                        phoneDemo

                        VStack(spacing: 12) {
                            instruction(number: 1, symbol: "iphone", title: "Hold Flat",
                                        detail: "Keep the screen facing the ceiling.", color: ArcadeTheme.sky)
                            instruction(number: 2, symbol: "hourglass", title: "Wait for HIT",
                                        detail: "The ball will stop inside the hit zone.", color: ArcadeTheme.gold)
                            instruction(number: 3, symbol: "arrow.up", title: "Pop Up Gently",
                                        detail: "Move the whole phone upward a little.", color: ArcadeTheme.coral)
                        }

                        Button(action: start) {
                            Label("START LEVEL", systemImage: "play.fill")
                        }
                        .buttonStyle(ArcadePrimaryButtonStyle())
                        .padding(.top, 4)

                        Label("No tilt needed • Unlimited retries", systemImage: "heart.fill")
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundStyle(ArcadeTheme.navy.opacity(0.62))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(22)
                    .arcadeGlass(cornerRadius: 34, opacity: 0.90)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
    }

    private var phoneDemo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(ArcadeTheme.sky.opacity(0.18))
            Capsule()
                .fill(ArcadeTheme.navy)
                .frame(width: 220, height: 54)
                .overlay(Capsule().stroke(.white, lineWidth: 5))
                .shadow(color: ArcadeTheme.navy.opacity(0.16), radius: 10, y: 8)
            Circle()
                .fill(ArcadeTheme.orange)
                .frame(width: 42, height: 42)
                .offset(y: -54)
            Image(systemName: "arrow.up")
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(ArcadeTheme.mint)
                .offset(y: -105)
        }
        .frame(height: 220)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold the phone flat and move it gently upward")
    }

    private func instruction(number: Int, symbol: String, title: String,
                             detail: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.23)).frame(width: 52, height: 52)
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(ArcadeTheme.navy)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(number). \(title)")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(ArcadeTheme.navy)
                Text(detail)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(ArcadeTheme.navy.opacity(0.64))
            }
            Spacer()
        }
        .padding(14)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

