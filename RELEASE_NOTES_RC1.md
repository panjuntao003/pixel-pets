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
- **Core Logic**: Validated via 128+ unit tests.
- **Resource Usage**: Optimized for background operation on macOS.

---
*Ready for production dogfooding and initial content rollout.*
