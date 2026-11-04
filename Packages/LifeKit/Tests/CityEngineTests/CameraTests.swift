import Foundation
import Testing
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
    let s = store.load()
    #expect(s.focusX == 40 && s.zoom == 60 && abs(s.yawOffset - deg20) < 1e-6)
}
