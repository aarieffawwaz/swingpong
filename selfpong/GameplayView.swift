import Combine
import SwiftUI

struct GameplayView: View {
    let engine: GameEngine
    let strongerFlash: Bool
    let reducedMotion: Bool
    let highContrast: Bool
    let pause: () -> Void
    let complete: () -> Void

    @State private var completionSent = false
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SkyBackground()
            GeometryReader { geometry in
                Canvas { context, size in drawScene(context: &context, size: size) }
                    .accessibilityLabel("The Level 1 ball stays in the middle of the sky")
            }
            ArcadeTheme.mint
                .opacity(engine.flashIntensity * (strongerFlash ? 0.38 : 0.22))
                .ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 14) {
                HStack {
                    SwingPongBrand(compact: true)
                    Spacer()
                    HitProgress(score: min(engine.score, GameEngine.levelOneTarget),
                                target: GameEngine.levelOneTarget)
                    ArcadeIconButton(symbol: "pause.fill", label: "Pause", action: pause)
                }
                Spacer()
                centerFeedback
                Spacer()
                bottomCard
            }
            .padding(.horizontal, 18)
            .safeAreaPadding(.vertical, 8)
        }
        .onReceive(timer) { engine.tick(at: $0) }
        .onChange(of: engine.score) { _, score in
            guard score >= GameEngine.levelOneTarget, !completionSent else { return }
            completionSent = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(reducedMotion ? 280 : 780))
                complete()
            }
        }
    }

    @ViewBuilder private var centerFeedback: some View {
        if engine.state == .countdown {
            VStack(spacing: 4) {
                Text("\(engine.countdownValue)")
                    .font(.system(size: 104, weight: .black, design: .rounded))
                    .foregroundStyle(ArcadeTheme.orange).contentTransition(.numericText())
                Text("KEEP IT FLAT").font(.system(.headline, design: .rounded, weight: .heavy))
            }
            .foregroundStyle(ArcadeTheme.navy)
        } else if engine.isInStrikeZone {
            VStack(spacing: 2) {
                Text("HIT!").font(.system(size: 76, weight: .black, design: .rounded))
                Text("POP UP NOW").font(.system(.headline, design: .rounded, weight: .heavy))
            }
            .foregroundStyle(.white).padding(.horizontal, 34).padding(.vertical, 14)
            .background(ArcadeTheme.orange, in: Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: 4))
            .shadow(color: ArcadeTheme.orange.opacity(0.35), radius: 16, y: 8)
            .accessibilityLabel("Hit now. Gently pop the phone upward.")
        } else if engine.flashIntensity > 0.55 && engine.feedbackTone == .success {
            VStack(spacing: 2) {
                Text("NICE!").font(.system(size: 68, weight: .black, design: .rounded))
                Text("+1 HIT").font(.system(.headline, design: .rounded, weight: .heavy))
            }
            .foregroundStyle(ArcadeTheme.mint).shadow(color: .white, radius: 8)
        }
    }

    @ViewBuilder private var bottomCard: some View {
        switch engine.state {
        case .ready: readinessCard
        case .countdown:
            instructionCard("Starting…", "Keep the screen facing the ceiling.", "iphone")
        case .playing, .checkingContact: playCard
        case .gameOver:
            VStack(spacing: 12) {
                instructionCard("No worries", "The ball will wait on your next try.", "heart.fill")
                Button("TRY AGAIN") { engine.resetToReady() }.buttonStyle(ArcadePrimaryButtonStyle())
            }
        }
    }

    private var readinessCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(ArcadeTheme.navy.opacity(0.10), lineWidth: 9)
                    Circle().trim(from: 0, to: engine.levelAmount)
                        .stroke(engine.isPhoneReady ? ArcadeTheme.mint : ArcadeTheme.orange,
                                style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: engine.isPhoneReady ? "checkmark" : "iphone")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(engine.isPhoneReady ? ArcadeTheme.mint : ArcadeTheme.navy)
                }
                .frame(width: 78, height: 78)
                VStack(alignment: .leading, spacing: 4) {
                    Text(engine.isPhoneReady ? "PHONE READY" : "HOLD PHONE FLAT")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                    Text(engine.isPhoneReady ? "Keep the screen facing up." : "Like a tray, screen toward the ceiling.")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(ArcadeTheme.navy.opacity(0.64))
                }
                Spacer()
            }
            Button("START") { engine.requestStart() }
                .buttonStyle(ArcadePrimaryButtonStyle()).disabled(!engine.isPhoneReady)
                .opacity(engine.isPhoneReady ? 1 : 0.44)
        }
        .foregroundStyle(ArcadeTheme.navy).padding(20).arcadeGlass(cornerRadius: 30, opacity: 0.92)
    }

    private var playCard: some View {
        VStack(spacing: 9) {
            if engine.isUsingSimulator {
                Button("SIMULATE HIT") { engine.simulateBounce() }.buttonStyle(ArcadePrimaryButtonStyle())
            } else {
                Label(playInstruction, systemImage: engine.isInStrikeZone ? "arrow.up" : "eye.fill")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(engine.isInStrikeZone ? ArcadeTheme.orange : ArcadeTheme.navy)
                    .frame(maxWidth: .infinity)
            }
            Text(playDetail).font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(ArcadeTheme.navy.opacity(0.62)).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18).padding(.vertical, 16).arcadeGlass(cornerRadius: 24, opacity: 0.90)
    }

    private var playInstruction: String {
        if engine.state == .checkingContact { return "GOT IT — CHECKING" }
        if engine.feedbackTone == .rejected { return "ALMOST — TRY AGAIN" }
        return engine.isInStrikeZone ? "POP UP GENTLY" : "WATCH THE BALL"
    }

    private var playDetail: String {
        if engine.feedbackTone == .rejected { return "Wait for HIT, then move the whole phone upward a little." }
        return engine.isInStrikeZone ? "The ball will wait. You do not need to rush." : "No tilt needed. Keep the phone flat."
    }

    private func instructionCard(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.title2.bold()).foregroundStyle(ArcadeTheme.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.headline, design: .rounded, weight: .heavy))
                Text(detail).font(.system(.footnote, design: .rounded, weight: .medium))
            }
            Spacer()
        }
        .foregroundStyle(ArcadeTheme.navy).padding(16).arcadeGlass(cornerRadius: 22, opacity: 0.90)
    }

    private func drawScene(context: inout GraphicsContext, size: CGSize) {
        if engine.state == .playing || engine.state == .checkingContact {
            // Continuity: one quiet path connects the ball's travel to the hit zone.
            var guide = Path()
            guide.move(to: CGPoint(x: size.width / 2, y: size.height * 0.18))
            guide.addLine(to: CGPoint(x: size.width / 2, y: size.height * 0.73))
            context.stroke(guide,
                           with: .color(ArcadeTheme.navy.opacity(0.10)),
                           style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [5, 12]))

            let zone = CGRect(x: size.width * 0.18, y: size.height * 0.69,
                              width: size.width * 0.64, height: 74)
            context.fill(Path(roundedRect: zone, cornerRadius: 37),
                         with: .color((engine.isInStrikeZone ? ArcadeTheme.orange : .white).opacity(0.22)))
            context.stroke(Path(roundedRect: zone, cornerRadius: 37),
                           with: .color((engine.isInStrikeZone ? ArcadeTheme.orange : ArcadeTheme.navy).opacity(0.18)),
                           style: StrokeStyle(lineWidth: 3, dash: [8, 9]))

            // Closure: only the paddle's top arc is shown. The hidden remainder is
            // easy to infer, while leaving the play area calm and uncluttered.
            let paddle = CGRect(x: size.width * 0.06, y: size.height * 0.88,
                                width: size.width * 0.88, height: size.height * 0.28)
            context.fill(Path(ellipseIn: paddle),
                         with: .linearGradient(
                            Gradient(colors: [ArcadeTheme.coral, ArcadeTheme.orange]),
                            startPoint: CGPoint(x: paddle.minX, y: paddle.minY),
                            endPoint: CGPoint(x: paddle.maxX, y: paddle.maxY)
                         ))
            context.stroke(Path(ellipseIn: paddle), with: .color(.white.opacity(0.80)), lineWidth: 4)
        }

        // Common fate: the trail uses the ball's own recorded positions, color,
        // and timing, so both are perceived as one moving object.
        for (index, position) in engine.ball.trail.enumerated() {
            let p = SpatialEngine.project(position: position, rotation: SpatialEngine.identityRotation(), canvasSize: size)
            guard p.isVisible else { continue }
            let fraction = Double(index + 1) / Double(max(engine.ball.trail.count, 1))
            let diameter = max(5, p.size * 0.18 * fraction)
            let rect = CGRect(x: size.width / 2 - diameter / 2, y: p.point.y - diameter / 2,
                              width: diameter, height: diameter)
            context.opacity = 0.08 + fraction * 0.24
            context.fill(Path(ellipseIn: rect), with: .color(ArcadeTheme.orange))
        }
        context.opacity = 1

        let p = SpatialEngine.project(position: engine.ball.position,
                                      rotation: SpatialEngine.identityRotation(), canvasSize: size)
        guard engine.state != .ready, p.isVisible else { return }
        let point = CGPoint(x: size.width / 2, y: p.point.y)
        let diameter = max(34, min(p.size, 88))
        let glow = CGRect(x: point.x - diameter * 0.72, y: point.y - diameter * 0.72,
                          width: diameter * 1.44, height: diameter * 1.44)
        context.fill(Path(ellipseIn: glow), with: .color(ArcadeTheme.orange.opacity(0.20)))
        let ball = CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2,
                          width: diameter, height: diameter)
        context.fill(Path(ellipseIn: ball), with: .color(ArcadeTheme.orange))
        context.stroke(Path(ellipseIn: ball), with: .color(highContrast ? ArcadeTheme.navy : .white),
                       lineWidth: highContrast ? 5 : 3)
        let shine = CGRect(x: ball.minX + diameter * 0.19, y: ball.minY + diameter * 0.14,
                           width: diameter * 0.24, height: diameter * 0.16)
        context.fill(Path(ellipseIn: shine), with: .color(.white.opacity(0.78)))
    }
}
