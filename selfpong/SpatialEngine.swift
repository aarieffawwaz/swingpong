import CoreGraphics
import CoreMotion
import Foundation

struct BallState: Equatable {
    var position = SIMD3<Double>(0, 0, 0.2)
    var velocity = SIMD3<Double>(0, 0, 0)
    var trail: [SIMD3<Double>] = []
}

struct ProjectedBall {
    let point: CGPoint
    let edgePoint: CGPoint
    let isVisible: Bool
    let isBehind: Bool
    let size: Double
    let indicatorOpacity: Double
    let direction: CGVector
}

enum SpatialEngine {
    static let fieldOfViewDegrees = 64.0
    static let edgeMargin = 34.0

    static func project(position: SIMD3<Double>, rotation: CMRotationMatrix, canvasSize: CGSize) -> ProjectedBall {
        let view = multiply(rotation, position)
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let focalLength = min(canvasSize.width, canvasSize.height) * 0.5
            / tan(fieldOfViewDegrees * .pi / 360)
        let isBehind = view.z <= 0.01
        let safeDepth = max(abs(view.z), 0.01)
        let rawPoint = CGPoint(
            x: center.x + view.x / safeDepth * focalLength,
            y: center.y - view.y / safeDepth * focalLength
        )

        let visibleRect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: edgeMargin, dy: edgeMargin)
        let isVisible = !isBehind && visibleRect.contains(rawPoint)

        var direction = CGVector(dx: rawPoint.x - center.x, dy: rawPoint.y - center.y)
        if isBehind {
            direction = CGVector(dx: -direction.dx, dy: -direction.dy)
        }
        if abs(direction.dx) + abs(direction.dy) < 0.001 {
            direction = CGVector(dx: 0, dy: -1)
        }

        let halfWidth = max(canvasSize.width / 2 - edgeMargin, 1)
        let halfHeight = max(canvasSize.height / 2 - edgeMargin, 1)
        let scaleX = halfWidth / max(abs(direction.dx), 0.001)
        let scaleY = halfHeight / max(abs(direction.dy), 0.001)
        let scale = min(scaleX, scaleY)
        let edgePoint = CGPoint(x: center.x + direction.dx * scale,
                                y: center.y + direction.dy * scale)

        let distance = max(position.z, 0.15)
        let ballSize = min(max(88 / (0.55 + distance), 24), 88)
        let offAxis = hypot(view.x, view.y) / safeDepth
        let opacity = isBehind ? 0.48 : min(max(1.05 - offAxis * 0.22, 0.38), 1)

        return ProjectedBall(point: rawPoint,
                             edgePoint: edgePoint,
                             isVisible: isVisible,
                             isBehind: isBehind,
                             size: ballSize,
                             indicatorOpacity: opacity,
                             direction: direction)
    }

    static func identityRotation() -> CMRotationMatrix {
        CMRotationMatrix(m11: 1, m12: 0, m13: 0,
                         m21: 0, m22: 1, m23: 0,
                         m31: 0, m32: 0, m33: 1)
    }

    static func simulatedRotation(horizontal: Double, vertical: Double) -> CMRotationMatrix {
        let yaw = horizontal
        let pitch = vertical
        let cy = cos(yaw), sy = sin(yaw)
        let cp = cos(pitch), sp = sin(pitch)
        return CMRotationMatrix(m11: cy, m12: sy * sp, m13: sy * cp,
                                m21: 0, m22: cp, m23: -sp,
                                m31: -sy, m32: cy * sp, m33: cy * cp)
    }

    private static func multiply(_ matrix: CMRotationMatrix, _ vector: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(
            matrix.m11 * vector.x + matrix.m12 * vector.y + matrix.m13 * vector.z,
            matrix.m21 * vector.x + matrix.m22 * vector.y + matrix.m23 * vector.z,
            matrix.m31 * vector.x + matrix.m32 * vector.y + matrix.m33 * vector.z
        )
    }
}
