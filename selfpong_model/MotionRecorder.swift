//
//  MotionRecorder.swift
//  selfpong_model
//
//  Captures fixed-length CoreMotion windows around every acceleration peak and
//  appends them to a single labeled CSV that Create ML's Activity Classification
//  template can ingest.
//
//  The game is keepie-uppie: the phone is held flat, screen up, like a bat. Ball
//  height comes from peak magnitude and direction from the gravity vector — both
//  plain physics. The model's only job is deciding whether a triggered window was
//  a real bounce or incidental hand movement, which a magnitude threshold cannot
//  do because the peaks overlap.
//

import Foundation
import CoreMotion
import Observation
import UIKit

/// These numbers must match in three places: this app, the Create ML project
/// (Prediction Window Size / frequency), and the live inference path in the game.
/// Changing one alone produces a model that trains fine and predicts garbage.
enum RecordingConfig {
    static let sampleRate = 100.0
    static let preTriggerFrames = 20      // includes the trigger frame itself
    static let postTriggerFrames = 30
    static var frameCount: Int { preTriggerFrames + postTriggerFrames }  // 50 = 0.5 s
    static var windowSeconds: Double { Double(frameCount) / sampleRate }

    /// Stops one bounce being cut into two samples.
    static let refractorySeconds = 0.35

    static let defaultThreshold = 1.5     // g of userAcceleration magnitude
    static let thresholdRange = 0.4 ... 4.0

    static let targetPerClass = 40
    static let calibrationSamples = 5
    static let calibrationDuration = 1.25
    static let calibrationMultiplier = 0.70
}

/// What the hand was doing when the trigger fired.
///
/// The game runs a cheap magnitude threshold as a pre-filter and hands every
/// window it catches to this model. The threshold cannot tell an intentional
/// bounce from a grip shift — the peaks overlap — so the model is what decides
/// whether a contact counts. Ball height and direction are NOT its job: those
/// come from peak magnitude and the gravity vector, as plain physics.
enum MotionClass: String, CaseIterable, Identifiable {
    case bounce, adjust, idle

    var id: String { rawValue }
    var display: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .bounce: "arrow.up.circle.fill"
        case .adjust: "hand.draw"
        case .idle:   "figure.walk"
        }
    }

    var short: String {
        switch self {
        case .bounce: "A real hit. Should count."
        case .adjust: "Repositioning. Must not count."
        case .idle:   "Everyday hand motion. Must not count."
        }
    }

    var steps: [String] {
        switch self {
        case .bounce:
            ["Hold the phone flat, screen facing up, like a bat.",
             "Juggle normally — pop straight up from the wrist, bat stays up.",
             "Mix it up: soft pops, hard pops, tilted pops. All of these are 'bounce'.",
             "Keep going for a minute or two. Each contact is cut automatically."]
        case .adjust:
            ["Same flat grip, screen up.",
             "Shift your grip, reposition your hand, re-centre the bat.",
             "Steady yourself like you just misjudged a bounce and lunged for it.",
             "Never make a clean upward pop — these are exactly the near-misses that must not score."]
        case .idle:
            ["Hold the phone flat and just live normally.",
             "Walk around, turn, stand still, gesture with your other hand.",
             "Set it down and pick it up again.",
             "Anything that is not a deliberate bounce belongs here."]
        }
    }

    var signal: String {
        switch self {
        case .bounce: "Sharp clean impulse, bat level throughout."
        case .adjust: "Slow wandering motion, gravity drifts as the bat tilts."
        case .idle:   "Low, unstructured motion with no clear impulse."
        }
    }

    /// The samples that actually teach the model something are the ones near the
    /// threshold — those are the windows the game would otherwise misfire on.
    var hint: String {
        switch self {
        case .bounce:
            "Include your weakest real bounces. If the model only sees hard ones, it will reject your soft pops in play."
        case .adjust, .idle:
            "Nothing being captured? Lower the threshold. You want the borderline motions that would fool the trigger — not obvious ones."
        }
    }
}

enum ParticipantProfile: String, CaseIterable, Identifiable {
    case primary
    case guest

    var id: String { rawValue }
    var displayName: String { self == .primary ? "Me" : "Guest" }
}

@Observable
final class MotionRecorder {

    enum CalibrationState: Equatable {
        case idle
        case measuring
        case ready
        case failed(String)
    }

    enum State: Equatable {
        case idle
        case listening
        case captured(MotionClass)
    }

    private(set) var state: State = .idle
    private(set) var counts: [MotionClass: Int] = [:]
    private(set) var participantCounts: [ParticipantProfile: [MotionClass: Int]] = [:]
    private(set) var unavailableReason: String?
    private(set) var calibrationState: CalibrationState = .idle
    private(set) var calibrationPeaks: [Double] = []

    /// Live |userAcceleration| in g, throttled to ~20 Hz for the on-screen meter.
    private(set) var liveMagnitude: Double = 0
    /// Peak of the most recent captured bounce — lets you eyeball whether your
    /// "soft" and "hard" are actually separable before recording 90 of them.
    private(set) var lastPeak: Double = 0
    /// Samples captured since this rally started.
    private(set) var rallyCount: Int = 0

    private(set) var threshold: Double = RecordingConfig.defaultThreshold

    private let motion = CMMotionManager()
    private var activeLabel: MotionClass = .bounce
    private var activeParticipant: ParticipantProfile = .primary

    private struct Frame {
        let timestamp: Double
        let values: [Double]   // ua xyz, rr xyz, g xyz
        let magnitude: Double
    }

    private var buffer: [Frame] = []
    private var triggerIndex: Int?
    private var refractoryUntil: Double = 0
    private var frameTick = 0
    private var calibrationPeak = 0.0

    private static let thresholdKey = "calibratedTriggerThreshold"

    static let header = "session_id,participant_id,label,frame_index,timestamp,ua_x,ua_y,ua_z,rr_x,rr_y,rr_z,g_x,g_y,g_z"

    var total: Int { counts.values.reduce(0, +) }
    var isThresholdLocked: Bool { total > 0 }
    var hasCalibration: Bool { UserDefaults.standard.object(forKey: Self.thresholdKey) != nil }

    var csvURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("swings.csv")
    }

    init() {
        if !motion.isDeviceMotionAvailable {
            unavailableReason = "Device motion unavailable — run on a real iPhone, not the Simulator."
        }
        motion.deviceMotionUpdateInterval = 1.0 / RecordingConfig.sampleRate
        if let saved = UserDefaults.standard.object(forKey: Self.thresholdKey) as? Double {
            threshold = saved
            calibrationState = .ready
        }
        refreshCounts()
    }

    // MARK: - Guided calibration

    /// Measures one gentle bounce without asking the user to understand a
    /// threshold slider. After five measurements, a conservative trigger is
    /// selected below the weakest observed bounce.
    func measureGentleBounce() {
        guard unavailableReason == nil,
              calibrationState != .measuring,
              calibrationPeaks.count < RecordingConfig.calibrationSamples else { return }

        calibrationPeak = 0
        calibrationState = .measuring
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let a = data.userAcceleration
            let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            calibrationPeak = max(calibrationPeak, magnitude)
            liveMagnitude = magnitude
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + RecordingConfig.calibrationDuration) { [weak self] in
            self?.finishCalibrationMeasurement()
        }
    }

    private func finishCalibrationMeasurement() {
        motion.stopDeviceMotionUpdates()
        liveMagnitude = 0

        guard calibrationPeak >= RecordingConfig.thresholdRange.lowerBound else {
            calibrationState = .failed("That movement was too small. Tap Try Again, then make one clear gentle pop.")
            return
        }

        calibrationPeaks.append(calibrationPeak)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if calibrationPeaks.count == RecordingConfig.calibrationSamples,
           let weakest = calibrationPeaks.min() {
            threshold = min(max(weakest * RecordingConfig.calibrationMultiplier,
                                RecordingConfig.thresholdRange.lowerBound),
                            RecordingConfig.thresholdRange.upperBound)
            UserDefaults.standard.set(threshold, forKey: Self.thresholdKey)
            calibrationState = .ready
        } else {
            calibrationState = .idle
        }
    }

    func retryCalibrationMeasurement() {
        guard case .failed = calibrationState else { return }
        calibrationState = .idle
    }

    func restartCalibration() {
        guard !isThresholdLocked else { return }
        motion.stopDeviceMotionUpdates()
        calibrationPeaks = []
        calibrationState = .idle
        threshold = RecordingConfig.defaultThreshold
        UserDefaults.standard.removeObject(forKey: Self.thresholdKey)
    }

    // MARK: - Rally

    func startRally(label: MotionClass, participant: ParticipantProfile) {
        guard case .idle = state, unavailableReason == nil else { return }
        activeLabel = label
        activeParticipant = participant
        buffer = []
        triggerIndex = nil
        refractoryUntil = 0
        rallyCount = 0
        state = .listening

        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, _ in
            guard let self, let d = data else { return }
            handle(d)
        }
    }

    func stopRally() {
        motion.stopDeviceMotionUpdates()
        buffer = []
        triggerIndex = nil
        liveMagnitude = 0
        state = .idle
    }

    private func handle(_ d: CMDeviceMotion) {
        let ua = d.userAcceleration, rr = d.rotationRate, g = d.gravity
        let mag = (ua.x * ua.x + ua.y * ua.y + ua.z * ua.z).squareRoot()
        buffer.append(Frame(timestamp: d.timestamp,
                            values: [ua.x, ua.y, ua.z, rr.x, rr.y, rr.z, g.x, g.y, g.z],
                            magnitude: mag))

        frameTick += 1
        if frameTick % 5 == 0 { liveMagnitude = mag }

        if let t = triggerIndex {
            // Wait until enough post-contact frames have arrived, then cut.
            if buffer.count >= t + RecordingConfig.postTriggerFrames + 1 {
                let start = t - (RecordingConfig.preTriggerFrames - 1)
                emit(Array(buffer[start ..< start + RecordingConfig.frameCount]))
                refractoryUntil = d.timestamp + RecordingConfig.refractorySeconds
                buffer = []
                triggerIndex = nil
            }
            return
        }

        // Not capturing: keep only enough history to reach back before a contact.
        if buffer.count > RecordingConfig.preTriggerFrames {
            buffer.removeFirst(buffer.count - RecordingConfig.preTriggerFrames)
        }

        if mag > threshold,
           d.timestamp > refractoryUntil,
           buffer.count == RecordingConfig.preTriggerFrames {
            triggerIndex = buffer.count - 1
        }
    }

    private func emit(_ frames: [Frame]) {
        let session = UUID().uuidString
        let label = activeLabel
        let rows = frames.enumerated().map { i, f in
            let vals = f.values.map { String(format: "%.6f", $0) }.joined(separator: ",")
            return "\(session),\(activeParticipant.rawValue),\(label.rawValue),\(i),\(String(format: "%.4f", f.timestamp)),\(vals)"
        }
        append(rows)

        lastPeak = frames.map(\.magnitude).max() ?? 0
        rallyCount += 1
        refreshCounts()

        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        state = .captured(label)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, case .captured = state else { return }
            state = .listening
        }
    }

    // MARK: - CSV

    private func append(_ rows: [String]) {
        let url = csvURL
        let body = rows.joined(separator: "\n") + "\n"

        guard let handle = try? FileHandle(forWritingTo: url) else {
            try? (Self.header + "\n" + body).write(to: url, atomically: true, encoding: .utf8)
            return
        }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(body.utf8))
    }

    /// Counts distinct session_ids per label, i.e. bounces — not rows.
    func refreshCounts() {
        var seen: [MotionClass: Set<String>] = [:]
        var seenByParticipant: [ParticipantProfile: [MotionClass: Set<String>]] = [:]
        for line in csvLines().dropFirst() {
            let cols = line.split(separator: ",", omittingEmptySubsequences: false)
            guard cols.count > 2,
                  let participant = ParticipantProfile(rawValue: String(cols[1])),
                  let label = MotionClass(rawValue: String(cols[2])) else { continue }
            let session = String(cols[0])
            seen[label, default: []].insert(session)
            seenByParticipant[participant, default: [:]][label, default: []].insert(session)
        }
        counts = seen.mapValues(\.count)
        participantCounts = seenByParticipant.mapValues { labels in labels.mapValues(\.count) }
    }

    private func csvLines() -> [String] {
        guard let text = try? String(contentsOf: csvURL, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map(String.init)
    }

    /// Drops the most recent sample. Auto-segmentation will occasionally cut a
    /// bad one — a kept bad sample is worse than one not taken.
    func undoLast() {
        let lines = csvLines()
        guard lines.count > 1, let last = lines.last,
              let session = last.split(separator: ",").first.map(String.init) else { return }

        let kept = [lines[0]] + lines.dropFirst().filter { !$0.hasPrefix(session + ",") }
        try? (kept.joined(separator: "\n") + "\n").write(to: csvURL, atomically: true, encoding: .utf8)
        if rallyCount > 0 { rallyCount -= 1 }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        refreshCounts()
    }

    func resetDataset() {
        _ = try? FileManager.default.removeItem(at: csvURL)
        refreshCounts()
    }
}
