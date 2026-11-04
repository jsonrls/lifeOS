import CoreGraphics
import Foundation
import LifeCore
import simd

public struct CameraState: Codable, Equatable, Sendable {
    public var focusX: Float
    public var focusZ: Float
    /// Orthographic half-height in world units, 6...60.
    public var zoom: Float
    /// Radians, within +-20 degrees.
    public var yawOffset: Float

    public init(focusX: Float, focusZ: Float, zoom: Float, yawOffset: Float) {
        self.focusX = focusX; self.focusZ = focusZ; self.zoom = zoom; self.yawOffset = yawOffset
    }

    static let zoomRange: ClosedRange<Float> = 6...60
    static let maxYaw: Float = 20 * .pi / 180
    static let maxFocus: Float = 40
    static let baseYaw: Float = .pi / 4
    static let pitch: Float = 35 * .pi / 180

    // Zoom 32 fits the ~+-27 tile city on a typical landscape window.
    public static let cityView = CameraState(focusX: 0, focusZ: 0, zoom: 32, yawOffset: 0)

    public static func districtView(_ b: TileRect) -> CameraState {
        CameraState(focusX: b.center.x, focusZ: b.center.z, zoom: 16, yawOffset: 0).clamped()
    }

    public static func buildingView(_ b: BuildingDefinition) -> CameraState {
        let f = b.footprint
        return CameraState(focusX: f.center.x, focusZ: f.center.z,
                           zoom: Float(max(f.width, f.depth)) + 6, yawOffset: 0).clamped()
    }

    /// Sign convention: the world follows the cursor, so focus moves opposite to the drag.
    /// Camera yaw t gives ground right = (cos t, -sin t) and ground up = (-sin t, -cos t) in (x, z).
    /// Math runs in Double so huge finite inputs clamp to the bounds instead of overflowing Float.
    public func panned(screenDelta d: SIMD2<Float>, viewHeightPoints: Float) -> CameraState {
        guard viewHeightPoints > 0, viewHeightPoints.isFinite, d.x.isFinite, d.y.isFinite else { return self }
        let k = 2 * Double(zoom) / Double(viewHeightPoints)
        let t = Double(Self.baseYaw) + Double(yawOffset)
        let dx = Double(d.x) * k
        let dy = Double(d.y) * k / Double(sin(Self.pitch))
        let mx = -dx * cos(t) - dy * sin(t)
        let mz = dx * sin(t) - dy * cos(t)
        var s = self
        s.focusX = Self.clampD(Double(focusX) + mx, Double(Self.maxFocus))
        s.focusZ = Self.clampD(Double(focusZ) + mz, Double(Self.maxFocus))
        return s.clamped()
    }

    public func zoomed(byFactor f: Float) -> CameraState {
        guard f.isFinite, f > 0 else { return self }
        var s = self
        s.zoom = Float(min(max(Double(zoom) * Double(f), Double(Self.zoomRange.lowerBound)), Double(Self.zoomRange.upperBound)))
        return s.clamped()
    }

    public func rotated(byRadians r: Float) -> CameraState {
        guard r.isFinite else { return self }
        var s = self
        s.yawOffset = Self.clampD(Double(yawOffset) + Double(r), Double(Self.maxYaw))
        return s.clamped()
    }

    /// Line-based wheels report whole notches, trackpads report points.
    public func scrolled(deltaY: Float, precise: Bool) -> CameraState {
        zoomed(byFactor: exp(min(max(-deltaY * (precise ? 0.01 : 0.1), -10), 10)))
    }

    private static func clampD(_ v: Double, _ bound: Double) -> Float {
        Float(min(max(v, -bound), bound))
    }

    public func clamped() -> CameraState {
        let d = Self.cityView
        func ok(_ v: Float, _ fallback: Float, _ r: ClosedRange<Float>) -> Float {
            v.isFinite ? min(max(v, r.lowerBound), r.upperBound) : fallback
        }
        let m = Self.maxFocus
        return CameraState(focusX: ok(focusX, d.focusX, -m...m), focusZ: ok(focusZ, d.focusZ, -m...m),
                           zoom: ok(zoom, d.zoom, Self.zoomRange),
                           yawOffset: ok(yawOffset, d.yawOffset, -Self.maxYaw...Self.maxYaw))
    }
}

// MARK: camera placement

public extension CameraState {
    /// Far enough that the whole city stays in front of the near plane at any clamped focus.
    static let cameraDistance: Float = 200

    /// Eye sits at focus + (sin t, cos t) on (x, z), t = 45 deg + yaw, raised to the pitch.
    /// This is the placement `panned` assumes, so the axes there and here must stay in step.
    var cameraPose: (position: SIMD3<Float>, target: SIMD3<Float>) {
        let t = Self.baseYaw + yawOffset
        let target = SIMD3<Float>(focusX, 0, focusZ)
        let flat = Self.cameraDistance * cos(Self.pitch)
        return (target + [flat * sin(t), Self.cameraDistance * sin(Self.pitch), flat * cos(t)], target)
    }

    private var cameraAxes: (right: SIMD3<Float>, up: SIMD3<Float>, forward: SIMD3<Float>) {
        let pose = cameraPose
        let forward = simd_normalize(pose.target - pose.position)
        let right = simd_normalize(simd_cross(forward, [0, 1, 0]))
        return (right, simd_cross(right, forward), forward)
    }

    /// Orthographic projection to view points, origin top-left. The focus lands at the view center.
    func screenPoint(of p: SIMD3<Float>, viewSize: CGSize) -> CGPoint {
        let axes = cameraAxes
        let d = p - cameraPose.target
        let pointsPerUnit = Float(viewSize.height) / (2 * zoom)
        return CGPoint(x: viewSize.width / 2 + CGFloat(simd_dot(d, axes.right) * pointsPerUnit),
                       y: viewSize.height / 2 - CGFloat(simd_dot(d, axes.up) * pointsPerUnit))
    }

    /// Inverse of `screenPoint`: orthographic rays are parallel, so only the origin moves with the point.
    func pickRay(at p: CGPoint, viewSize: CGSize) -> (origin: SIMD3<Float>, direction: SIMD3<Float>) {
        let axes = cameraAxes
        let unitsPerPoint = 2 * zoom / Float(viewSize.height)
        let dx = Float(p.x - viewSize.width / 2) * unitsPerPoint
        let dy = Float(viewSize.height / 2 - p.y) * unitsPerPoint
        return (cameraPose.position + axes.right * dx + axes.up * dy, axes.forward)
    }
}
