import CityEngine
import LifeCore
import Testing
@testable import LifeOS

@MainActor struct CityStoreTests {
    @Test func escapeClearsSelectionThenReturnsToCityView() {
        let s = CityStore()
        s.focus(.finance)
        s.select("finance.central-bank")
        s.escape()
        #expect(s.selectedBuildingID == nil)
        #expect(s.camera != .cityView, "first Esc only deselects")
        #expect(s.focusedDistrict == .finance)
        s.escape()
        #expect(s.camera == .cityView)
        #expect(s.focusedDistrict == nil)
    }

    @Test func selectingBuildingFocusesItsDistrict() {
        let s = CityStore()
        s.select("health.medical-center")
        #expect(s.selectedBuildingID == "health.medical-center")
        #expect(s.focusedDistrict == .health)
        s.select("city-hall")
        #expect(s.focusedDistrict == nil)
    }

    @Test func focusDistrictSetsDistrictViewCamera() {
        let s = CityStore()
        let d = CityCatalog.districts.first { $0.id == .personal }!
        s.focus(.personal)
        #expect(s.camera == .districtView(d.bounds))
        #expect(s.focusedDistrict == .personal)
    }

    @Test func selectUnknownIDIsIgnored() {
        let s = CityStore()
        s.select("city-hall")
        s.select("nope")
        #expect(s.selectedBuildingID == "city-hall")
        s.select(nil)
        #expect(s.selectedBuildingID == nil)
    }

    @Test func showCityResetsCameraAndFocus() {
        let s = CityStore()
        s.focus(.health)
        s.select("health.fitness-center")
        s.showCity()
        #expect(s.camera == .cityView)
        #expect(s.focusedDistrict == nil)
        #expect(s.selectedBuildingID == nil)
    }

    @Test func goToSelectsAndFramesBuilding() {
        let s = CityStore()
        s.goTo("finance.marketplace")
        #expect(s.selectedBuildingID == "finance.marketplace")
        #expect(s.camera == .buildingView(CityCatalog.building(id: "finance.marketplace")!))
    }

    @Test func focusingAnotherDistrictClearsStaleSelection() {
        let s = CityStore()
        s.select("finance.central-bank")
        s.focus(.health)
        #expect(s.selectedBuildingID == nil)
        s.select("city-hall")
        s.focus(.health)
        #expect(s.selectedBuildingID == nil)
    }

    @Test func focusingSameDistrictKeepsSelection() {
        let s = CityStore()
        s.select("finance.central-bank")
        s.focus(.finance)
        #expect(s.selectedBuildingID == "finance.central-bank")
    }

    @Test func programmaticMovesPersistOnceAndSelectDoesNot() {
        var saved: [CameraState] = []
        let s = CityStore(persist: { saved.append($0) })
        s.select("finance.central-bank")
        #expect(saved.isEmpty)
        s.focus(.finance)
        #expect(saved.count == 1)
        s.goTo("finance.marketplace")
        #expect(saved.count == 2)
        s.showCity()
        #expect(saved.count == 3)
        #expect(saved.last == .cityView)
        s.escape()  // nothing selected: returns to City View, one save
        #expect(saved.count == 4)
    }

    @Test func everyBuildingIsReachableFromNavigatorRows() {
        var reachable = Set<String>()
        for focused in [nil] + DistrictType.allCases.map(Optional.some) {
            for r in NavigatorRows.rows(focused: focused) { if case .goTo(let id) = r.action { reachable.insert(id) } }
        }
        #expect(reachable == Set(CityCatalog.buildings.map(\.id)))
        let hall = NavigatorRows.rows(focused: nil).first!
        #expect(hall.label == "City Hall, Central Plaza")
    }
}
