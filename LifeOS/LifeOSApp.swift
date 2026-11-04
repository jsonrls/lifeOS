import CityEngine
import LifeCore
import AppKit
import SwiftUI

@main
struct LifeOSApp: App {
    @State private var store: CityStore
    private let cameras = CameraStore(defaults: .standard)

    init() {
        let cameras = CameraStore(defaults: .standard)
        _store = State(initialValue: CityStore(camera: cameras.load(), persist: cameras.save))
    }

    var body: some Scene {
        WindowGroup {
            MainView(store: store)
                // A quit mid-drag or within 300 ms of a scroll would otherwise lose the last camera move.
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    cameras.save(store.camera)
                }
        }
            .defaultSize(width: 1280, height: 800)
            .windowResizability(.contentMinSize)
            .commands {
                CommandGroup(replacing: .newItem) {}  // one window: all windows would share one store
                CityCommands(store: store)
            }
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
