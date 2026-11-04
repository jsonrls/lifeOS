import Testing
import RealityKit
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
}
