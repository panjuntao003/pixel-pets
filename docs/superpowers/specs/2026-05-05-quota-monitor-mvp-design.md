# Quota Monitor MVP — Design Spec

**Date:** 2026-05-05
**Status:** Approved (pending implementation plan)
**Scope:** Phase A — Runtime Refactor (no physical file deletion)

---

## 1. Motivation

Pixel Pets scope-crept into a complex virtual pet system. The original goal was a simple AI tool quota monitor. This spec defines the pivot:

- **Freeze Pixel Pets Core** — keep source files but disconnect from runtime.
- **Quota Monitor MVP** — minimal menu-bar tool showing quota status for AI CLI providers.
- **Phase B** (future) will clean up dead code after MVP is stable.

---

## 2. Tech Stack

- **Language:** Swift 5.9
- **UI:** SwiftUI + AppKit
- **Platform:** macOS menu-bar app (`LSUIElement = true`)
- **Networking:** URLSession (quota APIs)
- **Persistence:** JSON file for settings + latest snapshot
- **Build:** XcodeGen (`project.yml`)

---

## 3. Data Models

### 3.1 `QuotaStatus`

```swift
enum QuotaStatus: String, Codable {
    case normal
    case low          // below configurable threshold
    case exhausted    // fully consumed
    case unavailable  // provider cannot be reached
    case unknown      // not yet queried
}
```

### 3.2 `QuotaSource`

```swift
enum QuotaSource: String, Codable {
    case providerAPI   // direct provider API call
    case localCLI      // from local CLI tool
    case estimated     // heuristics-based estimation
    case manual        // user-provided
    case unknown
}
```

### 3.3 `ProviderQuotaSnapshot`

```swift
struct ProviderQuotaSnapshot: Codable, Equatable {
    let provider: AIProvider
    var status: QuotaStatus
    var remainingPercent: Double?       // 0.0–100.0, nil if unknown
    var resetAt: Date?                  // when quota resets
    let lastCheckedAt: Date             // most recent query attempt
    let lastSuccessfulAt: Date?         // most recent successful fetch
    let source: QuotaSource
    var message: String?                // extra status info
}
```

### 3.4 `QuotaStateStore`

```swift
class QuotaStateStore: ObservableObject {
    @Published var snapshots: [AIProvider: ProviderQuotaSnapshot] = [:]
    @Published var lastRefreshAt: Date?

    func update(provider: AIProvider, snapshot: ProviderQuotaSnapshot)
    func snapshot(for: AIProvider) -> ProviderQuotaSnapshot?
    var primarySnapshot: ProviderQuotaSnapshot? { get }
    var overallStatus: QuotaStatus { get }
}
```

#### `overallStatus` Rules

Priority: `exhausted > low > normal > unknown`

- `overallStatus` and `primarySnapshot` MUST be calculated based on `enabledProviders` (Set<AIProvider>), passed in as a parameter or managed by `QuotaCoordinator`.
- `QuotaStateStore` does NOT guess which providers are enabled — it only stores snapshots.
- The caller (QuotaCoordinator) is responsible for filtering by enabled providers.
- Disabled provider snapshots are excluded from calculation.
- `unavailable` only returned when ALL enabled providers are unavailable, or no provider is enabled.

### 3.5 What is NOT stored

- No prompt text
- No code content
- No request bodies
- No token usage history
- No time-series data
- Only latest snapshot is persisted; no history.

---

## 4. Architecture

### 4.1 Phase A File Layout

```
PixelPets/
├── App/
│   ├── PixelPetsApp.swift          # Simplified entry (no Pixel Pets runtime)
│   ├── AppDelegate.swift           # Menu bar dot + popover
│   └── QuotaCoordinator.swift      # NEW: replaces AppCoordinator
├── Models/
│   ├── AIProvider.swift            # KEPT
│   ├── QuotaStatus.swift           # NEW
│   ├── QuotaSource.swift           # NEW
│   ├── ProviderQuotaSnapshot.swift  # NEW
│   └── QuotaStateStore.swift       # NEW
├── Senses/
│   ├── ClaudeQuotaClient.swift     # KEPT (extract Codex/Gemini to own files)
│   ├── CodexQuotaClient.swift      # NEW (extracted)
│   └── GeminiQuotaClient.swift     # NEW (extracted)
├── UI/
│   ├── PopoverView.swift           # REWRITTEN: minimal cards
│   ├── QuotaCardView.swift         # NEW: single provider card
│   ├── MenuBarDotView.swift        # NEW: colored status dot
│   └── Settings/
│       └── SettingsView.swift      # TRIMMED: only Quota Monitor tab
├── Persistence/
│   └── SettingsStore.swift         # KEPT, trimmed settings model
│
├── (All Pixel Pets files retained on disk, not referenced)
│   ├── Core/       (disconnected)
│   ├── Renderer/   (disconnected)
│   ├── Models/     (quota models kept, pet models disconnected)
│   ├── Resources/  (assets kept on disk, not loaded)
│   └── ...
```

### 4.2 What gets disconnected in Phase A

| Module | Action |
|---|---|
| `PetStateMachine.swift` | Not imported |
| `ActivityCoordinator.swift` | Not imported |
| `VisualStateReducer.swift` | Not imported |
| `PetViewModel.swift` | Not imported |
| `GrowthEngine.swift`, `GrowthStore.swift` | Not imported |
| `AssetRegistry.swift`, `ManifestValidator.swift` | Not imported |
| `Renderer/` (all files) | Not imported |
| `Scenes/` (all files) | Not imported |
| `FX/` (all files) | Not imported |
| `SystemEventSource.swift` + event sources | Not imported |
| `BitBotV2Renderer.swift` etc. | Not imported |
| `MenuBarIconRenderer.swift` | Not imported |
| `ProceduralSpriteCache.swift` | Not imported |
| `AnimationClock.swift` | Not imported |
| `HabitatView.swift` | Not imported |
| `CliCardView.swift` | Not imported |
| `QuotaBarView.swift` | Not imported |
| `AssetGalleryView.swift` | Not imported |
| `DebugStateHUD.swift` | Not imported |
| `HookPermissionView.swift` | Not imported |
| `HookServer.swift` | Not imported (audit first) |
| `HookRegistrar.swift` | Not imported (audit first) |
| `NodeGate.swift` | Not imported (audit first) |
| Log parsers (Claude, Codex, Gemini, OpenCode) | Not imported (audit first) |
| Settings: Unit/Loadout/Map tabs | Removed from SettingsView |

### 4.3 Audit Items (before Phase B deletion)

- **HookServer / HookRegistrar / NodeGate:** Only serve pet events via hook scripts. Do NOT contribute to quota data. Safe to disconnect.
- **Log parsers:** Only serve token counting for GrowthEngine. Do NOT contribute to quota data. Safe to disconnect.
- **Quota clients:** These ARE the quota data source. Keep and enhance.

---

## 5. UI Design

### 5.1 Menu Bar

- 12x12 solid colored dot via `NSStatusItem`
- Colors: green (normal), yellow (low), red (exhausted), gray (unavailable/no providers)
- Tooltip shows summary: "Claude 65% · Codex Exhausted · Gemini OK"
- No text in menu bar

### 5.2 Popover (~280x320, compact)

```
┌─────────────────────────────┐
│  Quota Monitor              │
│                             │
│  ● Claude                   │
│    65% remaining · Normal   │
│    Resets in 3h 20m         │
│    Updated 2 min ago        │
│                             │
│  ● Codex                    │
│    Exhausted                │
│    Resets in 1d 5h          │
│    Updated 1 min ago        │
│                             │
│  ● Gemini                   │
│    Unavailable              │
│    Last checked: just now   │
│                             │
│  ● OpenCode                 │
│    100% · Normal            │
│    Updated just now         │
│                             │
│  ─────────────────────────  │
│  Refreshed 2 min ago    [↻] │
│                    [Settings]│
└─────────────────────────────┘
```

### 5.3 Settings Window

Keep Settings scene. Only one tab: Quota Monitor.

| Setting | Type | Default |
|---|---|---|
| Enable Claude | Toggle | on |
| Enable Codex | Toggle | on |
| Enable Gemini | Toggle | on |
| Enable OpenCode | Toggle | on |
| Low quota threshold | Slider/Stepper | 20% |
| Refresh interval | Picker (1/5/15/30 min) | 5 min |
| Enable Pixel Pet | Toggle | off |

---

## 6. Error Handling

| Scenario | Behavior |
|---|---|
| Provider API unreachable | `status = .unavailable`, card shows "Unavailable", silent |
| Network timeout | Same as above |
| Auth expired (Claude OAuth) | `status = .unavailable`, attempt token refresh |
| Settings file corrupt | Rebuild with defaults |
| No providers enabled | Gray dot, popover shows "No providers enabled" |

No complex notification system. Status is conveyed through colors and card labels.

---

## 7. Quota Clients

### 7.1 Existing clients to keep

- `ClaudeQuotaClient` — fetches from `api.anthropic.com`, OAuth via Keychain
- `CodexQuotaClient` — currently embedded in `ClaudeQuotaClient.swift`, extract to own file
- `GeminiQuotaClient` — currently embedded in `ClaudeQuotaClient.swift`, extract to own file
- `OpenCodeQuotaClient` — in `OpenCodeGoQuotaClient.swift`, keep for OpenCode support

### 7.2 Client responsibilities

Each client:
1. Fetches quota data from its provider's API
2. Returns a `ProviderQuotaSnapshot`
3. Handles auth, timeouts, errors
4. Does NOT parse logs or hook events

---

## 8. Refresh Strategy

- **Timer-based:** `QuotaCoordinator` runs a `Timer` at configurable interval (default 5 min)
- **Manual refresh:** Button in popover triggers immediate refresh
- **Parallel fetch:** All enabled providers fetched concurrently via `TaskGroup`
- **Rate limiting:** Minimum 30s between fetches per provider

---

## 9. Persistence

- **Settings:** `~/Library/Application Support/com.pixelpets.app/settings.json` — also stores latest snapshot as a `quotas` field
- **No separate snapshot file** — keep it simple, one JSON file
- No SQLite (GrowthStore deleted in Phase B)
- No Keychain changes (Claude OAuth credentials kept)

---

## 10. Acceptance Criteria

1. Menu bar shows colored status dot reflecting overall quota health
2. Clicking dot opens popover with Claude / Codex / Gemini / OpenCode cards
3. Each card shows: provider name, status, remaining %, reset countdown, last update time
   - Success: shows "Updated X ago" using `lastSuccessfulAt`
   - Failure: shows "Last checked X ago" using `lastCheckedAt`
4. Manual refresh button works
5. Timer-based auto-refresh works
6. Unavailable providers degrade silently (gray dot, card label)
7. **No Pixel Pets runtime verification:**
   - `AssetRegistry` not initialized
   - `AnimationClock` not started
   - `HookServer` not started
   - Debug HUD not displayed
   - Rendering / Scenes / FX not on main execution path
8. Settings window works with only Quota Monitor tab
   - "Enable Pixel Pet" field kept in model but hidden in UI (or shown as "Coming later")
9. `xcodebuild test` passes (existing tests that don't depend on pet code)
10. All existing source files remain on disk (Phase B will clean up)

---

## 11. Out of Scope

- Trend charts / time-series history
- Complex notification system
- Pet skins, scenes, accessories, FX
- Asset library / content packs
- Growth / leveling / token tracking
- Debug HUD / Asset Gallery
- Hook registration
