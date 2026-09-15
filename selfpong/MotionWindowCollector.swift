import Foundation

struct MotionFrame: Equatable, Sendable {
    let timestamp: Double
    let features: [Double]

    init(timestamp: Double, features: [Double]) {
        precondition(features.count == 9, "A motion frame must contain exactly nine features")
        self.timestamp = timestamp
        self.features = features
    }

    var accelerationMagnitude: Double {
        let x = features[0], y = features[1], z = features[2]
        return (x * x + y * y + z * z).squareRoot()
    }
}

struct CapturedMotionWindow: Equatable, Sendable {
    let frames: [MotionFrame]
    let peakMagnitude: Double
}

struct MotionWindowCollector {
    static let sampleRate = 100.0
    static let preTriggerFrames = 20
    static let postTriggerFrames = 30
    static let frameCount = 50
    static let refractorySeconds = 0.35

    private var buffer: [MotionFrame] = []
    private var triggerIndex: Int?
    private var refractoryUntil = 0.0

    var isCapturing: Bool { triggerIndex != nil }

    mutating func append(
        _ frame: MotionFrame,
        threshold: Double,
        triggerEnabled: Bool = true
    ) -> CapturedMotionWindow? {
        buffer.append(frame)

        if let triggerIndex {
            if buffer.count >= triggerIndex + Self.postTriggerFrames + 1 {
                let start = triggerIndex - (Self.preTriggerFrames - 1)
                let frames = Array(buffer[start ..< start + Self.frameCount])
                refractoryUntil = frame.timestamp + Self.refractorySeconds
                buffer = []
                self.triggerIndex = nil
                return CapturedMotionWindow(
                    frames: frames,
                    peakMagnitude: frames.map(\.accelerationMagnitude).max() ?? 0
                )
            }
            return nil
        }

        if buffer.count > Self.preTriggerFrames {
            buffer.removeFirst(buffer.count - Self.preTriggerFrames)
        }

        if triggerEnabled,
           frame.accelerationMagnitude > threshold,
           frame.timestamp > refractoryUntil,
           buffer.count == Self.preTriggerFrames {
            triggerIndex = buffer.count - 1
        }
        return nil
    }

    mutating func reset() {
        buffer = []
        triggerIndex = nil
        refractoryUntil = 0
    }
}
