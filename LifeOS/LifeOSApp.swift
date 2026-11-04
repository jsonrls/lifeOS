import CityEngine
import LifeCore
import SwiftUI

@main
struct LifeOSApp: App {
    @State private var store: CityStore

    init() {
        let cameras = CameraStore(defaults: .standard)
        _store = State(initialValue: CityStore(camera: cameras.load(), persist: cameras.save))
    }

    var body: some Scene {
        WindowGroup { MainView(store: store) }
            .defaultSize(width: 1280, height: 800)
            .windowResizability(.contentMinSize)
            .commands { CityCommands(store: store) }
        Settings { Text("Settings").padding(40).frame(minWidth: 320) }
    }
}

/// ⌘1 City View, ⌘2...⌘6 districts in navigator order. Esc lives on MainView (`onExitCommand`), so Settings keeps its own.
private struct CityCommands: Commands {
    let store: CityStore

    var body: some Commands {
        CommandMenu("City") {
            Button("City View") { store.showCity() }.keyboardShortcut("1")
            ForEach(Array(DistrictType.navigatorOrder.enumerated()), id: \.element) { i, d in
                Button(d.displayName) { store.focus(d) }
                    .keyboardShortcut(KeyEquivalent(Character("\(i + 2)")))
            }
        }
    }
}
