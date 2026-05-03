# Asset System Architecture Plan

Based on the v2 redesign plan, we need to introduce a structured asset system.

## 1. Asset Models

We will create structured models for assets to decouple definition from rendering.

*   `SceneAsset`: Defines id, name, logical size (360x140), safe area, default pet placement, and state-based variations.
*   `PetAsset`: Defines id, name, base size, anchors (headTop, back, etc.), and state-based variations.
*   `AccessoryAsset`: Defines id, category, mount point, layer (back/front/floating), and visual variations.

## 2. State & Render Layers

*   `VisualState`: A unified state derived from `PetState`, `SceneState`, and `AccessoryState`.
*   `HabitatRenderer`: A new top-level renderer that orchestrates:
    *   `SceneRenderer` (Background)
    *   `AccessoryRenderer` (Back layer)
    *   `PetRenderer` (The character)
    *   `AccessoryRenderer` (Front/Floating layers)
    *   `EffectRenderer` (Foreground FX)

## 3. Immediate Implementation Steps (Phase 1)

1.  **Define Core Protocols/Structs**: Create `SceneAsset`, `PetAsset`, and `AccessoryAnchor` definitions.
2.  **Refactor HabitatScene**: Transition from hardcoded drawing in `SciFiQuartersScene` to a more data-driven or structured approach using `SceneAsset`.
3.  **Establish Anchors in BitBotV2**: Modify `BitBotV2Renderer` to expose or utilize `PetAsset` anchors so accessories can be attached.
4.  **Create HabitatRenderer**: Build the composed view that layers these elements correctly.
