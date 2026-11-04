import CityEngine
import LifeCore
import SwiftUI

/// The city fills the window; the Mac chrome floats above it.
struct MainView: View {
    @Bindable var store: CityStore
    @State private var panels: [CGRect] = []
    @State private var opened: String?
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            CityViewport(camera: $store.camera, hoveredBuildingID: $store.hoveredBuildingID,
                         selectedBuildingID: Binding(get: { store.selectedBuildingID }, set: { store.select($0) }),
                         obstructions: panels, onOpenBuilding: { opened = $0 })
                .withFrameProbe()
                .ignoresSafeArea()
            VStack(spacing: 12) {
                TopBar().panel()
                HStack(alignment: .top) {
                    DistrictNavigator(store: store).panel()
                    Spacer(minLength: 0)
                    if let b = store.selectedBuildingID.flatMap(CityCatalog.building(id:)) {
                        BuildingInspector(building: b).panel()
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                Button { } label: { Label("Ask the Mayor", systemImage: "sparkles").padding(.horizontal, 6) }
                    .disabled(true)
                    .help("Coming in a later phase")
                    .panel()
            }
            .padding(16)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onPreferenceChange(PanelFrames.self) { panels = $0 }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .accessibilityElement(children: .contain)  // the focus target is a container, not an unlabeled group
        .accessibilityLabel("Life OS")
        .onAppear { focused = true }
        .onExitCommand { store.escape() }
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: store.selectedBuildingID)
        #if DEBUG
        .task {
            await DebugDriver.runIfRequested(.init(
                camera: $store.camera, hovered: $store.hoveredBuildingID,
                selected: Binding(get: { store.selectedBuildingID }, set: { store.select($0) }),
                opened: { opened }, store: store))
        }
        #endif
    }
}

private struct TopBar: View {
    var body: some View {
        HStack(spacing: 14) {
            Text("Life OS").font(.headline)
            Text("City Level 1").foregroundStyle(.primary.opacity(0.85))
            Text(Date.now, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                .foregroundStyle(.primary.opacity(0.85))
        }
        .font(.callout)
        .padding(.horizontal, 16).padding(.vertical, 8)
    }
}

// MARK: floating panels

/// Frames of every floating panel in window coordinates, so the viewport can leave scrolling over them alone.
private struct PanelFrames: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

extension CityViewport {
    func withFrameProbe() -> some View {
        #if DEBUG
        frameProbe(FrameLog.tick)
        #else
        self
        #endif
    }
}

extension View {
    /// Liquid Glass card that also takes clicks, so they never reach the city behind it.
    func panel() -> some View {
        self
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.8), in: .rect(cornerRadius: 16))  // keeps text contrast over any city or sky behind the glass
            .contentShape(.rect(cornerRadius: 16))
            .background(GeometryReader { Color.clear.preference(key: PanelFrames.self, value: [$0.frame(in: .global)]) })
    }
}
