import SwiftUI

struct GameSettingsView: View {
    @Binding var soundEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var strongerFlash: Bool
    @Binding var reducedMotion: Bool
    @Binding var highContrast: Bool
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Audio & Feedback") {
                    Toggle(isOn: $soundEnabled) {
                        Label("Sound Effects", systemImage: "speaker.wave.2.fill")
                    }
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptic Pop", systemImage: "iphone.radiowaves.left.and.right")
                    }
                }

                Section("Accessibility") {
                    Toggle(isOn: $strongerFlash) {
                        Label("Stronger Hit Flash", systemImage: "bolt.fill")
                    }
                    Toggle(isOn: $highContrast) {
                        Label("High-Contrast Ball", systemImage: "circle.lefthalf.filled")
                    }
                    Toggle(isOn: $reducedMotion) {
                        Label("Reduced Motion", systemImage: "figure.walk.motion")
                    }
                }

                Section("Level 1") {
                    LabeledContent("Goal", value: "3 gentle hits")
                    LabeledContent("Tilt", value: "Not needed")
                    LabeledContent("Retries", value: "Unlimited")
                }
            }
            .navigationTitle("Game Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss)
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(ArcadeTheme.orange)
    }
}

