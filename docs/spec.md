# Life OS — Virtual City: Product Spec (repo copy)

Condensed from the product and technical specification v1.0 agreed in the planning chat on 2026-11-04. Long tables outside the Phase 1 scope are summarized.

## Vision

Life OS is a native Mac app that presents personal life management as an interactive isometric 3D city. Each district is a life dimension, each building is a functional module, and the city develops from the user's real activities.

Principles: life before gamification; one connected world; meaningful interactions (every building has a real function); progress without punishment; intelligent assistance; privacy by design (local-first).

## Visual design

- Orthographic isometric camera, about 30–35° angle. Stylized 3D, distinct readable silhouettes.
- Curved and grid-connected roads; trees, parks, water, plazas. Soft lighting and soft contact shadows. Matte surfaces, glass, concrete, greenery. Subtle ambient movement. Minimal floating macOS controls.
- District colors: Productivity blue, Finance emerald, Health coral, Spirituality violet, Personal warm orange, Learning indigo, Relationships rose, Recreation teal. Use for identification, signage and subtle details. Do not paint whole neighborhoods in saturated color.
- Camera: zoom, pan, controlled rotation, double-click a building to enter, click a district label to focus, return to full-city view, keyboard shortcuts. Presets: City View, District View, Building View, Interior View. Preserve last camera position between sessions.

## City map

Central Plaza (City Hall, Mayor's Office, Town Square, Progress Monument, City Map Board) surrounded by districts: Knowledge north; Spirituality north-west; Productivity north-east; Health south-west; Finance south-east; Personal south. All essential districts are available from the start. Progression unlocks cosmetics, never access to life features.

## Districts and buildings

- Productivity: Office Tower, Co-working Hub, Project Center, Planning Center, Innovation Lab.
- Finance: Central Bank, Investment Tower, Savings Building, Marketplace, Treasury.
- Health: Medical Center, Fitness Center, Nutrition Hub, Wellness Center, Sports Park.
- Spirituality: Sanctuary, Meditation Pavilion, Reflection Garden, Wisdom Hall, Peace Monument. Customizable to the user's beliefs or secular practice.
- Personal and Relationships: Personal Residence, Family House, Community Center, Recreation Center, Life Administration Office.
- Knowledge: Grand Library, University, Research Lab, Academy, Observatory.
- Recreation: Botanical Garden, Sports Stadium, Art Center, Lakeside Park, Cultural Center.

## Building interaction

States: locked cosmetic, available, active, developing, needs attention, completed. Essential features are never locked behind gameplay.

Hover shows name and brief status. Single click opens a contextual inspector on the right. Double click opens the full module. Right click opens a context menu. Five cosmetic building levels.

The inspector shows overview figures, quick actions and an AI insight. Figures in designs are illustrative.

## Progression (later phases)

City XP, district XP, building levels, milestones, city level, landmarks, decorations. Reward meaningful behaviors, not data entry. Prevent XP farming. No destruction for missed routines. Users can pause progression.

## AI Mayor (later phases)

Daily briefing, weekly life review, goal-to-action conversion, cross-district intelligence, city advisor. Permission levels: read, recommend, prepare, execute. Consequential operations need explicit confirmation. Users can inspect why a recommendation was made.

## Native Mac design

The city occupies most of the window with floating controls: left district navigator, center 3D city, right selected-building panel, top status, bottom "Ask the Mayor".

Components: CityViewport, DistrictNavigator, BuildingInspector, MayorPanel, CityStatus, ActivityTimeline, QuickCapture, CityMap.

Shortcuts: ⌘K command center, ⌘J AI Mayor, ⌘1 City view, ⌘2 Productivity, ⌘3 Finance, ⌘4 Health, ⌘5 Personal, ⌘N quick capture, ⌘, settings, Esc close overlay / deselect.

Later: menu bar companion, widgets, notifications. Required: accessibility, VoiceOver-compatible building navigation, resizable windows, full screen.

## Architecture

Swift, SwiftUI, RealityKit, SwiftData or SQLite, App Intents, AI through a secure backend, Blender-compatible USDZ assets. Modular, domain-driven. City simulation independent of life modules. Centralized activity event system. Local-first, offline core, optional sync. Data-driven city engine: `BuildingDefinition` references asset, district, feature, upgrade levels, actions.

Performance targets to validate by profiling: 60 FPS on supported hardware, initial city load under 3 s after caching, building interaction under 100 ms, reduced background animation when inactive, adaptive memory, core works offline. Techniques: LOD, instancing, texture atlases, asset caching, frustum culling, lazy loading.

## Development rules

No monolithic files. Reusable SwiftUI components and RealityKit entities. Testable domain logic. Realistic sample data only for development previews. Never fabricated data in real financial or health reports. Unit tests for progression and domain logic. Profile 3D performance on real Mac hardware. Prefer a polished working MVP over feature quantity.

## First deliverable (Phase 1)

A running native macOS app with an isometric 3D city, Central Plaza, five initial districts, distinct building models, smooth camera controls, clickable buildings and a basic building inspector. No AI Mayor or external integrations until the city foundation works. Must be visually polished, modular and ready for later work.
