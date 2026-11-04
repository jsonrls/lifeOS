import Testing
import RealityKit
import simd
import LifeCore
@testable import CityEngine

@MainActor
struct SceneTests {
    private func buildingEntities(_ scene: Entity) -> [Entity] {
        var found: [Entity] = []
        func walk(_ e: Entity) {
            if Picking.buildingID(fromEntityName: e.name) != nil { found.append(e) }
            e.children.forEach(walk)
        }
        walk(scene)
        return found
    }

    @Test func sceneContainsOneEntityPerCatalogBuilding() {
        let scene = CitySceneBuilder.makeScene()
        let ids = buildingEntities(scene).compactMap { Picking.buildingID(fromEntityName: $0.name) }
        #expect(ids.count == CityCatalog.buildings.count)
        #expect(Set(ids) == Set(CityCatalog.buildings.map(\.id)))
        for n in ["ground", "roads", "plaza"] { #expect(scene.findEntity(named: n) != nil) }
    }

    @Test func everyBuildingEntityHasCollisionAndInputTarget() {
        for e in buildingEntities(CitySceneBuilder.makeScene()) {
            #expect(e.components[CollisionComponent.self] != nil, "\(e.name)")
            #expect(e.components[InputTargetComponent.self] != nil, "\(e.name)")
        }
    }

    // The picking raycast only sees shapes whose filter matches both ways; [] groups or masks are invisible to it.
    @Test func buildingsUseTheDefaultCollisionFilter() {
        for e in buildingEntities(CitySceneBuilder.makeScene()) {
            #expect(e.components[CollisionComponent.self]?.filter == .default, "\(e.name)")
        }
    }

    // The renderer looks down the entity's -Z, so the transform must agree with the pure pose.
    @Test func cameraEntityLooksAtTheFocusWithScreenRightAlongPanAxis() {
        let s = CameraState(focusX: 5, focusZ: -3, zoom: 20, yawOffset: 0.2)
        let e = Entity()
        CityViewport.apply(s, to: e)
        let pose = s.cameraPose
        let m = e.transformMatrix(relativeTo: nil)
        let right = SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z)
        let back = SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z)
        let t = Float.pi / 4 + 0.2
        #expect(simd_length(e.position(relativeTo: nil) - pose.position) < 1e-3)
        #expect(simd_length(back - simd_normalize(pose.position - pose.target)) < 1e-4)
        #expect(simd_length(right - SIMD3(cos(t), 0, -sin(t))) < 1e-4)
    }

    @Test func cameraComponentMapsZoomToVerticalScaleAndContainsTheCity() throws {
        let e = Entity()
        CityViewport.apply(CameraState(focusX: 0, focusZ: 0, zoom: 20, yawOffset: 0), to: e)
        let c = try #require(e.components[OrthographicCameraComponent.self])
        #expect(c.scale == 20 && c.scaleDirection == .vertical)
        #expect(c.near < CameraState.cameraDistance - 120 && c.far > CameraState.cameraDistance + 120)
    }

    @Test func pickingNameRoundTrips() {
        for b in CityCatalog.buildings {
            #expect(Picking.buildingID(fromEntityName: Picking.entityName(for: b.id)) == b.id)
        }
    }

    @Test func pickingRejectsForeignNames() {
        #expect(Picking.buildingID(fromEntityName: "ground") == nil)
        #expect(Picking.buildingID(fromEntityName: "") == nil)
        #expect(Picking.buildingID(fromEntityName: "building:") == nil)
    }

    @Test func buildingEntityBoundsAreInsideCityBounds() {
        let scene = CitySceneBuilder.makeScene()
        for e in buildingEntities(scene) {
            let b = e.visualBounds(relativeTo: scene)
            #expect(b.extents.y > 1, "\(e.name) has no geometry")
            #expect(b.min.x >= -28 && b.max.x <= 28, "\(e.name)")
            #expect(b.min.z >= -28 && b.max.z <= 28, "\(e.name)")
            #expect(b.min.y >= -0.01 && b.max.y <= 30, "\(e.name)")
        }
    }

    @Test func collisionBoxWrapsVisibleBounds() throws {
        let scene = CitySceneBuilder.makeScene()
        for e in buildingEntities(scene) {
            let vis = e.visualBounds(relativeTo: e)
            let shape = try #require(e.components[CollisionComponent.self]?.shapes.first)
            let box = shape.bounds
            #expect(box.min.x <= vis.min.x + 0.01 && box.max.x >= vis.max.x - 0.01, "\(e.name) x")
            #expect(box.min.y <= vis.min.y + 0.01 && box.max.y >= vis.max.y - 0.01, "\(e.name) y")
            #expect(box.min.z <= vis.min.z + 0.01 && box.max.z >= vis.max.z - 0.01, "\(e.name) z")
            // Tight: no more than 0.05 of empty space per axis.
            #expect(box.extents.x <= vis.extents.x + 0.05 && box.extents.y <= vis.extents.y + 0.05
                    && box.extents.z <= vis.extents.z + 0.05, "\(e.name) loose")
        }
        // campus tops out at h + 0.2; slab depth is 0.6 of the inset footprint
        let campus = try #require(buildingEntities(scene).first { $0.name == Picking.entityName(for: "productivity.coworking-hub") })
        #expect(try #require(campus.components[CollisionComponent.self]?.shapes.first).bounds.max.y >= 5.2)
        let slab = try #require(buildingEntities(scene).first { $0.name == Picking.entityName(for: "productivity.planning-center") })
        #expect(try #require(slab.components[CollisionComponent.self]?.shapes.first).bounds.extents.z < 4)
    }
}
