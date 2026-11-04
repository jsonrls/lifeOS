import CityEngine
import SwiftUI

@main
struct LifeOSApp: App {
    var body: some Scene {
        WindowGroup { CityScreen() }
            .defaultSize(width: 1280, height: 800)
    }
}

/// Temporary host for the viewport. The app shell task replaces it.
private struct CityScreen: View {
    @State private var camera = CameraStore(defaults: .standard).load()
    @State private var hovered: String?
    @State private var selected: String?
    @State private var opened: String?

    var body: some View {
        CityViewport(camera: $camera, hoveredBuildingID: $hovered, selectedBuildingID: $selected,
                     onOpenBuilding: { opened = $0 })
            .ignoresSafeArea()
            .overlay(alignment: .bottomLeading) {
                Text(selected ?? "nothing selected")
                    .font(.callout.monospaced())
                    .padding(8)
                    .background(.regularMaterial, in: .rect(cornerRadius: 8))
                    .padding()
            }
            #if DEBUG
            .task {
                await DebugDriver.runIfRequested(.init(camera: $camera, hovered: $hovered, selected: $selected,
                                                       opened: { opened }))
            }
            #endif
    }
}
