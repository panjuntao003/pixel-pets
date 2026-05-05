# Pixel Pets Release Candidate 1 (RC1)

Date: May 4, 2026
Version: 0.9.0-rc1

## Core Capabilities
- **Asset Manifest System**: Decoupled asset definitions from code via `manifest.json`. Supports layered scenes and multi-state pets.
- **ActivityCoordinator**: Intelligent event aggregator with priority management (`Error > Quota > Activity > Idle`) and debounce logic.
- **VisualStateReducer**: Deterministic mapping from system events to visual configurations (Pet/Scene/Accessory states + Intensity).
- **FXModules**: Generic, state-aware visual effects including `TypingSparks`, `AlertPulse`, and `EnergyFlow`.
- **Debug HUD**: Real-time visualization of current provider, events, visual state, and timeline. Supports diagnostics export.
- **Asset Gallery**: Developer-facing browser for live-previewing and validating all registered assets and anchors.
- **Manifest Validator**: Automated structural and resource integrity checks for asset packs.
- **Performance Guard**: Dynamic FPS scaling based on window visibility (ScenePhase) and activity level. Low Distraction and Reduce Motion support.

## Stability Status
- **Architecture**: Frozen.
- **Core Logic**: Validated via 164 unit tests (post-RC1.2 hotfix).
- **Resource Usage**: Optimized for background operation on macOS.

## Content Pack 01 (Initial Content Rollout)
- **New Production-Ready Scenes**: `Underwater Aquarium`, `Rooftop Server Garden`.
- **New Production-Ready Pets**: `Neural Jellyfish`, `OpenCode Terminal Bot`.
- **New Production-Ready Accessories**: `Halo`, `Code Cloud`, `Repair Patch`.
- **Debug-Only Assets**: `Repair Workshop` (Scene), `Quantum Cactus` (Pet), `Retro Antenna`, `Battery Backpack`, `Sidekick Drone`. These remain available in the Debug Asset Gallery but are filtered from production UI.

## Asset Pipeline & Governance
- **Production Readiness Filtering**: Implemented `productionReady` metadata in manifests. UI (Settings, Randomizer, Defaults) now strictly excludes non-production assets.
- **Accessory Compatibility**: Introduced `incompatiblePets` constraint. Assets like `Repair Patch` now dynamically detect and disable themselves on incompatible pets (e.g., `Neural Jellyfish`) to maintain visual integrity.

## RC1.2 Hotfix (May 5, 2026)
- **Fix IntSize Codable decode**: `IntSize` now correctly decodes JSON keys `width`/`height` (used by all manifests). Previously, manifests used `width`/`height` but Swift properties stored `w`/`h` with no CodingKeys override, causing every `logicalSize`/`baseSize` decode to silently fail.
- **Fix PetAsset anchors Codable decode**: `PetAsset.anchors` (`[AccessoryMountPoint: IntPoint]`) now decoded via `[String: IntPoint]` intermediate layer. Swift's JSONDecoder only treats `String`/`Int` keyed dictionaries as JSON objects; `String`-rawValue enum keys were decoded as arrays, causing all PetAsset decodes to fail.
- **Impact**: AssetRegistry now correctly loads all 16 manifest assets. Before this fix, the registry silently returned empty dictionaries, and HabitatRenderer fell back to legacy procedural drawing for everything.
- **Test count**: 128 → 164. 0 failures.
- **No asset manifest changes**, no `productionReady` changes, no architecture changes.
- `feature/pixel-pets-asset-library-import` remains unmerged and deferred.

## Known Issues
- **Hook System**: `AfterAgent` hook failure reported in some environments due to node-cli integration constraints. This is localized to the development toolchain and does not affect the production event loop or real-time event sensing via log parsers.
