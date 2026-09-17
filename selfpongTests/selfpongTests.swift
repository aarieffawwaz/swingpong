//
//  selfpongTests.swift
//  selfpongTests
//
//  Created by Aarief Fawwaz Satriahutama on 10/09/26.
//

import Testing
import CoreMotion
@testable import selfpong

struct selfpongTests {

    @Test func identityProjectionPlacesBallInCenter() {
        let result = SpatialEngine.project(
            position: SIMD3(0, 0, 1),
            rotation: SpatialEngine.identityRotation(),
            canvasSize: CGSize(width: 390, height: 844)
        )
        #expect(result.isVisible)
        #expect(abs(result.point.x - 195) < 0.001)
        #expect(abs(result.point.y - 422) < 0.001)
    }

    @Test func offscreenProjectionPinsIndicatorInsideEdge() {
        let result = SpatialEngine.project(
            position: SIMD3(4, 0, 1),
            rotation: SpatialEngine.identityRotation(),
            canvasSize: CGSize(width: 390, height: 844)
        )
        #expect(!result.isVisible)
        #expect(result.edgePoint.x <= 390 - SpatialEngine.edgeMargin + 0.001)
        #expect(result.edgePoint.x >= SpatialEngine.edgeMargin - 0.001)
    }

    @Test func behindProjectionIsExplicit() {
        let result = SpatialEngine.project(
            position: SIMD3(0.1, 0, -1),
            rotation: SpatialEngine.identityRotation(),
            canvasSize: CGSize(width: 390, height: 844)
        )
        #expect(!result.isVisible)
        #expect(result.isBehind)
    }

    @Test func collectorEmitsExactlyFiftyOrderedFrames() {
        var collector = MotionWindowCollector()
        var captured: CapturedMotionWindow?
        for index in 0..<55 {
            var features = Array(repeating: 0.0, count: 9)
            if index == 20 { features[2] = 2.0 }
            let frame = MotionFrame(timestamp: Double(index) / 100, features: features)
            captured = collector.append(frame, threshold: 1.0) ?? captured
        }
        #expect(captured?.frames.count == 50)
        #expect(captured?.frames.first?.timestamp == 0.01)
        #expect(captured?.frames[19].timestamp == 0.20)
        #expect(captured?.peakMagnitude == 2.0)
    }

    @Test func collectorReportsTriggerBeforeTheFullWindowIsReady() {
        var collector = MotionWindowCollector()
        for index in 0..<20 {
            var features = Array(repeating: 0.0, count: 9)
            if index == 19 { features[2] = 1.2 }
            let result = collector.append(
                MotionFrame(timestamp: Double(index) / 100, features: features),
                threshold: 0.85
            )
            #expect(result == nil)
        }
        #expect(collector.isCapturing)
    }

    @Test func collectorCannotStartBeforeTheHitWindow() {
        var collector = MotionWindowCollector()
        for index in 0..<20 {
            var features = Array(repeating: 0.0, count: 9)
            features[2] = 1.2
            _ = collector.append(
                MotionFrame(timestamp: Double(index) / 100, features: features),
                threshold: 0.78,
                triggerEnabled: false
            )
        }
        #expect(!collector.isCapturing)

        var hitFeatures = Array(repeating: 0.0, count: 9)
        hitFeatures[2] = 1.2
        _ = collector.append(
            MotionFrame(timestamp: 0.20, features: hitFeatures),
            threshold: 0.78,
            triggerEnabled: true
        )
        #expect(collector.isCapturing)
    }

    @Test func preprocessingUsesReplicatedEdgeSmoothingAndTrainingNormalization() {
        let frames = (0..<50).map { index in
            MotionFrame(timestamp: Double(index) / 100,
                        features: Array(repeating: Double(index), count: 9))
        }
        let window = CapturedMotionWindow(frames: frames, peakMagnitude: 49)
        let normalized = MotionPreprocessor.normalizedFeatures(for: window)
        let expectedFirstSmoothedValue = 0.25
        let expected = (expectedFirstSmoothedValue - MotionPreprocessor.means[0])
            / MotionPreprocessor.standardDeviations[0]
        #expect(abs(normalized[0][0] - expected) < 0.000_001)
        #expect(normalized.count == 50)
        #expect(normalized.allSatisfy { $0.count == 9 })
    }

    @Test func onlyBouncePredictionCanAddScore() {
        let frames = (0..<50).map {
            MotionFrame(timestamp: Double($0) / 100, features: Array(repeating: 0, count: 9))
        }
        let window = CapturedMotionWindow(frames: frames, peakMagnitude: 1.2)

        let rejected = GameEngine(classifier: StubClassifier(label: "adjust"))
        rejected.start()
        rejected.processCapturedWindow(window)
        #expect(rejected.score == 0)

        let accepted = GameEngine(classifier: StubClassifier(label: "bounce"))
        accepted.start()
        accepted.processCapturedWindow(window)
        #expect(accepted.score == 1)
    }

    @Test func phoneMustBeStillFlatAndScreenUpToBeReady() {
        #expect(GameEngine.phoneIsReady(
            gravity: CMAcceleration(x: 0.02, y: -0.03, z: -0.99),
            accelerationMagnitude: 0.05,
            rotationMagnitude: 0.10
        ))
        #expect(!GameEngine.phoneIsReady(
            gravity: CMAcceleration(x: 0.02, y: -0.03, z: 0.99),
            accelerationMagnitude: 0.05,
            rotationMagnitude: 0.10
        ))
        #expect(!GameEngine.phoneIsReady(
            gravity: CMAcceleration(x: 0.60, y: 0, z: -0.80),
            accelerationMagnitude: 0.05,
            rotationMagnitude: 0.10
        ))
        #expect(!GameEngine.phoneIsReady(
            gravity: CMAcceleration(x: 0.02, y: -0.03, z: -0.99),
            accelerationMagnitude: 0.40,
            rotationMagnitude: 0.10
        ))
    }

    @Test func hitCueOnlyAppearsForLowFallingBall() {
        #expect(GameEngine.ballIsHittable(positionZ: 0.50, verticalVelocity: -0.40))
        #expect(GameEngine.ballIsHittable(positionZ: 0.80, verticalVelocity: -0.40))
        #expect(!GameEngine.ballIsHittable(positionZ: 1.05, verticalVelocity: -0.40))
        #expect(!GameEngine.ballIsHittable(positionZ: 0.30, verticalVelocity: 0.40))
        #expect(!GameEngine.ballIsHittable(positionZ: 0, verticalVelocity: -0.40))
    }

    @Test func ballTravelDirectionIsUnambiguous() {
        #expect(GameEngine.travelPhase(verticalVelocity: 0.8, isWaitingForHit: false) == .rising)
        #expect(GameEngine.travelPhase(verticalVelocity: -0.8, isWaitingForHit: false) == .falling)
        #expect(GameEngine.travelPhase(verticalVelocity: 0, isWaitingForHit: true) == .waitingForHit)
    }

    @Test func beginnerModeLaunchesStraightUp() {
        let engine = GameEngine(classifier: StubClassifier(label: "bounce"))
        engine.start()
        #expect(engine.ball.velocity.x == 0)
        #expect(engine.ball.velocity.y == 0)

        let frames = (0..<50).map {
            MotionFrame(timestamp: Double($0) / 100, features: Array(repeating: 0, count: 9))
        }
        engine.processCapturedWindow(CapturedMotionWindow(frames: frames, peakMagnitude: 1.2))
        #expect(engine.ball.velocity.x == 0)
        #expect(engine.ball.velocity.y == 0)
    }

    @Test func levelOneWaitsForThePlayerInsteadOfDroppingTheBall() {
        let engine = GameEngine(classifier: StubClassifier(label: "bounce"))
        engine.start()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        engine.tick(at: start)
        for frame in 1...360 {
            engine.tick(at: start.addingTimeInterval(Double(frame) / 60))
        }

        #expect(engine.state == .playing)
        #expect(engine.isWaitingForHit)
        #expect(engine.isInStrikeZone)
        #expect(engine.ball.position.z == GameEngine.levelOneHoldHeight)
    }

    @Test func levelOneUsesThreeHitsAndResetClearsProgress() {
        #expect(GameEngine.levelOneTarget == 3)
        let engine = GameEngine(classifier: StubClassifier(label: "bounce"))
        let frames = (0..<50).map {
            MotionFrame(timestamp: Double($0) / 100, features: Array(repeating: 0, count: 9))
        }
        engine.start()
        engine.processCapturedWindow(CapturedMotionWindow(frames: frames, peakMagnitude: 1.2))
        #expect(engine.score == 1)

        engine.resetToReady()
        #expect(engine.score == 0)
        #expect(engine.state == .ready)
        #expect(!engine.isPaused)
    }

    @Test func pausingFreezesTheBallUntilResumed() {
        let engine = GameEngine(classifier: StubClassifier(label: "bounce"))
        engine.start()
        let start = Date(timeIntervalSinceReferenceDate: 2_000)
        engine.tick(at: start)
        engine.setPaused(true)
        let frozenPosition = engine.ball.position
        engine.tick(at: start.addingTimeInterval(2))
        #expect(engine.ball.position == frozenPosition)

        engine.setPaused(false)
        engine.tick(at: start.addingTimeInterval(2.1))
        engine.tick(at: start.addingTimeInterval(2.2))
        #expect(engine.ball.position != frozenPosition)
    }

}

private struct StubClassifier: MotionClassifying {
    let label: String

    func classify(_ window: CapturedMotionWindow) throws -> MotionPrediction {
        MotionPrediction(label: label, confidence: 0.95)
    }
}
