import SwiftUI

struct PauseMenuView: View {
    let resume: () -> Void
    let restart: () -> Void
    let exitLevel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(.secondary.opacity(0.25)).frame(width: 42, height: 5)
            PaddleMark(size: 70)
            Text("GAME PAUSED")
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(ArcadeTheme.navy)
            Text("Your progress is safe.").foregroundStyle(.secondary)
            Button("RESUME", action: resume).buttonStyle(ArcadePrimaryButtonStyle())
            Button("Restart Level", action: restart).buttonStyle(.bordered)
            Button("Exit to Levels", role: .destructive, action: exitLevel).buttonStyle(.plain)
        }
        .padding(24)
    }
}
