import CityEngine
import LifeCore
import Observation

/// Shared city state. CityViewport saves the camera after its own gestures; the store saves
/// the moves it makes itself, through `persist`, so each change is saved once.
@MainActor @Observable final class CityStore {
    var camera: CameraState
    var selectedBuildingID: String?
    var hoveredBuildingID: String?
    var focusedDistrict: DistrictType?
    private let persist: (CameraState) -> Void

    init(camera: CameraState = .cityView, persist: @escaping (CameraState) -> Void = { _ in }) {
        self.camera = camera
        self.persist = persist
    }

    /// Unknown ids are ignored. `nil` clears the selection and leaves the focused district alone.
    func select(_ id: String?) {
        guard let id else { selectedBuildingID = nil; return }
        guard let b = CityCatalog.building(id: id) else { return }
        selectedBuildingID = id
        focusedDistrict = b.district
    }

    func focus(_ d: DistrictType) {
        guard let bounds = CityCatalog.districts.first(where: { $0.id == d })?.bounds else { return }
        focusedDistrict = d
        move(to: .districtView(bounds))
    }

    /// Select a building and frame it, for navigator rows. Clicking in the city selects without moving the camera.
    func goTo(_ id: String) {
        guard let b = CityCatalog.building(id: id) else { return }
        select(id)
        move(to: .buildingView(b))
    }

    func showCity() {
        selectedBuildingID = nil
        focusedDistrict = nil
        move(to: .cityView)
    }

    /// Deselect first; with nothing selected, return to City View.
    func escape() {
        if selectedBuildingID != nil { selectedBuildingID = nil } else { showCity() }
    }

    private func move(to c: CameraState) {
        camera = c
        persist(c)
    }
}
