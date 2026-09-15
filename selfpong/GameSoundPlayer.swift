import AVFAudio
import Foundation

/// Small synthesized cues keep sound, haptics, and gameplay timing together
/// without shipping recordings or waiting for disk I/O at the contact moment.
final class GameSoundPlayer {
    enum Cue {
        case ready
        case countdown
        case start
        case hitWindow
        case motionDetected
        case accepted
        case rejected
        case gameOver
    }

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private let sampleRate = 44_100.0

    func prepare() {
        guard engine == nil, !isRunningTests else { return }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        try? engine.start()
        self.engine = engine
        self.player = player
    }

    func play(_ cue: Cue) {
        guard !isRunningTests else { return }
        prepare()
        guard let engine, let player else { return }
        if !engine.isRunning { try? engine.start() }
        guard let buffer = makeBuffer(for: cue) else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func makeBuffer(for cue: Cue) -> AVAudioPCMBuffer? {
        let parameters: (duration: Double, start: Double, end: Double, decay: Double, volume: Double, noise: Double)
        switch cue {
        case .ready:          parameters = (0.13, 620, 980, 12, 0.28, 0)
        case .countdown:      parameters = (0.055, 520, 520, 28, 0.22, 0)
        case .start:          parameters = (0.12, 880, 1_280, 11, 0.32, 0)
        case .hitWindow:      parameters = (0.09, 1_180, 920, 18, 0.34, 0.02)
        case .motionDetected: parameters = (0.045, 700, 560, 34, 0.18, 0.04)
        case .accepted:       parameters = (0.18, 920, 330, 16, 0.62, 0.24)
        case .rejected:       parameters = (0.11, 270, 190, 20, 0.27, 0.05)
        case .gameOver:       parameters = (0.30, 190, 65, 9, 0.42, 0.10)
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(parameters.duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        var phase = 0.0
        var noiseSeed: UInt32 = 0x5EED
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let progress = time / parameters.duration
            let frequency = parameters.start + (parameters.end - parameters.start) * progress
            phase += 2 * .pi * frequency / sampleRate
            let envelope = exp(-parameters.decay * time) * min(time * 350, 1)
            let body = sin(phase) * 0.72 + sin(phase * 2.03) * 0.28
            noiseSeed = noiseSeed &* 1_664_525 &+ 1_013_904_223
            let noise = (Double(noiseSeed & 0xffff) / 32_767.5) - 1
            let clickEnvelope = exp(-95 * time)
            samples[frame] = Float(parameters.volume * envelope
                * (body + noise * parameters.noise * clickEnvelope))
        }
        return buffer
    }
}
