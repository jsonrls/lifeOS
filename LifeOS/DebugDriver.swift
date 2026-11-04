#if DEBUG
import AppKit
import CityEngine
import LifeCore
import SwiftUI

/// Frame cadence from RealityKit's per-frame scene update, plus click latency. Perf numbers only, never shipped.
@MainActor enum FrameLog {
    static var dts: [Double] = []
    static var first: ContinuousClock.Instant?
    static var lastFrame: ContinuousClock.Instant = .now
    static var recording = false

    static func tick(_ dt: TimeInterval) {
        lastFrame = .now
        if first == nil { first = .now; print("first frame at \(Date().timeIntervalSince(processStart)) s after process start (SceneEvents.Update)") }
        if recording { dts.append(dt) }
    }

    static var processStart: Date {
        var info = kinfo_proc(), size = MemoryLayout<kinfo_proc>.stride, mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        sysctl(&mib, 4, &info, &size, nil, 0)
        let t = info.kp_proc.p_starttime
        return Date(timeIntervalSince1970: Double(t.tv_sec) + Double(t.tv_usec) / 1e6)
    }

    static func summary(_ name: String) {
        recording = false
        let d = dts.sorted(); defer { dts = [] }
        guard d.count > 1 else { return print("perf \(name): \(d.count) frames") }
        let total = d.reduce(0, +)
        func p(_ q: Double) -> Double { d[min(d.count - 1, Int(q * Double(d.count)))] * 1000 }
        print(String(format: "perf %@: %d frames in %.2f s = %.1f fps; frame ms p50 %.1f p95 %.1f p99 %.1f max %.1f; >20ms frames %d",
                     name, d.count, total, Double(d.count) / total, p(0.5), p(0.95), p(0.99), d.last! * 1000, d.filter { $0 > 0.020 }.count))
        fflush(stdout)
    }
}

/// Verification harness for machines where the shell has no screen recording or input-posting
/// permission. Set LIFEOS_DRIVE to `;`-separated steps and it posts real NSEvents to the
/// app's event queue, so they travel the normal AppKit and SwiftUI event path. Inert without the variable.
@MainActor enum DebugDriver {
    struct State {
        let camera: Binding<CameraState>
        let hovered: Binding<String?>
        let selected: Binding<String?>
        let opened: () -> String?
        let store: CityStore
    }

    static func runIfRequested(_ s: State) async {
        guard let script = ProcessInfo.processInfo.environment["LIFEOS_DRIVE"] else { return }
        try? await Task.sleep(for: .seconds(2))
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try? await Task.sleep(for: .milliseconds(500))
        print("active=\(NSApp.isActive) key=\(window.isKeyWindow) main=\(window.isMainWindow) visible=\(window.occlusionState.contains(.visible))")
        for step in script.split(separator: ";") {
            let a = step.split(separator: " ").map(String.init)
            guard let cmd = a.first else { continue }
            await run(cmd, Array(a.dropFirst()), s)
            try? await Task.sleep(for: .milliseconds(500))
            report(String(step), s)
        }
        NSApp.terminate(nil)
    }

    private static var window: NSWindow { NSApp.windows.first { $0.contentView != nil && $0.isVisible }! }
    private static var size: CGSize { window.contentView!.bounds.size }

    private static func report(_ step: String, _ s: State) {
        let c = s.camera.wrappedValue
        print("[\(step)] focus=(\(c.focusX), \(c.focusZ)) zoom=\(c.zoom) yaw=\(c.yawOffset)"
              + " district=\(s.store.focusedDistrict?.rawValue ?? "nil") selected=\(s.selected.wrappedValue ?? "nil") hovered=\(s.hovered.wrappedValue ?? "nil")"
              + " opened=\(s.opened() ?? "nil") view=\(size)")
        fflush(stdout)
    }

    private static func run(_ cmd: String, _ a: [String], _ s: State) async {
        let f = a.compactMap(Double.init)
        switch cmd {
        case "shot": shot(a[0])
        case "size": window.setContentSize(CGSize(width: f[0], height: f[1]))
        case "set": s.camera.wrappedValue = CameraState(focusX: Float(f[0]), focusZ: Float(f[1]), zoom: Float(f[2]), yawOffset: Float(f[3]))
        case "click": await click(point(a, s), count: 1)
        case "dclick": await click(point(a, s), count: 2)
        case "hover":
            hover(point(a, s))
            try? await Task.sleep(for: .milliseconds(60))
            print("hovered right after move: \(s.hovered.wrappedValue ?? "nil")")
        case "drag": await drag(from: point(a, s), by: CGSize(width: f[f.count - 2], height: f[f.count - 1]))
        case "pinch": await trackpad(hidType: 8, valueField: 113, value: f[0], times: Int(f[1]))
        case "twist": await trackpad(hidType: 5, valueField: 114, value: f[0], times: Int(f[1]))
        case "scroll":  // scroll <lines> <times> [p <x> <y>]; the view center without a point
            await scroll(lines: Int32(f[0]), times: Int(f[1]),
                         at: f.count >= 4 ? CGPoint(x: f[2], y: f[3]) : CGPoint(x: size.width / 2, y: size.height / 2))
        case "perfstart": FrameLog.dts = []; FrameLog.recording = true
        case "perfend": FrameLog.summary(a.first ?? "")
        case "latency": await latency(point(a, s), s)
        case "key": key(a[0], command: true)  // key <char>: ⌘ + char
        case "esc": key("\u{1b}", command: false, code: 53)
        default: print("unknown step \(cmd)")
        }
    }

    /// `b <building-id>`, or `w <x> <y> <z>` for a world point, or `p <x> <y>` for view points.
    private static func point(_ a: [String], _ s: State) -> CGPoint {
        let cam = s.camera.wrappedValue
        switch a[0] {
        case "b":
            let c = CityCatalog.buildings.first { $0.id == a[1] }!.footprint.center
            return cam.screenPoint(of: [c.x, 1, c.z], viewSize: size)
        case "w":
            return cam.screenPoint(of: [Float(a[1])!, Float(a[2])!, Float(a[3])!], viewSize: size)
        default:
            return CGPoint(x: Double(a[1])!, y: Double(a[2])!)
        }
    }

    private static func mouse(_ type: NSEvent.EventType, _ p: CGPoint, clicks: Int = 1) {
        let loc = CGPoint(x: p.x, y: size.height - p.y)
        NSApp.postEvent(NSEvent.mouseEvent(with: type, location: loc, modifierFlags: [],
                                           timestamp: ProcessInfo.processInfo.systemUptime,
                                           windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                           clickCount: clicks, pressure: 1)!, atStart: false)
    }

    /// Without a real cursor over the window no tracking area is entered, so queued moves go nowhere.
    private static func hover(_ p: CGPoint) {
        let e = NSEvent.mouseEvent(with: .mouseMoved, location: CGPoint(x: p.x, y: size.height - p.y), modifierFlags: [],
                                   timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                                   context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
        func walk(_ v: NSView) { v.subviews.forEach(walk); v.mouseMoved(with: e) }
        walk(window.contentView!)
    }

    private static func click(_ p: CGPoint, count: Int) async {
        for n in 1...count {
            mouse(.leftMouseDown, p, clicks: n)
            try? await Task.sleep(for: .milliseconds(30))
            mouse(.leftMouseUp, p, clicks: n)
            try? await Task.sleep(for: .milliseconds(60))
        }
    }

    /// Click at p, then time until the selection changes and until the next rendered frame after that.
    private static func latency(_ p: CGPoint, _ s: State) async {
        let before = s.selected.wrappedValue
        mouse(.leftMouseDown, p)
        try? await Task.sleep(for: .milliseconds(30))  // a tap needs a real press; timing starts at release
        let t0 = ContinuousClock.now
        mouse(.leftMouseUp, p)
        var tSel: ContinuousClock.Instant?
        while ContinuousClock.now - t0 < .seconds(1) {
            if tSel == nil, s.selected.wrappedValue != before { tSel = .now }
            if let tSel, FrameLog.lastFrame > tSel { break }
            try? await Task.sleep(for: .milliseconds(1))
        }
        func ms(_ d: Duration) -> Double { Double(d.components.attoseconds) / 1e15 + Double(d.components.seconds) * 1000 }
        print(String(format: "latency: click -> selection %.1f ms, click -> next frame after selection %.1f ms",
                     tSel.map { ms($0 - t0) } ?? -1, ms(FrameLog.lastFrame - t0)))
    }

    private static func drag(from p: CGPoint, by d: CGSize) async {
        mouse(.leftMouseDown, p)
        for i in 1...20 {
            try? await Task.sleep(for: .milliseconds(16))
            let t = CGFloat(i) / 20
            mouse(.leftMouseDragged, CGPoint(x: p.x + d.width * t, y: p.y + d.height * t))
        }
        mouse(.leftMouseUp, CGPoint(x: p.x + d.width, y: p.y + d.height))
    }

    private static func key(_ chars: String, command: Bool, code: UInt16 = 0) {
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            NSApp.postEvent(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: command ? .command : [],
                                             timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                                             context: nil, characters: chars, charactersIgnoringModifiers: chars,
                                             isARepeat: false, keyCode: code)!, atStart: false)
        }
    }

    private static func scroll(lines: Int32, times: Int, at p: CGPoint) async {
        for _ in 0..<times {
            let e = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: lines, wheel2: 0, wheel3: 0)!
            windowLocation(e, p)  // this private setter takes top-left points and flips them itself
            e.setIntegerValueField(CGEventField(rawValue: 51)!, value: Int64(window.windowNumber))  // the event's window
            NSApp.postEvent(NSEvent(cgEvent: e)!, atStart: false)
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Trackpad gesture events: CGEvent type 29 carries the HID type, value and phase in these fields.
    private static func trackpad(hidType: Int64, valueField: UInt32, value: Double, times: Int) async {
        for phase: Int64 in [1] + Array(repeating: 2, count: times) + [4] {
            let e = CGEvent(source: nil)!
            e.type = CGEventType(rawValue: 29)!
            e.setIntegerValueField(CGEventField(rawValue: 51)!, value: Int64(window.windowNumber))
            e.setIntegerValueField(CGEventField(rawValue: 110)!, value: hidType)
            e.setIntegerValueField(CGEventField(rawValue: 132)!, value: phase)
            e.setDoubleValueField(CGEventField(rawValue: valueField)!, value: phase == 2 ? value : 0)
            windowLocation(e, CGPoint(x: size.width / 2, y: size.height / 2))
            guard let ns = NSEvent(cgEvent: e) else { return print("no NSEvent for gesture") }
            NSApp.postEvent(ns, atStart: false)
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    /// Private setter, the only way to place a CGEvent-made event inside a window.
    private static func windowLocation(_ e: CGEvent, _ p: CGPoint) {
        typealias SetLocation = @convention(c) (CGEvent, CGPoint) -> Void
        unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGEventSetWindowLocation")!, to: SetLocation.self)(e, p)
    }

    /// Own-window capture needs no screen recording grant. The call is obsoleted in the SDK, hence dlsym.
    private static func shot(_ name: String) {
        typealias Capture = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return print("no capture symbol") }
        let capture = unsafeBitCast(sym, to: Capture.self)
        // .null rect, including-window list option, bounds-ignore-framing + best-resolution image options
        guard let img = capture(.null, 8, UInt32(window.windowNumber), 1 | 8)?.takeRetainedValue() else { return print("capture failed") }
        let url = FileManager.default.temporaryDirectory.appending(path: name + ".png")
        try? NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])?.write(to: url)
        print("shot \(url.path) \(img.width)x\(img.height)")
    }
}
#endif
