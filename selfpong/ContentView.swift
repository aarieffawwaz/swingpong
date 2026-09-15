import Combine
import SwiftUI

struct ContentView: View {
    @State private var engine = GameEngine()
    private let displayTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.72, green: 0.89, blue: 1.0), .white],
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()

            GeometryReader { geometry in
                Canvas { context, size in
                    drawScene(context: &context, size: size)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            engine.setSimulatedTilt(translationX: value.translation.width,
                                                    translationY: value.translation.height)
                        }
                )
                .accessibilityLabel("Sky view showing the virtual ball")
            }

            Color(feedbackColor)
                .opacity(engine.flashIntensity * 0.28)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if engine.isInStrikeZone {
                VStack(spacing: 2) {
                    Text("HIT!")
                        .font(.system(size: 74, weight: .black, design: .rounded))
                    Text("POP UP NOW")
                        .font(.headline.bold())
                }
                .foregroundStyle(.orange)
                .shadow(color: .white, radius: 8)
                .padding(.horizontal, 30).padding(.vertical, 14)
                .background(.white.opacity(0.88), in: Capsule())
                .allowsHitTesting(false)
                .accessibilityLabel("Hit now. Pop the phone upward.")
            } else if engine.flashIntensity > 0.72 && engine.feedbackTone == .success {
                VStack(spacing: 2) {
                    Text("NICE!")
                        .font(.system(size: 66, weight: .black, design: .rounded))
                    Text("+1 BOUNCE").font(.headline.bold())
                }
                .foregroundStyle(.green)
                .shadow(color: .white, radius: 8)
                .allowsHitTesting(false)
            }

            VStack(spacing: 14) {
                topBar
                if engine.state != .ready && engine.state != .countdown {
                    predictionPanel
                }
                Spacer()
                instructions
                controls
            }
            .padding()
        }
        .onReceive(displayTimer) { engine.tick(at: $0) }
        .onAppear { engine.prepare() }
        .onDisappear { engine.stop() }
        .preferredColorScheme(.light)
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RALLY").font(.caption.bold()).foregroundStyle(.secondary)
                Text("\(engine.score)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Text("LEVEL \(engine.levelNumber)")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13).padding(.vertical, 7)
                    .background(.orange, in: Capsule())

                Text(engine.levelName)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(engine.isUsingSimulator ? "SIMULATOR" : (engine.modelIsReady ? "CORE ML LIVE" : "MODEL ERROR"))
                    .font(.caption2.bold())
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .foregroundStyle(.blue)
                    .background(.white.opacity(0.78), in: Capsule())
            }
        }
    }

    private var predictionPanel: some View {
        HStack(spacing: 12) {
            Image(systemName: engine.predictionLabel == "bounce" ? "checkmark.circle.fill" : "waveform")
                .font(.title2)
                .foregroundStyle(feedbackColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("MOTION CHECK").font(.caption2.bold()).foregroundStyle(.secondary)
                Text("\(engine.predictionLabel.capitalized)  \(engine.predictionConfidence, format: .percent.precision(.fractionLength(0)))")
                    .font(.headline).monospacedDigit()
                Text(engine.lastDecision).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(feedbackColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).stroke(feedbackColor.opacity(0.40), lineWidth: 1.5)
        }
        .accessibilityElement(children: .combine)
    }

    private var instructions: some View {
        VStack(spacing: 5) {
            Text(statusTitle).font(.title2.bold())
            Text(statusDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var controls: some View {
        switch engine.state {
        case .ready:
            readyControls
        case .countdown:
            VStack(spacing: 8) {
                Text("\(engine.countdownValue)")
                    .font(.system(size: 76, weight: .black, design: .rounded))
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())
                Text("Keep the phone flat and still").font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.white.opacity(0.90), in: RoundedRectangle(cornerRadius: 22))
        case .playing:
            if engine.isUsingSimulator {
                Button { engine.simulateBounce() } label: {
                    Label("Simulate Bounce", systemImage: "hand.tap.fill")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent).tint(.orange)
            } else {
                Label(engine.isInStrikeZone ? "HIT! Pop upward now" : "Wait for HIT!",
                      systemImage: engine.isInStrikeZone ? "hand.raised.fill" : "hourglass")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                    .padding(.horizontal)
                    .foregroundStyle(engine.isInStrikeZone ? .white : .primary)
                    .background(engine.isInStrikeZone ? .orange : .white.opacity(0.84),
                                in: RoundedRectangle(cornerRadius: 16))
            }
        case .checkingContact:
            ProgressView("Checking motion…").padding()
        case .gameOver:
            mainButton("Try Again", icon: "arrow.clockwise") { engine.restart() }
        }
    }

    private var readyControls: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(.blue.opacity(0.18), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: engine.levelAmount)
                    .stroke(engine.isPhoneReady ? .green : .blue,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: engine.isPhoneReady ? "checkmark" : "iphone")
                    .font(.system(size: 35, weight: .bold))
                    .foregroundStyle(engine.isPhoneReady ? .green : .blue)
            }
            .frame(width: 86, height: 86)

            VStack(spacing: 3) {
                Text(engine.isPhoneReady ? "Phone Ready" : "Place Phone Flat")
                    .font(.title2.bold())
                Text(engine.isPhoneReady
                     ? "The ball stays centered and waits for every hit."
                     : "Screen up, like you are holding a tray.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            mainButton(engine.isPhoneReady ? "Start Game" : "Hold Flat to Start",
                       icon: engine.isPhoneReady ? "play.fill" : "lock.fill") {
                engine.requestStart()
            }
            .disabled(!engine.isPhoneReady)
            .opacity(engine.isPhoneReady ? 1 : 0.48)
        }
        .padding()
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 22))
    }

    private var statusTitle: String {
        switch engine.state {
        case .ready: engine.isPhoneReady ? "Ready to play" : "First, hold it correctly"
        case .countdown: "Get ready"
        case .playing: engine.isInStrikeZone ? "Hit it now!" : "Follow the falling ball"
        case .checkingContact: "Was that a real bounce?"
        case .gameOver: "Ball dropped"
        }
    }

    private var statusDetail: String {
        switch engine.state {
        case .ready: engine.motionMessage
        case .countdown: "The ball launches when the countdown finishes."
        case .playing:
            engine.isUsingSimulator
                ? "Wait for HIT, then tap Simulate Bounce."
                : (engine.isInStrikeZone
                   ? "Make one gentle upward pop. The ball will wait for you."
                   : "Wait. No tilt is needed in Level 1.")
        case .checkingContact: "Motion heard. Core ML is deciding if it counts."
        case .gameOver: "Only motions accepted as a bounce by Core ML add a point."
        }
    }

    private var feedbackColor: Color {
        switch engine.feedbackTone {
        case .neutral: .blue
        case .ready, .success: .green
        case .rejected: .orange
        case .warning: .red
        }
    }

    private func mainButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.title2.bold()).frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(.borderedProminent).tint(.orange)
    }

    private func drawScene(context: inout GraphicsContext, size: CGSize) {
        for (index, position) in engine.ball.trail.enumerated() {
            let projected = SpatialEngine.project(position: position, rotation: engine.rotation, canvasSize: size)
            guard projected.isVisible else { continue }
            let point = projected.point
            let fraction = Double(index + 1) / Double(max(engine.ball.trail.count, 1))
            let diameter = max(4, projected.size * 0.17 * fraction)
            let rect = CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2,
                              width: diameter, height: diameter)
            context.opacity = 0.10 + fraction * 0.30
            context.fill(Path(ellipseIn: rect), with: .color(.orange))
        }
        context.opacity = 1

        let projection = SpatialEngine.project(position: engine.ball.position,
                                               rotation: engine.rotation,
                                               canvasSize: size)
        if projection.isVisible {
            drawBall(context: &context, projection: projection)
        } else {
            drawIndicator(context: &context, projection: projection)
        }
    }

    private func drawBall(context: inout GraphicsContext, projection: ProjectedBall) {
        let glowSize = projection.size * 1.55
        let glowRect = CGRect(x: projection.point.x - glowSize / 2,
                              y: projection.point.y - glowSize / 2,
                              width: glowSize, height: glowSize)
        context.opacity = 0.20
        context.fill(Path(ellipseIn: glowRect), with: .color(.orange))

        let rect = CGRect(x: projection.point.x - projection.size / 2,
                          y: projection.point.y - projection.size / 2,
                          width: projection.size, height: projection.size)
        context.opacity = 1
        context.fill(Path(ellipseIn: rect), with: .color(.orange))
        context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.9)), lineWidth: 3)

        let highlight = CGRect(x: rect.minX + rect.width * 0.20,
                               y: rect.minY + rect.height * 0.16,
                               width: rect.width * 0.22,
                               height: rect.height * 0.16)
        context.fill(Path(ellipseIn: highlight), with: .color(.white.opacity(0.75)))
    }

    private func drawIndicator(context: inout GraphicsContext, projection: ProjectedBall) {
        let point = projection.edgePoint
        let length = hypot(projection.direction.dx, projection.direction.dy)
        let dx = projection.direction.dx / max(length, 0.001)
        let dy = projection.direction.dy / max(length, 0.001)
        let perpendicular = CGVector(dx: -dy, dy: dx)
        let tip = CGPoint(x: point.x + dx * 13, y: point.y + dy * 13)
        let back = CGPoint(x: point.x - dx * 12, y: point.y - dy * 12)
        var arrow = Path()
        arrow.move(to: tip)
        arrow.addLine(to: CGPoint(x: back.x + perpendicular.dx * 11, y: back.y + perpendicular.dy * 11))
        arrow.addLine(to: CGPoint(x: back.x - perpendicular.dx * 11, y: back.y - perpendicular.dy * 11))
        arrow.closeSubpath()

        context.opacity = projection.indicatorOpacity
        context.fill(arrow, with: .color(.orange))

        let ring = CGRect(x: point.x - 23, y: point.y - 23, width: 46, height: 46)
        context.stroke(Path(ellipseIn: ring),
                       with: .color(projection.isBehind ? .blue : .orange),
                       style: StrokeStyle(lineWidth: projection.isBehind ? 4 : 2,
                                          dash: projection.isBehind ? [5, 4] : []))

        if projection.isBehind {
            var label = context.resolve(Text("BEHIND").font(.caption2.bold()).foregroundStyle(.blue))
            label.shading = .color(.blue)
            context.opacity = 0.9
            context.draw(label, at: CGPoint(x: point.x, y: point.y + 34), anchor: .center)
        }
        context.opacity = 1
    }
}

#Preview {
    ContentView()
}
