import CoreMotion
import Foundation
import Observation
import UIKit

@Observable
final class GameEngine {
    static let hitZoneHeight = 0.95
    static let levelOneHoldHeight = 0.35
    static let contactTriggerThreshold = 0.78

    enum State: String {
        case ready = "Ready"
        case countdown = "Get ready"
        case playing = "Playing"
        case checkingContact = "Checking contact"
        case gameOver = "Dropped"
    }

    enum FeedbackTone: Equatable {
        case neutral
        case ready
        case success
        case rejected
        case warning
    }

    private(set) var state: State = .ready
    let levelNumber = 1
    let levelName = "Straight-Up Practice"
    private(set) var ball = BallState()
    private(set) var score = 0
    private(set) var rotation = SpatialEngine.identityRotation()
    private(set) var motionMessage = "Hold the phone flat, screen facing up"
    private(set) var isUsingSimulator = false
    private(set) var predictionLabel = "Waiting"
    private(set) var predictionConfidence = 0.0
    private(set) var lastDecision = "Start the rally, then make a gentle upward pop."
    private(set) var modelIsReady = false
    private(set) var isPhoneReady = false
    private(set) var levelAmount = 0.0
    private(set) var countdownValue = 3
    private(set) var feedbackTone: FeedbackTone = .neutral
    private(set) var isInStrikeZone = false
    private(set) var isWaitingForHit = false
    private(set) var flashIntensity = 0.0

    private let motion = CMMotionManager()
    private let classifier: (any MotionClassifying)?
    private var windowCollector = MotionWindowCollector()
    private var referenceAttitude: CMAttitude?
    private var latestAttitude: CMAttitude?
    private var previousTick: Date?
    private var trailAccumulator = 0.0
    private var readinessBeganAt: TimeInterval?
    private var countdownEndsAt: Date?
    private var pendingContactWasHittable: Bool?
    @ObservationIgnored private lazy var sounds = GameSoundPlayer()
    @ObservationIgnored private lazy var contactHaptic = UIImpactFeedbackGenerator(style: .rigid)

    init(classifier: (any MotionClassifying)? = nil) {
        motion.deviceMotionUpdateInterval = 1.0 / 100.0
        isUsingSimulator = !motion.isDeviceMotionAvailable
        if let classifier {
            self.classifier = classifier
            modelIsReady = true
        } else {
            self.classifier = try? CoreMLMotionClassifier()
            modelIsReady = self.classifier != nil
        }
        if isUsingSimulator {
            motionMessage = "Simulator: drag the sky to test phone tilt"
            isPhoneReady = true
            levelAmount = 1
        } else if !modelIsReady {
            motionMessage = "The trained model could not be loaded"
        }
    }

    func prepare() {
        sounds.prepare()
        startMotionIfNeeded()
    }

    func requestStart(at date: Date = Date()) {
        guard state == .ready, isPhoneReady else {
            feedbackTone = .warning
            motionMessage = "Place the phone flat, screen facing the ceiling"
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        countdownValue = 3
        countdownEndsAt = date.addingTimeInterval(3)
        state = .countdown
        feedbackTone = .ready
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sounds.play(.countdown)
    }

    func start() {
        score = 0
        state = .playing
        ball = BallState(position: SIMD3(0, 0, 0.22),
                         velocity: SIMD3(0, 0, 1.45),
                         trail: [])
        previousTick = nil
        windowCollector.reset()
        predictionLabel = "Waiting"
        predictionConfidence = 0
        lastDecision = modelIsReady ? "Listening for a real bounce…" : "Model unavailable"
        feedbackTone = .neutral
        isInStrikeZone = false
        isWaitingForHit = false
        flashIntensity = 0
        pendingContactWasHittable = nil
        countdownEndsAt = nil
        startMotionIfNeeded()
        recenter()
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        sounds.play(.start)
    }

    func restart() {
        state = .ready
        requestStart()
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        state = .ready
        previousTick = nil
    }

    func recenter() {
        referenceAttitude = latestAttitude?.copy() as? CMAttitude
        rotation = SpatialEngine.identityRotation()
        motionMessage = isUsingSimulator ? "Simulator: drag the sky to test phone tilt" : "View centered"
    }

    func tick(at date: Date) {
        if state == .countdown {
            guard isPhoneReady else {
                state = .ready
                countdownEndsAt = nil
                feedbackTone = .warning
                motionMessage = "Phone moved. Hold it flat and still again."
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                sounds.play(.rejected)
                return
            }
            guard let countdownEndsAt else { return }
            let nextValue = max(0, Int(ceil(countdownEndsAt.timeIntervalSince(date))))
            if nextValue != countdownValue, nextValue > 0 {
                countdownValue = nextValue
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                sounds.play(.countdown)
            }
            if nextValue == 0 { start() }
            return
        }
        guard state == .playing || state == .checkingContact else {
            previousTick = date
            return
        }
        guard let previousTick else {
            self.previousTick = date
            return
        }

        let dt = min(max(date.timeIntervalSince(previousTick), 0), 1.0 / 20.0)
        self.previousTick = date
        flashIntensity = max(0, flashIntensity - dt * 2.8)
        if !isWaitingForHit {
            ball.velocity.z -= 1.05 * dt
            ball.position += ball.velocity * dt
            trailAccumulator += dt

            if trailAccumulator >= 1.0 / 30.0 {
                ball.trail.append(ball.position)
                if ball.trail.count > 12 { ball.trail.removeFirst(ball.trail.count - 12) }
                trailAccumulator = 0
            }

            if state == .playing,
               ball.velocity.z < 0,
               ball.position.z <= Self.levelOneHoldHeight {
                isWaitingForHit = true
                ball.position.z = Self.levelOneHoldHeight
                ball.velocity = .zero
            }
        }

        updateStrikeZone()

        if ball.position.z <= 0, state == .checkingContact, pendingContactWasHittable == true {
            // The model needs 30 post-trigger frames. Hold the ball at the bat
            // during that short decision instead of making the player lose.
            ball.position.z = 0.02
            ball.velocity = .zero
        } else if ball.position.z <= 0 {
            ball.position.z = 0
            ball.velocity = .zero
            state = .gameOver
            feedbackTone = .warning
            flashIntensity = 0.85
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            sounds.play(.gameOver)
        }
    }

    func simulateBounce() {
        guard isUsingSimulator else { return }
        acceptBounce(peakMagnitude: 1.15,
                     contactWasHittable: isInStrikeZone)
        predictionLabel = "bounce"
        predictionConfidence = 1
        lastDecision = "Simulator bounce accepted"
        feedbackTone = .success
    }

    func processCapturedWindow(_ window: CapturedMotionWindow) {
        guard state == .playing || state == .checkingContact else { return }
        guard let classifier else {
            lastDecision = "Model unavailable — no score added"
            return
        }

        state = .checkingContact
        let contactWasHittable = pendingContactWasHittable
            ?? (ball.position.z > 0 && ball.position.z <= Self.hitZoneHeight)
        do {
            let prediction = try classifier.classify(window)
            predictionLabel = prediction.label
            predictionConfidence = prediction.confidence
            if prediction.label == "bounce" {
                acceptBounce(peakMagnitude: window.peakMagnitude,
                             contactWasHittable: contactWasHittable)
            } else {
                lastDecision = contactWasHittable
                    ? "Not counted — the ball is waiting, so try again"
                    : "Motion heard, but the ball was not ready"
                if contactWasHittable {
                    isWaitingForHit = true
                    ball.position.z = Self.levelOneHoldHeight
                    ball.velocity = .zero
                }
                feedbackTone = .rejected
                flashIntensity = 0.55
                sounds.play(.rejected)
            }
        } catch {
            lastDecision = "Could not check motion: \(error.localizedDescription)"
        }
        pendingContactWasHittable = nil
        if state != .gameOver { state = .playing }
    }

    private func acceptBounce(peakMagnitude: Double, contactWasHittable: Bool) {
        guard (state == .playing || state == .checkingContact), contactWasHittable else {
            lastDecision = "Bounce recognized, but the ball was not in the HIT zone"
            feedbackTone = .warning
            flashIntensity = 0.45
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            sounds.play(.rejected)
            return
        }
        let strength = min(max(1.35 + (peakMagnitude - Self.contactTriggerThreshold) * 0.24,
                               1.35),
                           1.75)
        ball.position.x = 0
        ball.position.y = 0
        ball.velocity.z = strength
        ball.velocity.x = 0
        ball.velocity.y = 0
        ball.position.z = max(ball.position.z, 0.08)
        isWaitingForHit = false
        rotation = SpatialEngine.identityRotation()
        score += 1
        lastDecision = "Bounce accepted — score +1"
        feedbackTone = .success
        flashIntensity = 1
        isInStrikeZone = false
        sounds.play(.accepted)
    }

    func setSimulatedTilt(translationX: Double, translationY: Double) {
        // Level 1 deliberately keeps the ball centered. Tilt mechanics return in later levels.
    }

    private func startMotionIfNeeded() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, error in
            guard let self else { return }
            if let error {
                motionMessage = "Motion error: \(error.localizedDescription)"
                return
            }
            guard let data else { return }
            latestAttitude = data.attitude
            updateReadiness(with: data)
            let frame = MotionFrame(
                timestamp: data.timestamp,
                features: [
                    data.userAcceleration.x, data.userAcceleration.y, data.userAcceleration.z,
                    data.rotationRate.x, data.rotationRate.y, data.rotationRate.z,
                    data.gravity.x, data.gravity.y, data.gravity.z
                ]
            )
            let wasCapturing = windowCollector.isCapturing
            let window = windowCollector.append(
                frame,
                threshold: Self.contactTriggerThreshold,
                triggerEnabled: isInStrikeZone
            )
            if !wasCapturing, windowCollector.isCapturing {
                motionTriggerDetected()
            }
            if let window {
                processCapturedWindow(window)
            }
            if referenceAttitude == nil {
                referenceAttitude = data.attitude.copy() as? CMAttitude
            }
            // Level 1 uses a locked, straight-up camera so returning the phone to
            // flat after a pop cannot make the ball appear on the opposite side.
            rotation = SpatialEngine.identityRotation()
        }
    }

    static func phoneIsReady(
        gravity: CMAcceleration,
        accelerationMagnitude: Double,
        rotationMagnitude: Double
    ) -> Bool {
        let tilt = hypot(gravity.x, gravity.y)
        return gravity.z < -0.90
            && tilt < 0.42
            && accelerationMagnitude < 0.20
            && rotationMagnitude < 0.80
    }

    static func ballIsHittable(positionZ: Double, verticalVelocity: Double) -> Bool {
        positionZ > 0 && positionZ <= hitZoneHeight && verticalVelocity < 0
    }

    private func updateStrikeZone() {
        let isHittable = (state == .playing || state == .checkingContact)
            && (isWaitingForHit
                || Self.ballIsHittable(positionZ: ball.position.z,
                                       verticalVelocity: ball.velocity.z))
        if isHittable, !isInStrikeZone {
            feedbackTone = .ready
            contactHaptic.prepare()
            sounds.play(.hitWindow)
        }
        isInStrikeZone = isHittable
    }

    private func motionTriggerDetected() {
        pendingContactWasHittable = isInStrikeZone
        feedbackTone = .neutral
        flashIntensity = max(flashIntensity, 0.28)
        lastDecision = "Motion heard — checking it now…"
        if isInStrikeZone { state = .checkingContact }
        contactHaptic.impactOccurred(intensity: 1)
        sounds.play(.motionDetected)
    }

    private func updateReadiness(with data: CMDeviceMotion) {
        let tilt = hypot(data.gravity.x, data.gravity.y)
        let faceUpFactor = min(max((-data.gravity.z - 0.55) / 0.40, 0), 1)
        let tiltFactor = min(max(1 - tilt / 0.65, 0), 1)
        levelAmount = faceUpFactor * tiltFactor

        let acceleration = data.userAcceleration
        let accelerationMagnitude = sqrt(
            acceleration.x * acceleration.x
                + acceleration.y * acceleration.y
                + acceleration.z * acceleration.z
        )
        let rotation = data.rotationRate
        let rotationMagnitude = sqrt(
            rotation.x * rotation.x
                + rotation.y * rotation.y
                + rotation.z * rotation.z
        )
        let correctlyHeld = Self.phoneIsReady(
            gravity: data.gravity,
            accelerationMagnitude: accelerationMagnitude,
            rotationMagnitude: rotationMagnitude
        )

        if correctlyHeld {
            if readinessBeganAt == nil { readinessBeganAt = data.timestamp }
            if let readinessBeganAt, data.timestamp - readinessBeganAt >= 0.35, !isPhoneReady {
                isPhoneReady = true
                feedbackTone = .ready
                motionMessage = "Phone ready — keep it like this"
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                sounds.play(.ready)
            }
        } else {
            readinessBeganAt = nil
            isPhoneReady = false
            if state == .ready {
                feedbackTone = .neutral
                motionMessage = data.gravity.z >= -0.90
                    ? "Turn the screen up toward the ceiling"
                    : "Make the phone flatter and keep it still"
            }
        }
    }
}
