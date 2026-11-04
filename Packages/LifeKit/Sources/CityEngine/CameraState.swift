import Foundation
import LifeCore

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
    public func panned(screenDelta d: SIMD2<Float>, viewHeightPoints: Float) -> CameraState {
        guard viewHeightPoints > 0, viewHeightPoints.isFinite else { return self }
        let k = 2 * zoom / viewHeightPoints
        let t = Self.baseYaw + yawOffset
        let right = SIMD2<Float>(cos(t), -sin(t))
        let up = SIMD2<Float>(-sin(t), -cos(t))
        let move = -right * (d.x * k) + up * (d.y * k / sin(Self.pitch))
        var s = self
        s.focusX += move.x; s.focusZ += move.y
        return s.clamped()
    }

    public func zoomed(byFactor f: Float) -> CameraState {
        guard f.isFinite, f > 0 else { return self }
        var s = self; s.zoom *= f
        return s.clamped()
    }

    public func rotated(byRadians r: Float) -> CameraState {
        var s = self; s.yawOffset += r
        return s.clamped()
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
