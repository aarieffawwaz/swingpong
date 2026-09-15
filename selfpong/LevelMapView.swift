import SwiftUI

struct LevelMapView: View {
    let levelOneCompleted: Bool
    let back: () -> Void
    let selectLevelOne: () -> Void
    let showSettings: () -> Void

    private let levels = [
        (1, "First Pop", "figure.table.tennis"),
        (2, "Find the Rhythm", "metronome"),
        (3, "Gentle Rally", "arrow.up.and.down"),
        (4, "Tilt Training", "move.3d"),
        (5, "Edge Chase", "arrow.up.right.circle"),
        (6, "Sky Rally", "trophy.fill")
    ]

    var body: some View {
        ZStack {
            SkyBackground()

            VStack(spacing: 12) {
                HStack {
                    ArcadeIconButton(symbol: "chevron.left", label: "Back", action: back)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SKY COURT")
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .foregroundStyle(ArcadeTheme.orange)
                        Text("Level Journey")
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                            .foregroundStyle(ArcadeTheme.navy)
                    }
                    Spacer()
                    ArcadeIconButton(symbol: "gearshape.fill", label: "Settings", action: showSettings)
                }
                .padding(.horizontal, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(levels.enumerated()), id: \.element.0) { index, level in
                            levelRow(number: level.0, title: level.1, symbol: level.2,
                                     alignment: index.isMultiple(of: 2) ? .leading : .trailing)
                            if index < levels.count - 1 { pathSegment(reversed: index.isMultiple(of: 2)) }
                        }
                    }
                    .padding(.horizontal, 38)
                    .padding(.top, 10)
                    .padding(.bottom, 210)
                }
            }
            .safeAreaPadding(.top, 8)

            VStack {
                Spacer()
                currentLevelCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
    }

    private func levelRow(number: Int, title: String, symbol: String,
                          alignment: HorizontalAlignment) -> some View {
        HStack {
            if alignment == .trailing { Spacer() }
            Button {
                if number == 1 { selectLevelOne() }
            } label: {
                VStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(number == 1
                                  ? (levelOneCompleted ? ArcadeTheme.mint : ArcadeTheme.orange)
                                  : .white.opacity(0.55))
                            .frame(width: number == 1 ? 78 : 62, height: number == 1 ? 78 : 62)
                            .overlay(Circle().stroke(.white, lineWidth: 4))
                            .shadow(color: number == 1
                                    ? ArcadeTheme.orange.opacity(0.30)
                                    : ArcadeTheme.navy.opacity(0.08), radius: 12, y: 6)
                        Image(systemName: number == 1 ? symbol : "lock.fill")
                            .font(.system(size: number == 1 ? 28 : 21, weight: .bold))
                            .foregroundStyle(number == 1 ? .white : ArcadeTheme.navy.opacity(0.28))
                    }
                    Text("\(number). \(title)")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(ArcadeTheme.navy)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(.white.opacity(0.80), in: Capsule())
                }
            }
            .buttonStyle(.plain)
            .disabled(number != 1)
            if alignment == .leading { Spacer() }
        }
    }

    private func pathSegment(reversed: Bool) -> some View {
        Path { path in
            let startX = reversed ? 42.0 : 210.0
            let endX = reversed ? 210.0 : 42.0
            path.move(to: CGPoint(x: startX, y: 0))
            path.addCurve(to: CGPoint(x: endX, y: 80),
                          control1: CGPoint(x: startX, y: 46),
                          control2: CGPoint(x: endX, y: 34))
        }
        .stroke(ArcadeTheme.navy.opacity(0.18),
                style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [7, 10]))
        .frame(height: 80)
    }

    private var currentLevelCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(levelOneCompleted ? "COMPLETED" : "READY TO PLAY")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .foregroundStyle(levelOneCompleted ? ArcadeTheme.mint : ArcadeTheme.orange)
                    Text("Level 1: First Pop")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(ArcadeTheme.navy)
                    Text("Make 3 gentle hits")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(ArcadeTheme.navy.opacity(0.62))
                }
                Spacer()
                PaddleMark(size: 54)
            }
            Button(action: selectLevelOne) {
                Label("OPEN LEVEL", systemImage: "play.fill")
            }
            .buttonStyle(ArcadePrimaryButtonStyle())
        }
        .padding(20)
        .arcadeGlass(cornerRadius: 30, opacity: 0.90)
    }
}

