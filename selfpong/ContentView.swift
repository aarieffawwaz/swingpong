import SwiftUI

struct ContentView: View {
    private enum Route { case home, map, briefing, gameplay, complete }

    @State private var route: Route = .home
    @State private var engine = GameEngine()
    @State private var showingSettings = false
    @State private var isPaused = false
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("strongerFlash") private var strongerFlash = false
    @AppStorage("reducedMotion") private var reducedMotion = false
    @AppStorage("highContrast") private var highContrast = false
    @AppStorage("levelOneCompleted") private var levelOneCompleted = false

    var body: some View {
        ZStack {
            switch route {
            case .home:
                HomeView(levelOneCompleted: levelOneCompleted,
                         play: { route = .map },
                         showSettings: { showingSettings = true })
            case .map:
                LevelMapView(levelOneCompleted: levelOneCompleted,
                             back: { route = .home },
                             selectLevelOne: { route = .briefing },
                             showSettings: { showingSettings = true })
            case .briefing:
                LevelBriefingView(close: { route = .map }, start: beginLevel)
            case .gameplay:
                GameplayView(engine: engine,
                             strongerFlash: strongerFlash,
                             reducedMotion: reducedMotion,
                             highContrast: highContrast,
                             pause: { engine.setPaused(true); isPaused = true },
                             complete: finishLevel)
            case .complete:
                LevelCompleteView(replay: beginLevel, nextLevel: { route = .map })
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showingSettings) {
            GameSettingsView(soundEnabled: $soundEnabled,
                             hapticsEnabled: $hapticsEnabled,
                             strongerFlash: $strongerFlash,
                             reducedMotion: $reducedMotion,
                             highContrast: $highContrast,
                             dismiss: { showingSettings = false })
        }
        .sheet(isPresented: $isPaused) {
            PauseMenuView(resume: { engine.setPaused(false); isPaused = false },
                          restart: { isPaused = false; beginLevel() },
                          exitLevel: { isPaused = false; engine.stop(); route = .map })
                .presentationDetents([.medium])
                .interactiveDismissDisabled()
        }
        .onAppear { syncFeedbackSettings() }
        .onChange(of: soundEnabled) { _, _ in syncFeedbackSettings() }
        .onChange(of: hapticsEnabled) { _, _ in syncFeedbackSettings() }
    }

    private func syncFeedbackSettings() {
        engine.soundEnabled = soundEnabled
        engine.hapticsEnabled = hapticsEnabled
    }

    private func beginLevel() {
        syncFeedbackSettings()
        engine.resetToReady()
        engine.prepare()
        route = .gameplay
    }

    private func finishLevel() {
        guard route == .gameplay else { return }
        levelOneCompleted = true
        engine.stop()
        route = .complete
    }
}

#Preview { ContentView() }
