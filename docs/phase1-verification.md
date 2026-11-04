# Phase 1 verification: accessibility and performance

Machine: Apple M4, 16 GB, macOS 27.2 (system appearance: Dark), built-in display (60 Hz). Branch `feature/phase1-city`.
No system setting was changed. All input was injected inside the app by the DEBUG driver (`LifeOS/DebugDriver.swift`), not hardware.

## Performance

Method: `LifeOS` built in **Release with the DEBUG flag** (`xcodebuild -configuration Release SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG`). The override reaches the package target too (frames are counted from `CityViewport`'s probe), so the code is optimized and the numbers are Release-based. The probe (`CityViewport.frameProbe`, `FrameLog`, driver) is `#if DEBUG` only: a plain Release build contains none of it (no `frameProbe`, `onFrame` or `LIFEOS_DRIVE` strings in the binary). Window 1280x800. Frame cadence is RealityKit's `SceneEvents.Update`, one per rendered frame. Presented-frame fps is therefore inferred from the scene-update cadence; it was not measured from displayed surfaces. The recorded Metal System Trace was not analyzed (its display tables are system-wide). Driver input is posted NSEvents: pan is 3 drags of about 20 steps at 16 ms; zoom is 120 scroll-wheel events.

| Run | Idle (1 s) frames / fps / >20 ms | Pan frames / fps / >20 ms / max ms | Zoom frames / fps / >20 ms / max ms | Launch to first update |
|---|---|---|---|---|
| 1 | 63 / 60.0 / 0 | 192 / 59.6 / 2 / 36.2 | 213 / 60.0 / 0 / 17.7 | 0.43 s |
| 2 | 63 / 60.0 / 0 | 190 / 59.7 / 3 / 35.1 | 213 / 60.0 / 0 / 18.1 | 0.36 s |
| 3 | 63 / 60.0 / 0 | 190 / 60.0 / 1 / 23.0 | 213 / 60.0 / 1 / 20.1 | 0.36 s |

| Metric | Target | Measured | Result |
|---|---|---|---|
| FPS while panning | 60 | 59.6-60.0 fps; p95 frame 17.9-18.0 ms, 1-3 frames over 20 ms per run | Met, with occasional hitches up to 36 ms |
| FPS while zooming | 60 | 60.0 fps; p95 17.5-17.6 ms | Met |
| Launch to first frame | under 3 s | 0.36-0.43 s warm. Earlier build, first launch after a fresh build: 1.67 s | Met |
| Click to inspector | under 100 ms | click release to selection change 14.2-23.9 ms (12 clicks); to the next rendered frame 14.7-24.2 ms | Met (see caveats) |

Pan hitches were slightly worse after the panel backing change (before it: 0-1 frames over 20 ms, one 41.9 ms outlier in a cold run). Whether the extra backing layer costs frame time was not isolated; 3 runs is too few to say.

Caveats:
- Launch time is process start (kernel start time) to the first `SceneEvents.Update`. It is not the first presented frame, and the warm figures are not a cold-boot number.
- Click latency is from the posted mouse-up to the store's `selectedBuildingID` changing, then to the next RealityKit frame. SwiftUI draws the inspector in the same main-thread update; its draw time is not separately timed. Roughly one frame (about 14-17 ms, an estimate, not measured separately) of the figure is probably tap recognition.
- Without a prior hover step, several early driver clicks did not register (the driver has no real cursor). Those runs are excluded; the table uses clicks preceded by a hover. A click with no selection change prints "no selection change" and is not counted.
- Nothing measured on a physical mouse or trackpad.
- Idle energy was not measured. The scene renders at 60 fps while idle (63 frames in 1.05 s in every run above).

Raw logs: `.superpowers/sdd/2026-11-04-life-os-phase1-city-foundation/evidence/task7-r2-perf-*.txt` (gitignored).

## Accessibility

Implemented:
- Selected navigator row carries the `isSelected` trait. District rows only have an accessibility value "expanded" (their buildings are listed) or "collapsed".
- The focusable main container is an accessibility container labelled "Life OS", so VoiceOver does not announce an unlabeled group.
- `CityViewport` has the label "Isometric city map" and the hint "The city is also navigable through the district list."
- Every building is reachable through navigator rows (City Hall fixed row; others under their district), each labelled "<name>, <district>" (covered by `everyBuildingIsReachableFromNavigatorRows`).

Reduce Motion: no camera move animates (camera changes are set directly), and the scene has no ambient animation. The one animation is the 0.2 s inspector appearance in `MainView`, disabled when Reduce Motion is on (`@Environment(\.accessibilityReduceMotion)`). Not exercised with the setting on.

Contrast. Fix: panels now have a `windowBackgroundColor` backing at 0.8 opacity behind the glass, and secondary text is primary color at 0.85 opacity. Method: the DEBUG driver sets `NSApp.appearance` (`appearance light|dark`; app only, no system setting), captures the window, and the ratio is WCAG contrast between the brightest/darkest text pixel and the median background pixel of the text region (a pixel estimate). Two camera positions: panels over the city, and panels over the pale sky (city moved off screen, the worst case for light text).

| Text | Dark, over city | Dark, over sky | Light, over city | Light, over sky |
|---|---|---|---|---|
| Navigator rows | 7.65 | 7.40 | 20.1 | 20.4 |
| Inspector body | 8.01 | 7.61 | 20.0 | 20.4 |
| "Sample data" caption | 6.31 | 6.07 | 15.7 | 15.6 |
| Top bar | 5.16 | 5.15 | 19.1 | 19.0 |
| "Ask the Mayor" (disabled, exempt) | 1.93 | 2.08 | 2.29 | 2.51 |

All enabled text is at or above 4.5:1 in both appearances. The disabled button is faint but readable; it is exempt. Before the fix (dark only): body 4.4, secondary 2.2-2.5. The district color dots are decoration; the text row carries the name. Ratios are estimates from one render per case; the live glass varies with what is behind it. Evidence: `c-*.png` in the app container tmp (`~/Library/Containers/com.jaysonreales.lifeos/Data/tmp`), `task7-r2-contrast.txt`.

## Remaining for a human

- Physical mouse and trackpad: click, drag pan, scroll, pinch, rotate, hover.
- Physical keyboard Esc after clicking the city, and after Tab-focusing a navigator row.
- Full screen (and live window resize).
- Dark mode and light mode look on the real system setting (appearance was only forced inside the app).
- VoiceOver: row announcements ("selected", "expanded"/"collapsed"), the city map label and hint, no unlabeled group.
- Reduce Motion on: inspector appears without animation.
- Cmd+, Settings window.
