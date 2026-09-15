import SwiftUI

struct ContentView: View {
    private enum Stage: Hashable {
        case welcome
        case calibration
        case training(MotionClass)
        case review
        case export
    }

    @State private var recorder = MotionRecorder()
    @State private var stage: Stage = .welcome
    @State private var participant: ParticipantProfile = .primary
    @State private var confirmingReset = false
    @State private var confirmingRecalibration = false

    var body: some View {
        NavigationStack {
            Group {
                if isRecording { recordingScreen } else { screen(for: stage) }
            }
            .animation(.snappy(duration: 0.2), value: isRecording)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .confirmationDialog("Delete every recorded sample?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Delete all samples", role: .destructive) { recorder.resetDataset() }
        } message: {
            Text("This cannot be undone. Your calibration will stay saved.")
        }
        .confirmationDialog("Start calibration again?", isPresented: $confirmingRecalibration, titleVisibility: .visible) {
            Button("Recalibrate", role: .destructive) { recorder.restartCalibration() }
        } message: {
            Text("Your saved sensitivity will be replaced. This is only available before recording samples.")
        }
    }

    private var isRecording: Bool {
        switch recorder.state {
        case .idle: false
        case .listening, .captured: true
        }
    }

    private var title: String {
        if isRecording { return "Recording" }
        switch stage {
        case .welcome: return "Teach SwingPong"
        case .calibration: return "Set Sensitivity"
        case .training(let motion): return motion.friendlyName
        case .review: return "Check Your Progress"
        case .export: return "Share Dataset"
        }
    }

    @ViewBuilder
    private func screen(for stage: Stage) -> some View {
        switch stage {
        case .welcome: welcomeScreen
        case .calibration: calibrationScreen
        case .training(let motion): classScreen(motion)
        case .review: reviewScreen
        case .export: exportScreen
        }
    }

    private var welcomeScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 68)).foregroundStyle(.tint).padding(.top, 28)
                VStack(spacing: 10) {
                    Text("Teach the game what a bounce feels like")
                        .font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Text("We will guide you. You do not need to understand motion sensors or machine learning.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                VStack(spacing: 12) {
                    welcomeRow(number: "1", title: "Set sensitivity", detail: "Make five gentle pops.")
                    welcomeRow(number: "2", title: "Record three examples", detail: "Real bounces, hand adjustments, and everyday movement.")
                    welcomeRow(number: "3", title: "Share the dataset", detail: "The file will be used to train the model.")
                }
                if recorder.total > 0 {
                    Label("You already have \(recorder.total) saved samples.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                primaryButton(recorder.hasCalibration ? "Continue" : "Let’s Start", icon: "arrow.right") {
                    stage = recorder.hasCalibration ? .review : .calibration
                }
            }
            .padding()
        }
    }

    private func welcomeRow(number: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Text(number).font(.headline.monospacedDigit()).foregroundStyle(.white)
                .frame(width: 34, height: 34).background(.tint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding().background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
    }

    private var calibrationScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "iphone.gen3")
                    .font(.system(size: 80))
                    .symbolEffect(.bounce, value: recorder.calibrationState == .measuring)
                    .foregroundStyle(.tint).padding(.top, 20)
                VStack(spacing: 8) {
                    Text(calibrationHeading).font(.title.bold())
                    Text(calibrationInstruction).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                HStack(spacing: 12) {
                    ForEach(0..<RecordingConfig.calibrationSamples, id: \.self) { index in
                        Image(systemName: index < recorder.calibrationPeaks.count ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(index < recorder.calibrationPeaks.count ? .green : .secondary)
                    }
                }
                if let reason = recorder.unavailableReason {
                    notice(reason, icon: "exclamationmark.triangle.fill", color: .orange)
                }
                calibrationAction
                if recorder.hasCalibration {
                    DisclosureGroup("Advanced details") {
                        Text("Trigger sensitivity: \(recorder.threshold, specifier: "%.2f") g")
                            .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                    }
                    .font(.subheadline)
                    Button("Calibrate again", role: .destructive) { confirmingRecalibration = true }
                        .disabled(recorder.isThresholdLocked)
                }
            }
            .padding()
        }
    }

    private var calibrationHeading: String {
        switch recorder.calibrationState {
        case .idle: "Gentle pop \(recorder.calibrationPeaks.count + 1) of \(RecordingConfig.calibrationSamples)"
        case .measuring: "Pop now"
        case .ready: "Sensitivity ready"
        case .failed: "Let’s try that again"
        }
    }

    private var calibrationInstruction: String {
        switch recorder.calibrationState {
        case .idle: "Hold the phone flat, screen up. Tap the button, then make one gentle upward pop."
        case .measuring: "Make one gentle upward pop while the phone stays facing up."
        case .ready: "The app can now listen for your gentlest real bounce."
        case .failed(let message): message
        }
    }

    @ViewBuilder
    private var calibrationAction: some View {
        switch recorder.calibrationState {
        case .idle:
            primaryButton("Measure This Bounce", icon: "waveform.path.ecg") { recorder.measureGentleBounce() }
                .disabled(recorder.unavailableReason != nil)
        case .measuring:
            ProgressView().controlSize(.large).padding()
        case .ready:
            primaryButton("Continue to Real Bounces", icon: "arrow.right") { stage = .training(.bounce) }
        case .failed:
            primaryButton("Try Again", icon: "arrow.clockwise") { recorder.retryCalibrationMeasurement() }
        }
    }

    private func classScreen(_ motion: MotionClass) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: motion.symbol).font(.system(size: 72)).foregroundStyle(motion.color).padding(.top, 24)
                VStack(spacing: 8) {
                    Text(motion.friendlyName).font(.largeTitle.bold())
                    Text(motion.outcomeText).font(.title3.weight(.semibold)).foregroundStyle(motion.color)
                    Text(motion.simpleInstruction).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                sampleProgress(for: motion)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Who is holding the phone?").font(.headline)
                    Picker("Person", selection: $participant) {
                        ForEach(ParticipantProfile.allCases) { profile in
                            Text(profile.displayName).tag(profile)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(participant == .primary ? "Choose Me for your recordings." : "Choose Guest when another person is helping.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding().background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
                notice(motion.doNotText, icon: "exclamationmark.circle", color: .secondary)
                primaryButton("Start Recording", icon: "record.circle") {
                    recorder.startRally(label: motion, participant: participant)
                }
                    .disabled(!recorder.hasCalibration || recorder.unavailableReason != nil)
                HStack {
                    Button("Back") { stage = previousStage(before: motion) }
                    Spacer()
                    Button("Skip for now") { stage = nextStage(after: motion) }
                }
                .font(.subheadline)
            }
            .padding()
        }
    }

    private func sampleProgress(for motion: MotionClass) -> some View {
        let count = recorder.counts[motion] ?? 0
        return VStack(spacing: 8) {
            Text("\(count) of \(RecordingConfig.targetPerClass)")
                .font(.system(size: 42, weight: .bold, design: .rounded)).monospacedDigit()
            ProgressView(value: min(Double(count) / Double(RecordingConfig.targetPerClass), 1)).tint(motion.color)
            Text("Me: \(recorder.participantCounts[.primary]?[motion] ?? 0)  •  Guest: \(recorder.participantCounts[.guest]?[motion] ?? 0)")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Text(count < 10 ? "First goal: collect 10 test samples" : "Test goal complete — keep going to 40")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding().background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
    }

    private var recordingScreen: some View {
        let motion = activeMotion
        return VStack(spacing: 20) {
            Spacer()
            Image(systemName: justCaptured ? "checkmark.circle.fill" : "waveform.path.ecg")
                .font(.system(size: 56)).foregroundStyle(justCaptured ? .green : motion.color)
            Text("\(recorder.rallyCount)")
                .font(.system(size: 120, weight: .bold, design: .rounded)).monospacedDigit()
                .contentTransition(.numericText())
            Text(justCaptured ? "Sample saved" : "Listening for \(motion.friendlyName.lowercased())")
                .font(.title3.weight(.semibold)).foregroundStyle(justCaptured ? .green : .secondary)
            Text(motion.simpleInstruction).multilineTextAlignment(.center).padding(.horizontal)
            liveMeter
            Spacer()
            HStack {
                Button(role: .destructive) { recorder.undoLast() } label: {
                    Label("Undo Last", systemImage: "arrow.uturn.backward")
                }
                .disabled(recorder.rallyCount == 0)
                Spacer()
                Text("Last signal: \(recorder.lastPeak, specifier: "%.2f") g")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Button { recorder.stopRally() } label: {
                Label("Stop Recording", systemImage: "stop.fill")
                    .font(.title2.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(.borderedProminent).tint(.red)
        }
        .padding()
    }

    private var activeMotion: MotionClass {
        if case .training(let motion) = stage { return motion }
        return .bounce
    }

    private var justCaptured: Bool {
        if case .captured = recorder.state { return true }
        return false
    }

    private var liveMeter: some View {
        GeometryReader { geometry in
            let fraction = min(recorder.liveMagnitude / RecordingConfig.thresholdRange.upperBound, 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(recorder.liveMagnitude >= recorder.threshold ? Color.green : Color.accentColor)
                    .frame(width: geometry.size.width * max(fraction, 0))
            }
        }
        .frame(height: 18).accessibilityLabel("Motion strength")
    }

    private var reviewScreen: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("You can revisit any section.").foregroundStyle(.secondary).padding(.top)
                ForEach(MotionClass.allCases) { motion in
                    Button { stage = .training(motion) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: motion.symbol).font(.title2).foregroundStyle(motion.color).frame(width: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(motion.friendlyName).font(.headline)
                                Text("\(recorder.counts[motion] ?? 0) of \(RecordingConfig.targetPerClass) samples")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text("Me \(recorder.participantCounts[.primary]?[motion] ?? 0) • Guest \(recorder.participantCounts[.guest]?[motion] ?? 0)")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding().background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                notice("Sensitivity is locked at \(String(format: "%.2f", recorder.threshold)) g so every class is recorded fairly.",
                       icon: "lock.fill", color: .secondary)
                primaryButton("Continue to Share", icon: "square.and.arrow.up") { stage = .export }
                    .disabled(recorder.total == 0)
                Button("Delete all samples", role: .destructive) { confirmingReset = true }
                    .disabled(recorder.total == 0)
            }
            .padding()
        }
    }

    private var exportScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "doc.badge.arrow.up").font(.system(size: 72)).foregroundStyle(.tint)
            Text("Your dataset is ready to share").font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text("Share swings.csv to your Mac. It contains \(recorder.total) motion samples. We will check it before training the model.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            ShareLink(item: recorder.csvURL) {
                Label("Share Dataset", systemImage: "square.and.arrow.up")
                    .font(.title2.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(.borderedProminent).disabled(recorder.total == 0)
            Button("Back to Review") { stage = .review }
            Spacer()
        }
        .padding()
    }

    private func primaryButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon).font(.title2.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(.borderedProminent)
    }

    private func notice(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon).font(.subheadline).foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading).padding()
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    private func previousStage(before motion: MotionClass) -> Stage {
        switch motion {
        case .bounce: .calibration
        case .adjust: .training(.bounce)
        case .idle: .training(.adjust)
        }
    }

    private func nextStage(after motion: MotionClass) -> Stage {
        switch motion {
        case .bounce: .training(.adjust)
        case .adjust: .training(.idle)
        case .idle: .review
        }
    }
}

private extension MotionClass {
    var friendlyName: String {
        switch self {
        case .bounce: "Real Bounce"
        case .adjust: "Hand Adjustment"
        case .idle: "Everyday Movement"
        }
    }

    var outcomeText: String {
        switch self {
        case .bounce: "This should count"
        case .adjust, .idle: "This must not count"
        }
    }

    var simpleInstruction: String {
        switch self {
        case .bounce: "Keep the screen facing up. Mix gentle, strong, and slightly tilted upward pops."
        case .adjust: "Shift your grip and re-center the phone, but do not make a clean upward pop."
        case .idle: "Walk, turn, hold still, or pick up the phone as you normally would."
        }
    }

    var doNotText: String {
        switch self {
        case .bounce: "Do not flip the phone or swing it from your shoulder."
        case .adjust: "Do not make an intentional bounce during this section."
        case .idle: "If nothing is captured, make slightly stronger normal movements."
        }
    }

    var color: Color {
        switch self {
        case .bounce: .green
        case .adjust: .orange
        case .idle: .blue
        }
    }
}

#Preview {
    ContentView()
}
