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
}
