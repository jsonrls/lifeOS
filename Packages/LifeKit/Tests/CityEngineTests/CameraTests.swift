import CoreGraphics
import Foundation
import Testing
import simd
import LifeCore
@testable import CityEngine

private let deg20 = Float(20) * .pi / 180

@Test func zoomClampsAtBothEnds() {
    #expect(CameraState.cityView.zoomed(byFactor: 1e6).zoom == 60)
    #expect(CameraState.cityView.zoomed(byFactor: 1e-6).zoom == 6)
}

@Test func zoomIgnoresBadFactors() {
    for f in [Float.nan, .infinity, 0, -2] {
        #expect(CameraState.cityView.zoomed(byFactor: f) == .cityView)
    }
}

// Convention: dragging right moves the world right, so focus moves left on screen.
// At yawOffset 0 the camera yaw is 45 deg, so screen-right on the ground is (+x, -z)/sqrt2:
// focus moves (-x, +z) with equal magnitude.
@Test func panRightMovesWorldRightAtZeroYaw() {
    var s = CameraState.cityView; s.zoom = 20
    let p = s.panned(screenDelta: [100, 0], viewHeightPoints: 400)
    let step: Float = 10 / Float(2).squareRoot()
    #expect(abs(p.focusX + step) < 1e-4)
    #expect(abs(p.focusZ - step) < 1e-4)
}

// Dragging down moves the world down: focus moves toward screen-up, divided by sin(35 deg).
@Test func panDownMovesFocusUpScreenWithForeshortening() {
    var s = CameraState.cityView; s.zoom = 20
    let p = s.panned(screenDelta: [0, 100], viewHeightPoints: 400)
    let sinPitch: Float = sin(Float(35) * .pi / 180)
    let step: Float = 10 / sinPitch / Float(2).squareRoot()
    #expect(abs(p.focusX + step) < 1e-3)
    #expect(abs(p.focusZ + step) < 1e-3)
}

@Test func panAccountsForYaw() {
    var s = CameraState.cityView; s.zoom = 20; s.yawOffset = deg20
    let p = s.panned(screenDelta: [100, 0], viewHeightPoints: 400)
    let yaw = Float.pi / 4 + deg20
    let step: Float = 10
    #expect(abs(p.focusX + cos(yaw) * step) < 1e-4)
    #expect(abs(p.focusZ - sin(yaw) * step) < 1e-4)
}

@Test func panIgnoresZeroViewHeight() {
    #expect(CameraState.cityView.panned(screenDelta: [5, 5], viewHeightPoints: 0) == .cityView)
}

@Test func rotateClampsToTwentyDegrees() {
    #expect(abs(CameraState.cityView.rotated(byRadians: 10).yawOffset - deg20) < 1e-6)
    #expect(abs(CameraState.cityView.rotated(byRadians: -10).yawOffset + deg20) < 1e-6)
}

@Test func nonFiniteStateFallsBackToCityView() {
    for bad in [Float.nan, .infinity, -.infinity] {
        let s = CameraState(focusX: bad, focusZ: bad, zoom: bad, yawOffset: bad)
        #expect(s.clamped() == .cityView)
    }
}

@Test func mixedNonFiniteKeepsFiniteFields() {
    let s = CameraState(focusX: 5, focusZ: -6, zoom: .nan, yawOffset: 0.1).clamped()
    #expect(s == CameraState(focusX: 5, focusZ: -6, zoom: CameraState.cityView.zoom, yawOffset: 0.1))
}

@Test func zoomExtremeFactorsClampNotFallBack() {
    #expect(CameraState.cityView.zoomed(byFactor: .greatestFiniteMagnitude).zoom == 60)
    #expect(CameraState.cityView.zoomed(byFactor: .leastNonzeroMagnitude).zoom == 6)
}

@Test func nonFinitePanAndRotateAreIgnored() {
    let s = CameraState(focusX: 5, focusZ: 6, zoom: 20, yawOffset: 0.1)
    #expect(s.panned(screenDelta: [.nan, 1], viewHeightPoints: 400) == s)
    #expect(s.panned(screenDelta: [1, .infinity], viewHeightPoints: 400) == s)
    #expect(s.rotated(byRadians: .nan) == s)
    #expect(s.rotated(byRadians: -.infinity) == s)
}

@Test func hugeFinitePanAndRotateClampToBounds() {
    let s = CameraState(focusX: 5, focusZ: 6, zoom: 60, yawOffset: 0)
    let p = s.panned(screenDelta: [.greatestFiniteMagnitude, 0], viewHeightPoints: 1)
    #expect(p.focusX == -40 && p.focusZ == 40)
    #expect(s.rotated(byRadians: .greatestFiniteMagnitude).yawOffset == deg20)
    #expect(s.rotated(byRadians: -.greatestFiniteMagnitude).yawOffset == -deg20)
}

@Test func focusClampsToBounds() {
    let s = CameraState(focusX: 999, focusZ: -999, zoom: 20, yawOffset: 0).clamped()
    #expect(s.focusX == 40 && s.focusZ == -40)
}

@Test func districtViewCentersOnDistrict() {
    for d in CityCatalog.districts {
        let v = CameraState.districtView(d.bounds)
        #expect(v.focusX == d.bounds.center.x && v.focusZ == d.bounds.center.z)
        #expect(v == v.clamped())
    }
}

@Test func buildingViewCentersAndIsClamped() {
    for b in CityCatalog.buildings {
        let v = CameraState.buildingView(b)
        #expect(v.focusX == b.footprint.center.x && v.focusZ == b.footprint.center.z)
        #expect(v == v.clamped())
    }
}

// MARK: camera placement

@Test func poseSitsAtBaseYawAndPitch() {
    let (eye, target) = CameraState.cityView.cameraPose
    #expect(target == [0, 0, 0])
    let d = eye - target
    #expect(abs(simd_length(d) - CameraState.cameraDistance) < 1e-2)
    #expect(abs(d.x - d.z) < 1e-3 && d.x > 0)  // 45 deg: (sin t, cos t) are equal and positive
    #expect(abs(asin(d.y / simd_length(d)) - Float(35) * .pi / 180) < 1e-5)
}

@Test func poseFollowsFocusAndYaw() {
    let s = CameraState(focusX: 7, focusZ: -3, zoom: 20, yawOffset: deg20)
    let (eye, target) = s.cameraPose
    #expect(target == [7, 0, -3])
    let t = Float.pi / 4 + deg20
    let d = eye - target
    #expect(abs(atan2(d.x, d.z) - t) < 1e-5)
}

// The tested pan math and the camera placement must agree: a ground point follows the cursor exactly.
@Test func groundPointFollowsTheDragAtAnyYaw() {
    let size = CGSize(width: 1280, height: 800)
    for yaw in [-deg20, 0, deg20] {
        let s = CameraState(focusX: 3, focusZ: -2, zoom: 24, yawOffset: yaw)
        let p: SIMD3<Float> = [5, 0, 4]
        let before = s.screenPoint(of: p, viewSize: size)
        let after = s.panned(screenDelta: [70, -30], viewHeightPoints: 800).screenPoint(of: p, viewSize: size)
        #expect(abs(after.x - before.x - 70) < 0.01)
        #expect(abs(after.y - before.y + 30) < 0.01)
    }
}

@Test func visibleHalfHeightEqualsZoom() {
    let s = CameraState(focusX: 0, focusZ: 0, zoom: 20, yawOffset: 0)
    let size = CGSize(width: 1000, height: 600)
    let pose = s.cameraPose
    let forward = simd_normalize(pose.target - pose.position)
    let up = simd_cross(simd_normalize(simd_cross(forward, [0, 1, 0])), forward)
    #expect(abs(s.screenPoint(of: up * 20, viewSize: size).y) < 0.01)  // top edge of the view
    #expect(s.screenPoint(of: .zero, viewSize: size) == CGPoint(x: 500, y: 300))
}

@Test func pickRayPassesThroughTheProjectedPoint() {
    let size = CGSize(width: 1280, height: 800)
    let s = CameraState(focusX: 4, focusZ: -9, zoom: 18, yawOffset: -deg20)
    let p: SIMD3<Float> = [-6, 3, 11]
    let ray = s.pickRay(at: s.screenPoint(of: p, viewSize: size), viewSize: size)
    let along = simd_dot(p - ray.origin, ray.direction)
    #expect(simd_length(ray.origin + ray.direction * along - p) < 1e-3)
    #expect(abs(simd_length(ray.direction) - 1) < 1e-5)
}

// Rotating the fingers clockwise turns the world clockwise on screen.
@Test func positiveRotationTurnsWorldClockwise() {
    let size = CGSize(width: 800, height: 800)
    let p: SIMD3<Float> = [10, 0, -10]  // straight right of center at yaw 0
    let a = CameraState.cityView.screenPoint(of: p, viewSize: size)
    let b = CameraState.cityView.rotated(byRadians: 0.2).screenPoint(of: p, viewSize: size)
    #expect(abs(a.y - 400) < 0.01 && b.y > a.y)  // right-side point moves down
}

@Test func scrollUpZoomsInAndWheelNotchIsCoarser() {
    let s = CameraState.cityView
    #expect(s.scrolled(deltaY: 10, precise: true).zoom < s.zoom)
    #expect(s.scrolled(deltaY: -10, precise: true).zoom > s.zoom)
    #expect(s.scrolled(deltaY: 1, precise: false).zoom < s.scrolled(deltaY: 1, precise: true).zoom)
    #expect(s.scrolled(deltaY: 1e9, precise: true).zoom == 6)
    #expect(s.scrolled(deltaY: -1e9, precise: true).zoom == 60)
}

private func freshDefaults() -> (UserDefaults, String) {
    let name = "lifeos.test.\(UUID().uuidString)"
    return (UserDefaults(suiteName: name)!, name)
}

@Test func storeRoundTrips() {
    let (d, name) = freshDefaults(); defer { d.removePersistentDomain(forName: name) }
    let store = CameraStore(defaults: d)
    let s = CameraState(focusX: 3, focusZ: -4, zoom: 12, yawOffset: 0.1)
    store.save(s)
    #expect(store.load() == s)
}

@Test func storeFallsBackOnCorruptData() {
    let (d, name) = freshDefaults(); defer { d.removePersistentDomain(forName: name) }
    d.set(Data([0xDE, 0xAD, 0xBE, 0xEF]), forKey: "lifeos.camera")
    #expect(CameraStore(defaults: d).load() == .cityView)
}

@Test func storeFallsBackOnOutOfRangeValues() {
    let (d, name) = freshDefaults(); defer { d.removePersistentDomain(forName: name) }
    let store = CameraStore(defaults: d)
    store.save(CameraState(focusX: 500, focusZ: 0, zoom: 1000, yawOffset: 5))
    #expect(store.load() == .cityView)
}
