# Phase 1 verification: accessibility and performance

Machine: Apple M4, 16 GB, macOS 27.2 (system appearance: Dark), built-in display (60 Hz). Branch `feature/phase1-city`.
No system setting was changed. All input was injected inside the app by the DEBUG driver (`LifeOS/DebugDriver.swift`), not hardware.

## Performance

Method: `LifeOS` built in **Release with the DEBUG flag** (`xcodebuild -configuration Release SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG`), so the code is optimized but the driver and frame probe are present. Window 1280x800. Frame cadence is RealityKit's `SceneEvents.Update` (one per rendered frame) captured through the DEBUG-only `onFrame` hook on `CityViewport`. This measures scene update cadence, not the display's presented frames. Driver input is posted NSEvents: pan is 3 drags of about 20 steps at 16 ms; zoom is 120 scroll-wheel events.

| Metric | Target | Measured | Result |
|---|---|---|---|
| FPS while panning (3 runs) | 60 | 59.7, 60.0, 60.0 fps; p95 frame 17.2-17.4 ms | Met |
| FPS while zooming (3 runs) | 60 | 60.0, 60.0, 60.0 fps; p95 frame 17.2-17.3 ms | Met |
| Launch to first frame | under 3 s | 1.67 s (first launch after a fresh build), 0.39 s and 0.39 s (next two) | Met |
| Click to inspector | under 100 ms | click release to selection change 13.8-21.2 ms (11 clicks over 3 runs); to the next rendered frame 14.2-21.6 ms | Met (see caveat) |

Worst single frames: 41.9 ms once, during pan in the first (cold) run; 17.6-22.6 ms otherwise. One to two frames over 20 ms occurred per 1 s idle window. No problem measured, so no performance fix was made.

Caveats:
- Launch time is process start (kernel start time) to the first `SceneEvents.Update`. It is not the first presented frame, and is not a cold-boot or first-ever-launch number.
- Click latency is from the posted mouse-up to the store's `selectedBuildingID` changing, then to the next RealityKit frame. SwiftUI draws the inspector in the same main-thread update; its draw time is not separately timed. About 14-17 ms of the figure is one frame of tap recognition.
- Without a prior hover step, Several early driver clicks did not register (the driver has no real cursor). Those runs are excluded; the table uses clicks preceded by a hover. One later click also failed after a lost hover.
- `xctrace` works here: a Time Profiler recording of the Release app and a Metal System Trace of the Debug app were recorded. Neither was analyzed, and no numbers above come from them. Metal System Trace's display tables are system-wide, so the in-app probe was used instead.
- Nothing measured on a physical mouse or trackpad.

Raw logs: `.superpowers/sdd/2026-11-04-life-os-phase1-city-foundation/evidence/task7-perf-*.txt`, `task7-lat-*.txt` (gitignored).

## Accessibility

Implemented:
- Selected navigator row carries the `isSelected` trait. District rows have an accessibility value "expanded" (their buildings are listed) or "collapsed".
- The focusable main container is an accessibility container labelled "Life OS", so VoiceOver does not announce an unlabeled group.
- `CityViewport` has the label "Isometric city map" and the hint "The city is also navigable through the district list."
- Every building is reachable through navigator rows (City Hall fixed row; others under their district), each labelled "<name>, <district>" (covered by `everyBuildingIsReachableFromNavigatorRows`).

Reduce Motion: no camera move animates (camera changes are set directly), and the scene has no ambient animation. The one animation is the 0.2 s inspector appearance in `MainView`, now disabled when Reduce Motion is on (`@Environment(\.accessibilityReduceMotion)`). Not exercised with the setting on.

Contrast (read from renders, not a formal audit):
- Light mode could not be rendered. This Mac is in Dark, and launching with `-AppleInterfaceStyle Light` still rendered dark. Light mode is unverified.
- Dark render, sampled in `evidence/7-Dark.png`: primary text is white; against the glass behind it, 4.4:1 in the navigator and inspector, just under the 4.5:1 guideline for body text. Secondary text ("Sample data", "City Level 1", date) measured about 2.2-2.5:1, which fails 4.5:1. The top bar sits over the pale plaza at some camera positions, which is the worst case. These are sampled pixel estimates; glass contrast changes with what is behind it. Not fixed here; a darker glass tint or fully opaque secondary text color for the panels is the likely fix and is a design call.
- District color dots are decoration; the text row carries the name.

## Remaining for a human

- Physical mouse and trackpad: click, drag pan, scroll, pinch, rotate, hover.
- Physical keyboard Esc after clicking the city, and after Tab-focusing a navigator row.
- Full screen (and live window resize).
- Dark mode and light mode look, including light-mode panel contrast.
- VoiceOver: row announcements ("selected", "expanded"/"collapsed"), the city map label and hint, no unlabeled group.
- Reduce Motion on: inspector appears without animation.
- Cmd+, Settings window.
