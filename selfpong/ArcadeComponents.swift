import SwiftUI

enum ArcadeTheme {
    static let orange = Color("ArcadeOrange")
    static let coral = Color("ArcadeCoral")
    static let sky = Color("SkyBlue")
    static let mist = Color("SkyMist")
    static let navy = Color("MarineNavy")
    static let mint = Color("SuccessMint")
    static let gold = Color("SolarGold")
    static let error = Color("PopCoral")
}

struct SkyBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ArcadeTheme.sky, ArcadeTheme.mist],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(.white.opacity(0.26))
                .frame(width: 260)
                .blur(radius: 2)
                .offset(x: 150, y: -300)

            CloudShape()
                .fill(.white.opacity(0.58))
                .frame(width: 145, height: 58)
                .offset(x: -135, y: -235)

            CloudShape()
                .fill(.white.opacity(0.42))
                .frame(width: 118, height: 48)
                .offset(x: 150, y: 210)
        }
        .ignoresSafeArea()
    }
}

private struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: CGRect(x: 0, y: rect.height * 0.42,
                                      width: rect.width, height: rect.height * 0.58),
                            cornerSize: CGSize(width: rect.height * 0.30,
                                               height: rect.height * 0.30))
        path.addEllipse(in: CGRect(x: rect.width * 0.15, y: rect.height * 0.18,
                                   width: rect.width * 0.42, height: rect.height * 0.62))
        path.addEllipse(in: CGRect(x: rect.width * 0.43, y: 0,
                                   width: rect.width * 0.40, height: rect.height * 0.82))
        return path
    }
}

struct PaddleMark: View {
    var size: CGFloat = 42
    var showsBall = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.11)
                .fill(ArcadeTheme.navy)
                .frame(width: size * 0.23, height: size * 0.48)
                .offset(y: size * 0.33)
                .rotationEffect(.degrees(8))

            Circle()
                .fill(
                    LinearGradient(colors: [ArcadeTheme.coral, ArcadeTheme.orange],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(Circle().stroke(ArcadeTheme.navy, lineWidth: max(2, size * 0.045)))
                .frame(width: size * 0.72, height: size * 0.72)
                .shadow(color: ArcadeTheme.orange.opacity(0.30), radius: size * 0.12, y: size * 0.08)

            if showsBall {
                Circle()
                    .fill(ArcadeTheme.orange)
                    .overlay(Circle().stroke(.white, lineWidth: max(1, size * 0.03)))
                    .frame(width: size * 0.24, height: size * 0.24)
                    .offset(x: size * 0.31, y: -size * 0.30)
            }
        }
        .frame(width: size, height: size * 1.08)
        .accessibilityHidden(true)
    }
}

struct SwingPongBrand: View {
    var compact = false

    var body: some View {
        HStack(spacing: 9) {
            PaddleMark(size: compact ? 34 : 42)
            Text("Swing") + Text("Pong").foregroundStyle(ArcadeTheme.orange)
        }
        .font(.system(compact ? .headline : .title3, design: .rounded, weight: .heavy))
        .foregroundStyle(ArcadeTheme.navy)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("SwingPong")
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 28
    var opacity = 0.82

    func body(content: Content) -> some View {
        content
            .background(.white.opacity(opacity), in: RoundedRectangle(cornerRadius: cornerRadius,
                                                                       style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.90), lineWidth: 1)
            }
            .shadow(color: ArcadeTheme.navy.opacity(0.09), radius: 18, y: 8)
    }
}

extension View {
    func arcadeGlass(cornerRadius: CGFloat = 28, opacity: Double = 0.82) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, opacity: opacity))
    }
}

struct ArcadePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(
                LinearGradient(colors: [ArcadeTheme.coral, ArcadeTheme.orange],
                               startPoint: .top, endPoint: .bottom),
                in: Capsule()
            )
            .overlay(alignment: .top) {
                Capsule().fill(.white.opacity(0.40)).frame(height: 2).padding(.horizontal, 22)
            }
            .shadow(color: ArcadeTheme.orange.opacity(0.36), radius: 14, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct ArcadeIconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ArcadeTheme.navy)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .background(.white.opacity(0.78), in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.9)))
        .shadow(color: ArcadeTheme.navy.opacity(0.08), radius: 10, y: 5)
        .accessibilityLabel(label)
    }
}

struct HitProgress: View {
    let score: Int
    let target: Int

    var body: some View {
        HStack(spacing: 7) {
            Text("HITS")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(ArcadeTheme.navy.opacity(0.62))
            ForEach(0..<target, id: \.self) { index in
                Circle()
                    .fill(index < score ? ArcadeTheme.mint : ArcadeTheme.navy.opacity(0.10))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white.opacity(0.75), lineWidth: 1))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(.white.opacity(0.84), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hits: \(score) of \(target)")
    }
}

