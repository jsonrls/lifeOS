import AppKit
import RealityKit
import SwiftUI

/// The interactive 3D city: orthographic camera, pan/zoom/rotate gestures, hover and tap picking.
public struct CityViewport: View {
    @Binding private var camera: CameraState
    @Binding private var hoveredBuildingID: String?
    @Binding private var selectedBuildingID: String?
    private let onOpenBuilding: (String) -> Void

    @State private var cameraEntity = Entity()
    // GestureState, not State: a cancelled gesture never calls onEnded, and a stale baseline would jump the next one.
    @GestureState private var lastDrag: CGSize = .zero
    @GestureState private var lastMagnification: CGFloat = 1
    @GestureState private var lastRotation: Angle = .zero
    @State private var scrollSave: Task<Void, Never>?

    private let store = CameraStore(defaults: .standard)

    public init(camera: Binding<CameraState>, hoveredBuildingID: Binding<String?>,
                selectedBuildingID: Binding<String?>, onOpenBuilding: @escaping (String) -> Void) {
        _camera = camera
        _hoveredBuildingID = hoveredBuildingID
        _selectedBuildingID = selectedBuildingID
        self.onOpenBuilding = onOpenBuilding
    }

    public var body: some View {
        GeometryReader { geo in
            RealityView { content in
                content.add(CitySceneBuilder.makeScene())
                content.add(cameraEntity)
            } update: { _ in
                Self.apply(camera, to: cameraEntity)
            }
            .realityViewCameraControls(.none)  // our gestures drive the camera, not RealityKit's orbit
            .gesture(pan(viewHeight: Float(geo.size.height)))
            .simultaneousGesture(pinch)
            .simultaneousGesture(twist)
            .simultaneousGesture(select(in: geo.size))
            .simultaneousGesture(open(in: geo.size))
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let p): setHovered(buildingID(at: p, in: geo.size))
                case .ended: setHovered(nil)
                }
            }
            .background(ScrollWheelMonitor(onScroll: scroll))
            .background(Color(red: 0.80, green: 0.85, blue: 0.87))  // pale haze, same in light and dark mode
        }
    }

    static func apply(_ s: CameraState, to entity: Entity) {
        let pose = s.cameraPose
        entity.look(at: pose.target, from: pose.position, relativeTo: nil)
        var c = OrthographicCameraComponent()
        c.near = 1
        c.far = 2 * CameraState.cameraDistance
        c.scale = s.zoom
        c.scaleDirection = .vertical
        entity.components.set(c)
    }

    // MARK: gestures

    private func pan(viewHeight: Float) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($lastDrag) { v, last, _ in
                camera = camera.panned(screenDelta: [Float(v.translation.width - last.width),
                                                     Float(v.translation.height - last.height)],
                                       viewHeightPoints: viewHeight)
                last = v.translation
            }
            .onEnded { _ in store.save(camera) }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .updating($lastMagnification) { v, last, _ in
                camera = camera.zoomed(byFactor: Float(last / v.magnification))
                last = v.magnification
            }
            .onEnded { _ in store.save(camera) }
    }

    private var twist: some Gesture {
        RotateGesture()
            .updating($lastRotation) { v, last, _ in
                camera = camera.rotated(byRadians: Float((v.rotation - last).radians))
                last = v.rotation
            }
            .onEnded { _ in store.save(camera) }
    }

    /// A click that hits no building is a deselect, so one gesture covers both and they cannot race.
    private func select(in size: CGSize) -> some Gesture {
        SpatialTapGesture().onEnded { v in selectedBuildingID = buildingID(at: v.location, in: size) }
    }

    private func open(in size: CGSize) -> some Gesture {
        SpatialTapGesture(count: 2).onEnded { v in
            if let id = buildingID(at: v.location, in: size) { onOpenBuilding(id) }
        }
    }

    private func scroll(_ deltaY: Float, precise: Bool) {
        camera = camera.scrolled(deltaY: deltaY, precise: precise)
        scrollSave?.cancel()  // wheels have no end phase: save once scrolling goes quiet
        scrollSave = Task {
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled { store.save(camera) }
        }
    }

    // MARK: picking

    /// Casts our own parallel ray. RealityView's `entity(at:)`, `hitTest` and `targetedToAnyEntity`
    /// found nothing with this camera, and its `ray(through:)` fans out from the eye.
    private func buildingID(at p: CGPoint, in size: CGSize) -> String? {
        let ray = camera.pickRay(at: p, viewSize: size)
        return cameraEntity.scene?
            .raycast(origin: ray.origin, direction: ray.direction, length: 2 * CameraState.cameraDistance,
                     query: .nearest, relativeTo: nil)
            .first.flatMap { Picking.buildingID(fromEntityName: $0.entity.name) }
    }

    private func setHovered(_ id: String?) {
        if hoveredBuildingID != id { hoveredBuildingID = id }
    }
}

/// SwiftUI has no scroll wheel gesture on macOS. A local monitor sees wheel events without taking
/// mouse clicks away from the RealityView, and it lives only while this view is in a window.
/// shortcut: bounds check only, so floating panels over the city would zoom it too; add a hit test with the panels.
private struct ScrollWheelMonitor: NSViewRepresentable {
    let onScroll: @MainActor (Float, Bool) -> Void

    func makeNSView(context: Context) -> MonitorView { MonitorView() }
    func updateNSView(_ view: MonitorView, context: Context) { view.onScroll = onScroll }

    final class MonitorView: NSView {
        var onScroll: (@MainActor (Float, Bool) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] e in
                guard let self, e.window === self.window,
                      self.bounds.contains(self.convert(e.locationInWindow, from: nil)) else { return e }
                self.onScroll?(Float(e.scrollingDeltaY), e.hasPreciseScrollingDeltas)
                return nil
            }
        }
    }
}
