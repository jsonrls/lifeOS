import Testing
@testable import LifeCore

@Suite struct CatalogTests {
    @Test func buildingIDsAreUnique() {
        let ids = CityCatalog.buildings.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyBuildingFootprintLiesInsideItsDistrictBounds() {
        for b in CityCatalog.buildings {
            let bounds = b.district == nil
                ? CityCatalog.plazaBounds
                : CityCatalog.districts.first { $0.id == b.district }!.bounds
            #expect(bounds.contains(b.footprint), "\(b.id)")
        }
    }

    @Test func noTwoFootprintsOverlap() {
        let all = CityCatalog.buildings
        for i in all.indices {
            for j in all.indices where j > i {
                #expect(!all[i].footprint.intersects(all[j].footprint), "\(all[i].id) vs \(all[j].id)")
            }
        }
    }

    @Test func districtBoundsDoNotOverlapEachOther() {
        let d = CityCatalog.districts
        for i in d.indices {
            #expect(!d[i].bounds.intersects(CityCatalog.plazaBounds))
            for j in d.indices where j > i {
                #expect(!d[i].bounds.intersects(d[j].bounds), "\(d[i].id) vs \(d[j].id)")
            }
        }
    }

    @Test func eachDistrictHasFourBuildingsAndTotalIs21() {
        #expect(CityCatalog.buildings.count == 21)
        for t in DistrictType.allCases {
            #expect(CityCatalog.buildings(in: t).count == 4, "\(t)")
        }
    }

    @Test func noTwoBuildingsInOneDistrictShareStyleAndHeight() {
        for t in DistrictType.allCases {
            let keys = CityCatalog.buildings(in: t).map { "\($0.style)-\($0.heightUnits)" }
            #expect(Set(keys).count == keys.count, "\(t)")
        }
    }

    @Test func tileRectIntersectsIsFalseForTouchingEdges() {
        let a = TileRect(x: 0, z: 0, width: 4, depth: 4)
        #expect(!a.intersects(TileRect(x: 4, z: 0, width: 4, depth: 4)))
        #expect(!a.intersects(TileRect(x: 0, z: 4, width: 4, depth: 4)))
        #expect(a.intersects(TileRect(x: 3, z: 3, width: 4, depth: 4)))
    }

    @Test func lookupByIDReturnsNilForUnknown() {
        #expect(CityCatalog.building(id: "nope") == nil)
        #expect(CityCatalog.building(id: "productivity.office-tower") != nil)
    }

    @Test func layoutIsCompactAndHallIsTallest() {
        for d in CityCatalog.districts {
            #expect(abs(d.bounds.center.x) <= 40 && abs(d.bounds.center.z) <= 40)
        }
        #expect(CityCatalog.buildings.allSatisfy { $0.maxLevel == 5 })
        #expect(CityCatalog.buildings.max { $0.heightUnits < $1.heightUnits }?.id == CityCatalog.cityHall.id)
    }
}
