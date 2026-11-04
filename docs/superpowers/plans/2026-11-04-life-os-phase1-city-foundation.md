# Life OS — Phase 1: City Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A running native macOS app that shows an interactive isometric 3D city (Central Plaza, five districts, 21 distinct clickable buildings) with smooth camera control and a building inspector.

**Architecture:** A local Swift package `LifeKit` holds two targets: `LifeCore` (pure-Swift city catalog: districts, buildings, tile geometry; no UI, no RealityKit) and `CityEngine` (camera math, procedural scene building, RealityKit viewport). A thin Xcode app target (`LifeOS`) owns the SwiftUI chrome and an `@Observable` `CityStore`. The city never imports life-management code; later modules talk to it only through activity events (Phase 4).

**Tech Stack:** Swift 6.4, SwiftUI, RealityKit (`RealityView`, `OrthographicCameraComponent`), Swift Testing, XcodeGen, GitHub Actions (macOS runner).

**Spec:** the "Life OS — Virtual City" product spec in the originating chat (sections 2, 3, 4, 5, 8, 9.4, 9.5, 15). Save a copy to `docs/spec.md` in Task 1 so it travels with the repo.

## Global Constraints

- Platform: macOS, deployment target 26.0 (toolchain on this Mac: Xcode 27.2, Swift 6.4.2, macOS 27.2). RealityKit orthographic camera needs macOS 15+.
- Camera: orthographic isometric; pitch 35°, base yaw 45°, yaw adjustable only within ±20° of base.
- Five Phase 1 districts: Productivity (blue), Finance (emerald), Health (coral), Spirituality (violet), Personal (warm orange). Other districts are added later as data only.
- Buildings come from data (`BuildingDefinition`); no per-building view code.
- Essential features are never locked: all five districts and all buildings are available in Phase 1.
- Each building has `maxLevel = 5` cosmetic levels; Phase 1 renders level 1 only.
- Placeholder numbers appear only in the inspector and are labelled "Sample data".
- No AI Mayor, no persistence of life data, no network in Phase 1.
- Targets (validate by profiling on real hardware, not assumed): 60 FPS, selection response < 100 ms, cached load < 3 s.
- Repo flow: `feature/*` → `staging` → `main`. No Vercel (native app); CI is `xcodebuild test` on GitHub Actions.

## Review Focus

- Mouse wheel / trackpad scroll with huge deltas must clamp zoom, never flip or vanish the city.
- Camera state loaded from disk that is corrupt, NaN, or out of range falls back to the City View preset.
- Click on empty ground, road, or plaza deselects without crashing; overlapping hit shapes select the nearest building.
- Resizing the window to a tiny size or entering full screen keeps the focus point and apparent scale stable.
- Every building is reachable and selectable without a mouse (VoiceOver and keyboard via the district navigator).

---

## File Structure

```
life/
├── project.yml                         XcodeGen spec (app target + local package)
├── .github/workflows/ci.yml            xcodebuild test
├── docs/spec.md, docs/superpowers/plans/…
├── Packages/LifeKit/
│   ├── Package.swift
│   ├── Sources/LifeCore/
│   │   ├── TileRect.swift              integer tile rectangle math
│   │   ├── DistrictType.swift          enum + display name
│   │   ├── BuildingDefinition.swift    data model + BuildingStyle
│   │   └── CityCatalog.swift           the five districts, plaza, 21 buildings
│   ├── Sources/CityEngine/
│   │   ├── CameraState.swift           pure camera math + presets + Codable
│   │   ├── CameraStore.swift           UserDefaults persistence with fallback
│   │   ├── BuildingFactory.swift       BuildingDefinition -> Entity (procedural)
│   │   ├── CitySceneBuilder.swift      ground, roads, plaza, trees, lights
│   │   ├── CityViewport.swift          SwiftUI RealityView + gestures
│   │   └── Picking.swift               entity name <-> building id
│   └── Tests/{LifeCoreTests,CityEngineTests}/
└── LifeOS/
    ├── LifeOSApp.swift                 window, commands (menu shortcuts)
    ├── CityStore.swift                 selection / hover / focus / camera
    ├── MainView.swift                  viewport + floating chrome
    ├── DistrictNavigator.swift         left list, keyboard + VoiceOver
    ├── BuildingInspector.swift         right panel
    └── Palette.swift                   district accent colors
```

---

### Task 1: Scaffold repo, package, app shell, CI

**Files:**
- Create: `project.yml`, `Packages/LifeKit/Package.swift`, `LifeOS/LifeOSApp.swift`, `.github/workflows/ci.yml`, `.gitignore`, `docs/spec.md`
- Create: one empty `Placeholder.swift` per package target (so it compiles); removed in Tasks 2 and 3.

**Interfaces:**
- Produces: scheme `LifeOS` (app) and package test targets `LifeCoreTests`, `CityEngineTests`; branches `main`, `staging`, `feature/phase1-city`.

- [ ] **Step 1:** `git init -b main`; add `.gitignore` (Xcode, `.build`, `*.xcodeproj`, `.DS_Store`); commit; `git branch staging`; `git switch -c feature/phase1-city`.
- [ ] **Step 2:** Create `Package.swift`: tools 6.0, platforms `.macOS(.v26)`, library targets `LifeCore` and `CityEngine` (depends on `LifeCore`), a Swift Testing test target for each.
- [ ] **Step 3:** Install and use XcodeGen (`brew install xcodegen` if absent). `project.yml`: app target `LifeOS`, bundle id `com.jaysonreales.lifeos`, macOS 26.0, local package dependency on both libraries, App Sandbox on, hardened runtime on.
- [ ] **Step 4:** `LifeOSApp.swift`: `@main struct LifeOSApp: App` with `WindowGroup { Text("Life OS") }`, `.defaultSize(width: 1280, height: 800)`.
- [ ] **Step 5:** `ci.yml`: on push/PR to `staging` and `main`, `macos-latest`: run `swift test --package-path Packages/LifeKit`, then `xcodegen && xcodebuild -scheme LifeOS -destination 'platform=macOS' build`.
- [ ] **Step 6: Verify.** `xcodegen && xcodebuild -scheme LifeOS -destination 'platform=macOS' build` → `BUILD SUCCEEDED`. `swift test --package-path Packages/LifeKit` → exits 0.
- [ ] **Step 7:** Commit `chore: scaffold LifeOS app and LifeKit package`. Creating the GitHub remote and pushing is outward-facing: stop and ask the user first.

### Task 2: LifeCore — tile math and city catalog

**Files:**
- Create: `Sources/LifeCore/{TileRect,DistrictType,BuildingDefinition,CityCatalog}.swift`
- Test: `Tests/LifeCoreTests/CatalogTests.swift`

**Interfaces:**
- Produces:
  - `public struct TileRect: Equatable, Hashable, Sendable { public var x, z, width, depth: Int; public func intersects(_ o: TileRect) -> Bool; public func contains(_ o: TileRect) -> Bool; public var center: (x: Float, z: Float) { get } }`
  - `public enum DistrictType: String, CaseIterable, Codable, Sendable { case productivity, finance, health, spirituality, personal; public var displayName: String { get } }`
  - `public enum BuildingStyle: String, Sendable { case tower, slab, steppedTower, dome, pavilion, pagoda, gabled, campus, hall, garden }`
  - `public struct BuildingDefinition: Identifiable, Equatable, Sendable { public let id: String; public let district: DistrictType?; public let name: String; public let featureID: String; public let footprint: TileRect; public let heightUnits: Float; public let style: BuildingStyle; public let maxLevel: Int }` (`district == nil` only for City Hall)
  - `public struct DistrictDefinition: Identifiable, Sendable { public let id: DistrictType; public let bounds: TileRect }`
  - `public enum CityCatalog { public static let plazaBounds: TileRect; public static let cityHall: BuildingDefinition; public static let districts: [DistrictDefinition]; public static let buildings: [BuildingDefinition]; public static func building(id: String) -> BuildingDefinition?; public static func buildings(in: DistrictType) -> [BuildingDefinition] }`

Layout (tile units, plaza centered at origin, 6-tile roads between blocks, each district bounds 14×14): Spirituality NW, Productivity NE, Health SW, Finance SE, Personal south-center. Four buildings each, with ids like `productivity.office-tower`:
- Productivity — Office Tower (tower), Co-working Hub (campus), Planning Center (slab), Innovation Lab (dome)
- Finance — Central Bank (hall), Investment Tower (steppedTower), Savings Building (slab), Marketplace (pavilion)
- Health — Medical Center (campus), Fitness Center (hall), Nutrition Hub (gabled), Wellness Center (garden)
- Spirituality — Sanctuary (pagoda), Meditation Pavilion (pavilion), Reflection Garden (garden), Wisdom Hall (hall)
- Personal — Personal Residence and Family House (gabled), Community Center (campus), Life Administration Office (slab)
- City Hall (hall, tallest, in the plaza)

- [ ] **Step 1: Write failing tests** in `CatalogTests.swift`: `buildingIDsAreUnique`; `everyBuildingFootprintLiesInsideItsDistrictBounds`; `noTwoFootprintsOverlap` (includes City Hall vs plaza); `districtBoundsDoNotOverlapEachOther`; `eachDistrictHasFourBuildingsAndTotalIs21`; `noTwoBuildingsInOneDistrictShareStyleAndHeight`; `tileRectIntersectsIsFalseForTouchingEdges`; `lookupByIDReturnsNilForUnknown`.
- [ ] **Step 2:** `swift test --package-path Packages/LifeKit --filter CatalogTests` → FAIL (types not defined).
- [ ] **Step 3:** Implement the types above exactly; catalog data as literals. Delete the LifeCore placeholder.
- [ ] **Step 4:** Rerun → all PASS.
- [ ] **Step 5:** Commit `feat(core): city catalog with five districts and 21 buildings`.

### Task 3: CityEngine — camera math and persistence

**Files:**
- Create: `Sources/CityEngine/{CameraState,CameraStore}.swift`
- Test: `Tests/CityEngineTests/CameraTests.swift`

**Interfaces:**
- Consumes: `TileRect`, `BuildingDefinition`.
- Produces:
  - `public struct CameraState: Codable, Equatable, Sendable { public var focusX: Float; public var focusZ: Float; public var zoom: Float; public var yawOffset: Float }` — `zoom` is the orthographic half-height in world units, range `6...60`; `yawOffset` in radians, range ±20°; focus clamped to ±40.
  - `public static let cityView: CameraState`
  - `public static func districtView(_ b: TileRect) -> CameraState`; `public static func buildingView(_ b: BuildingDefinition) -> CameraState`
  - `public func panned(screenDelta: SIMD2<Float>, viewHeightPoints: Float) -> CameraState` — the world follows the cursor (drag right moves the world right), accounting for yaw.
  - `public func zoomed(byFactor: Float) -> CameraState`; `public func rotated(byRadians: Float) -> CameraState`
  - `public func clamped() -> CameraState` — any non-finite field becomes the `cityView` value.
  - `public struct CameraStore { public init(defaults: UserDefaults, key: String = "lifeos.camera"); public func load() -> CameraState; public func save(_ s: CameraState) }`
- [ ] **Step 1: Write failing tests:** `zoomClampsAtBothEnds` (factors 1e6 and 1e-6); `panRightMovesWorldRightAtZeroYaw`; `panAccountsForYaw`; `rotateClampsToTwentyDegrees`; `nonFiniteStateFallsBackToCityView` (NaN, ±inf); `focusClampsToBounds`; `districtViewCentersOnDistrict`; `storeRoundTrips`; `storeFallsBackOnCorruptData` (garbage bytes under the key); `storeFallsBackOnOutOfRangeValues`.
- [ ] **Step 2:** `swift test --package-path Packages/LifeKit --filter CameraTests` → FAIL.
- [ ] **Step 3:** Implement. `CameraStore.load` decodes JSON then `.clamped()`; any decode failure returns `.cityView`. Delete the CityEngine placeholder.
- [ ] **Step 4:** Run → PASS. **Step 5:** Commit `feat(engine): camera state, presets, persistence`.

### Task 4: CityEngine — procedural city scene

**Files:**
- Create: `Sources/CityEngine/{BuildingFactory,CitySceneBuilder,Picking}.swift`
- Test: `Tests/CityEngineTests/SceneTests.swift`

**Interfaces:**
- Consumes: `CityCatalog`, `BuildingDefinition`, `BuildingStyle`.
- Produces:
  - `public enum Picking { public static func entityName(for buildingID: String) -> String; public static func buildingID(fromEntityName: String) -> String? }` (prefix `building:`)
  - `@MainActor public enum BuildingFactory { public static func makeEntity(for: BuildingDefinition, accent: SIMD3<Float>?) -> Entity }` — primitive meshes chosen by `style` (stacked boxes with setbacks, dome, gabled roof, pagoda tiers, garden = low walls + trees). Root entity is named via `Picking` and carries a `CollisionComponent` (box over the whole building) and an `InputTargetComponent`. Accent colors sign and trim only, never the whole building.
  - `@MainActor public enum CitySceneBuilder { public static func makeScene() -> Entity }` — ground, roads between district blocks, plaza with City Hall and a monument, at least 40 trees/park props, per-district ground tint, one shadow-casting `DirectionalLight`, soft ambient fill; children named `ground`, `roads`, `plaza`.
- [ ] **Step 1: Write failing tests:** `sceneContainsOneEntityPerCatalogBuilding`; `everyBuildingEntityHasCollisionAndInputTarget`; `pickingNameRoundTrips`; `pickingRejectsForeignNames`; `buildingEntityBoundsAreInsideCityBounds`.
- [ ] **Step 2:** Run `--filter SceneTests` → FAIL.
- [ ] **Step 3:** Implement. Procedural geometry is a deliberate Phase 1 choice (no 3D assets exist yet). Keep each style in its own small private function so a USDZ loader can replace it per building in Phase 2.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5 (visual):** Once Task 5 exists, review the render against the art direction (matte materials, soft shadows, readable silhouettes) and tune proportions and colors. Use `ui-ux-pro-max`, `frontend-design` and `ecc:liquid-glass-design` for palette and chrome.
- [ ] **Step 6:** Commit `feat(engine): procedural isometric city scene`.

### Task 5: CityViewport — camera, gestures, hover and tap picking

**Files:**
- Create: `Sources/CityEngine/CityViewport.swift`

**Interfaces:**
- Consumes: `CameraState`, `CameraStore`, `CitySceneBuilder`, `Picking`.
- Produces: `public struct CityViewport: View { public init(camera: Binding<CameraState>, hoveredBuildingID: Binding<String?>, selectedBuildingID: Binding<String?>, onOpenBuilding: @escaping (String) -> Void) }`.

Behavior: a `RealityView` with a camera entity carrying `OrthographicCameraComponent`, positioned by `look(at:from:)` from `CameraState` (pitch 35°, yaw 45° + offset), scale from `zoom`, updated in the `update:` closure. Gestures: drag = pan; scroll wheel and pinch = zoom (via `CameraState.zoomed`); two-finger rotate = yaw (clamped); `SpatialTapGesture().targetedToAnyEntity()` = select (empty ground → `nil`); double-tap = `onOpenBuilding`; `onContinuousHover` = hover. Save through `CameraStore` when a gesture ends, not per frame. Pause ambient animation when the window is inactive.

- [ ] **Step 1:** Implement per the behavior above. Check current Apple docs first for the `OrthographicCameraComponent` zoom property and near/far planes. Taps already need `CollisionComponent` + `InputTargetComponent` from Task 4.
- [ ] **Step 2: Verify** by running the app (`/run`): isometric city renders; drag pans; scroll zooms and stops at both limits; rotate stops at ±20°; click selects; empty-ground click deselects. Save a screenshot as evidence.
- [ ] **Step 3:** Commit `feat(engine): interactive city viewport`.

### Task 6: App shell — store, navigator, inspector, shortcuts

**Files:**
- Create: `LifeOS/{CityStore,Palette,MainView,DistrictNavigator,BuildingInspector}.swift`; Modify: `LifeOS/LifeOSApp.swift`
- Test: `LifeOSTests/CityStoreTests.swift` (add a test target to `project.yml`)

**Interfaces:**
- Consumes: `CityViewport`, `CameraState`, `CityCatalog`.
- Produces: `@MainActor @Observable final class CityStore { var camera: CameraState; var selectedBuildingID: String?; var hoveredBuildingID: String?; var focusedDistrict: DistrictType?; func select(_ id: String?); func focus(_ d: DistrictType); func showCity(); func escape() }`
  - `escape()` clears selection first; with nothing selected it returns to City View.
  - `focus(d)` sets `camera = .districtView(bounds)`; `select(id)` also sets `focusedDistrict` to the building's district and ignores unknown ids.

UI: viewport fills the window with floating elements (Liquid Glass or `.regularMaterial`): top bar (title, static "City Level 1", date); left `DistrictNavigator` (district list; expanding a district lists its buildings; rows are `Button`s with `.accessibilityLabel("<name>, <district>")`); right `BuildingInspector` (name, district accent chip, feature, "Level 1 of 5", placeholder stats labelled "Sample data", disabled "Open" button with help "Coming in a later phase"); bottom "Ask the Mayor" button, disabled. Commands: ⌘1 City View, ⌘2 Productivity, ⌘3 Finance, ⌘4 Health, ⌘5 Personal, ⌘6 Spirituality (spec lists ⌘2–⌘5 only; ⌘6 is added here), Esc → `escape()`, ⌘, opens a stub Settings scene.

- [ ] **Step 1: Write failing tests** in `CityStoreTests`: `escapeClearsSelectionThenReturnsToCityView`; `selectingBuildingFocusesItsDistrict`; `focusDistrictSetsDistrictViewCamera`; `selectUnknownIDIsIgnored`; `showCityResetsCameraAndFocus`.
- [ ] **Step 2:** `xcodegen && xcodebuild test -scheme LifeOS -destination 'platform=macOS'` → FAIL.
- [ ] **Step 3:** Implement the store, then the views. Keep views thin; logic lives in the store.
- [ ] **Step 4:** Tests PASS. Run the app: navigator row selects a building and moves the camera; inspector updates; shortcuts work; window resize and full screen keep scale and focus.
- [ ] **Step 5:** Commit `feat(app): district navigator, building inspector, shortcuts`.

### Task 7: Accessibility, performance, review, ship

**Files:** modify as findings require; create `docs/phase1-verification.md`.

- [ ] **Step 1: Accessibility.** VoiceOver reaches every building through the navigator; Reduce Motion disables ambient animation; text contrast on glass checked in light and dark. Run `design:accessibility-review`.
- [ ] **Step 2: Performance.** Profile with Instruments (Time Profiler, Metal System Trace) on this Mac. Record fps while panning/zooming, launch-to-first-frame, and click-to-inspector latency in `docs/phase1-verification.md`. Record measured numbers only. Fix only measured problems (shadow cost, entity count, material reuse).
- [ ] **Step 3: Review.** Run `/review`, then `ecc:swift-reviewer`; use `ecc:swift-build-resolver` if the build breaks. Fix findings.
- [ ] **Step 4: QA.** Run the app and exercise every Review Focus line by hand. Take screenshots of City View, District View and a selected building (light and dark).
- [ ] **Step 5: Ship.** `/ship` targeting `staging` (needs the GitHub remote from Task 1); CI green before merge. Merge `staging` → `main` only on the user's explicit OK.

---

## Self-Review

- Phase 1 deliverable coverage: isometric ortho camera (T3, T5); plaza, five districts, distinct buildings (T2, T4); smooth camera (T3, T5); clickable (T4, T5); inspector (T6); persistent camera (T3, T5); shortcuts and navigation (T6); accessibility and profiling (T7).
- Deferred to Phase 2+: day/night, rendered upgrade levels 2–5, menu bar companion, command palette (⌘K), remaining districts.
- Names match across tasks (`CameraState`, `Picking`, `CityCatalog`, `CityStore`).

## Roadmap (separate plans, written when Phase 1 ships)

| Phase | Scope | Skills to use |
|---|---|---|
| 2 | USDZ asset pipeline, five building levels, hover/context menu, day/night, remaining districts, fly-to animation | `ecc:swiftui-patterns`, `design:design-critique` |
| 3 | SwiftData persistence; tasks/goals/habits/journal/expense/workout modules; building interiors as native views | `ecc:swift-actor-persistence`, `superpowers:test-driven-development` |
| 4 | `ActivityEvent` bus, XP / district XP / levels, anti-farming rules, pause mode, unit-tested progression | `ecc:tdd-workflow` |
| 5 | AI Mayor via secure backend, permission levels (read/recommend/prepare/execute), inspectable context | `ecc:security-review`, `cso` |
| 6 | App Intents for the Siri actions; Siri AI behavior is beta-dependent | `ecc:foundation-models-on-device`, Apple docs via Context7 |
| 7 | Perf/accessibility hardening, menu bar companion, command palette | `ecc:performance-optimizer`, `/canary` equivalent |
