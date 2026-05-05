# RC1.2 Hotfix Report
**Branch:** hotfix/rc1.2-intsize-decode  
**Base:** main @ d375a5f (Content Pack 01)  
**Date:** 2026-05-05  

---

## Executive Summary

Two silent manifest decode failures blocked all asset loading since the AssetRegistry was first introduced. Neither bug produced a visible error — they silently returned empty dictionaries, causing `HabitatRenderer` to fall back entirely to legacy procedural drawing. Both are fixed in this hotfix.

---

## Bugs Fixed

### Bug 1 — `IntSize`: JSON keys `"width"`/`"height"` never decoded

**Severity:** RC1 Blocker  
**Root cause:** `IntSize` stored data as `w`/`h` Swift properties with no `CodingKeys` override. All manifests use `"width"`/`"height"` JSON keys. The synthesized `Codable` expected `"w"`/`"h"` → every manifest decode silently returned `nil` at the `logicalSize` / `baseSize` field → the entire asset struct failed to decode.  
**Fix:** Custom `init(from:)` / `encode(to:)` on `IntSize`:
- Decodes `"width"`/`"height"` (primary — all current manifests)
- Falls back to `"w"`/`"h"` (legacy compatibility)
- Always encodes as `"width"`/`"height"` (canonical output)

### Bug 2 — `PetAsset.anchors`: `[AccessoryMountPoint: IntPoint]` decoded as array, not object

**Severity:** RC1 Blocker  
**Root cause:** Swift's `JSONDecoder` only treats `Dictionary<String, _>` and `Dictionary<Int, _>` as JSON objects. All other key types — including `String`-rawValue enums — are decoded as `[key, value]` arrays. `AccessoryMountPoint` is a `String` enum, but does not satisfy the `String`/`Int` constraint. Every `PetAsset` decode threw `typeMismatch: Expected Array but found dictionary`, silently caught by `try?` → `pets` was always empty.  
**Fix:** Custom `init(from:)` / `encode(to:)` on `PetAsset`:
- Decodes `anchors` as `[String: IntPoint]`, then maps string keys to `AccessoryMountPoint` enum values
- Unknown anchor keys are silently dropped (forward compatibility)
- Encodes back to `[String: IntPoint]` using rawValue keys

---

## Asset Registry — Actual Load Counts (post-fix)

| Category | Total | productionReady:true | productionReady:nil (pass-through) | productionReady:false |
|---|--:|--:|--:|--:|
| Scenes | 5 | 2 | 2 | 1 |
| Pets | 4 | 2 | 1 | 1 |
| Accessories | 7 | 3 | 1 | 3 |
| **Production pool** | **~12** | **7** | **4** | **–** |

Production filter: `productionReady != false`. Assets with `nil` pass through (not explicitly disabled).

---

## Production Pool (productionReady != false)

| Asset | Type | productionReady | Notes |
|---|---|---|---|
| `rooftop_server_garden` | Scene | true | Full state coverage |
| `underwater_aquarium` | Scene | true | Full state coverage |
| `galaxy_observatory` | Scene | nil | Full state coverage. Candidate for `true` after QA. |
| `cyber_bamboo` | Scene | nil | normal-only. Falls back for dim/alert. Candidate for explicit `false`. |
| `neural_jellyfish` | Pet | true | All 4 states, 3 anchors |
| `opencode_terminal_bot` | Pet | true | All 4 states, 5 anchors |
| `nebula_bot` | Pet | nil | All 4 standard states. See note on damaged.png below. |
| `halo` | Accessory | true | All 2 states, no incompatibilities |
| `code_cloud` | Accessory | true | All 2 states, no incompatibilities |
| `repair_patch` | Accessory | true | Incompatible with neural_jellyfish |
| `bubble_helmet` | Accessory | nil | Compatible with 3/4 pets |

---

## Assets Excluded from Production (productionReady:false)

| Asset | Type | Reason |
|---|---|---|
| `repair_workshop` | Scene | Explicitly false |
| `cactus_sprite` | Pet | Explicitly false |
| `battery_backpack` | Accessory | Explicitly false |
| `retro_antenna` | Accessory | Explicitly false |
| `sidekick_drone` | Accessory | Explicitly false |

---

## On `galaxy_observatory` and `nebula_bot` (productionReady: nil)

The user asked not to change these without justification. Here is the analysis:

**`galaxy_observatory`:** productionReady:nil. Has full state coverage (normal/dim/alert). Was the default scene preference in RC1 settings (`test_defaults_scenePreference_isGalaxyObservatory` passes). **Recommendation:** promote to `productionReady:true` in the next Asset QA PR. No blocking issues.

**`nebula_bot`:** productionReady:nil. Has all 4 standard states. Richest anchor set (7 mount points). **Recommendation:** promote to `productionReady:true` after confirming 24×28 compact form factor renders correctly in the habitat at scale.

Both are left as-is in this hotfix.

---

## On `damaged.png` (nebula_bot)

**Classification: non-renderable development artifact — formally registered.**

In `main`, nebula_bot's manifest explicitly lists `"damaged": "damaged.png"`. The file exists. This is NOT an orphan — it is formally registered. However:
- `PetState` has no `.damaged` case → the renderer can never request it
- It will never appear in the production UI
- It is effectively unreachable dead state

**Decision: retain as debug variant.** No change in this hotfix. The manifest entry keeps it auditable. A future cleanup PR should either (a) add a comment in the manifest noting it's a debug-only frame, or (b) remove both file and manifest entry together as a deliberate deletion.

---

## No Asset Production Status Changes

This hotfix makes **zero changes** to `productionReady` fields. All manifest files are untouched. The only code changes are in `AssetModels.swift`.

---

## Files Changed

| File | Change |
|---|---|
| `PixelPets/Models/AssetModels.swift` | `IntSize` custom Codable (Bug 1) + `PetAsset` custom Codable (Bug 2) |
| `PixelPetsTests/IntSizeCodableTests.swift` | New — 10 unit tests for `IntSize` encode/decode contract |
| `PixelPetsTests/AssetRegistryIntegrationTests.swift` | New — 24 integration tests for real-asset loading and production filtering |
| `PixelPets.xcodeproj/project.pbxproj` | Registered both new test files |

---

## Test Results

| Metric | Before | After |
|---|--:|--:|
| Total tests | 128 | **162** |
| Failures | 0 | **0** |
| New tests added | — | **34** |

New tests are in two suites:
- `IntSizeCodableTests` (10): width/height decode, w/h legacy, encode canonical, round-trip, manifest fixture values
- `AssetRegistryIntegrationTests` (24): load counts, production filtering, known-asset lookup, logical size values, URL resolution, file existence, state coverage

---

## RC1 Dogfood Status

- ✅ All 162 tests pass
- ✅ `AssetRegistry` now loads all 16 manifest assets correctly
- ✅ `productionScenes`, `productionPets`, `productionAccessories` all non-empty
- ✅ `HabitatRenderer` can now use sprite assets (was falling back to procedural drawing since launch)
- ✅ No changes to ActivityCoordinator, VisualStateReducer, or HabitatRenderer flow
- ✅ RC1 Dogfood can continue — this is a safe merge to main

---

## Deferred to Asset Library Import PR

- productionReady:false for galaxy_observatory, nebula_bot, cyber_bamboo, bubble_helmet
- incompatiblePets additions to battery_backpack, sidekick_drone
- AssetGalleryView badge upgrades
- ManifestValidator per-asset summaries
- ASSET_INVENTORY.md, ASSET_LIBRARY_IMPORT_REPORT.md
