# PixelPets MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app featuring Bit-Bot, a pixel robot pet that reacts to AI CLI tool usage in real time and grows over time as token consumption accumulates.

**Architecture:** Top-down, 6 phases. Phase 0 locks prerequisites and collects real fixture data before writing any integration code. Phase 1 builds the full renderer and panel UI with mock data. Phases 2–5 wire in real data with graceful degradation at every layer.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (NSStatusItem/NSPopover), ObservableObject + @Published (macOS 13+ compatible), Network.framework (NWListener), URLSession async/await, SQLite3 (direct, no ORM), Node.js hook scripts (bundled, optional).

**Degradation contract:**
- No Node.js → hooks unavailable, pet still shows quota + growth
- Quota API fails → shows "未连接", not fake data
- No CLI installed → card hidden, not error

---

## File Map

```
PixelPets/                          ← Xcode project root (created manually)
├── PixelPets/
│   ├── App/
│   │   ├── PixelPetsApp.swift      # @main, AppDelegate wiring
│   │   └── AppCoordinator.swift    # NSStatusItem + NSPopover + orchestration
│   ├── Models/
│   │   ├── PetState.swift          # PetState enum (12 cases)
│   │   ├── AgentSkin.swift         # AgentSkin enum + palette
│   │   ├── QuotaTier.swift         # QuotaTier struct + QuotaFetchResult enum
│   │   ├── Accessory.swift         # Accessory enum + slot/threshold
│   │   └── PetViewModel.swift      # ObservableObject source of truth
│   ├── Core/
│   │   ├── PetStateMachine.swift   # Hook events → PetState
│   │   ├── GrowthEngine.swift      # Tokens → Level + Accessories
│   │   └── QuotaMonitor.swift      # Tiers + idle time → Sleep/Wake
│   ├── Renderer/
│   │   ├── PixelColor.swift        # Color(hex:) + AgentPalette constants
│   │   ├── FaceProvider.swift      # FaceProvider protocol + BitBotFaceProvider
│   │   ├── BitBotRenderer.swift    # Canvas 6-layer draw
│   │   └── AnimationClock.swift    # TimelineView 30fps frame counter
│   ├── Senses/
│   │   ├── HookServer.swift        # NWListener on 127.0.0.1:15799
│   │   ├── NodeGate.swift          # NodeAvailability detection
│   │   ├── HookRegistrar.swift     # Per-CLI registration with backup + dry-run
│   │   ├── LogPoller.swift         # DispatchSource + mtime cursor + installedAt filter
│   │   ├── ClaudeLogParser.swift   # ~/.claude/projects/**/*.jsonl → TokenBatch
│   │   ├── GeminiLogParser.swift   # ~/.gemini/tmp/*/chats/*.json → TokenBatch
│   │   ├── CodexLogParser.swift    # ~/.codex/sessions/*.jsonl → TokenBatch
│   │   ├── OpenCodeLogParser.swift # opencode.db (read-only SQLite3) → TokenBatch
│   │   ├── ClaudeQuotaClient.swift # api.anthropic.com/api/oauth/usage
│   │   └── CodexQuotaClient.swift  # chatgpt.com/backend-api/wham/usage
│   ├── UI/
│   │   ├── MenuBarIcon.swift       # NSHostingView wrapping AnimationClock (16×16)
│   │   ├── PopoverView.swift       # Root 360px popover
│   │   ├── PetDisplayView.swift    # Top 110px: pet + agent label
│   │   ├── CliCardView.swift       # Per-CLI quota card
│   │   ├── QuotaBarView.swift      # Single progress bar with ~ indicator
│   │   └── HookPermissionView.swift# First-launch permission dialog
│   ├── Persistence/
│   │   ├── GrowthStore.swift       # SQLite3: growth_progress, cursor_store
│   │   └── SettingsStore.swift     # ~/.pixelpets/settings.json
│   └── Resources/
│       ├── hooks/
│       │   ├── pixelpets-hook.js   # Claude Code hook
│       │   ├── gemini-hook.js      # Gemini CLI hook
│       │   └── codex-hook.js       # Codex hook
│       └── Fixtures/               # Real sample data for tests
│           ├── claude_sample.jsonl
│           ├── gemini_sample.json
│           ├── codex_sample.jsonl
│           └── opencode_sample.sql # INSERT statements from real DB
├── PixelPetsTests/
│   ├── PetStateMachineTests.swift
│   ├── GrowthEngineTests.swift
│   ├── QuotaMonitorTests.swift
│   ├── ClaudeLogParserTests.swift  # Uses Fixtures/claude_sample.jsonl
│   ├── GeminiLogParserTests.swift
│   ├── CodexLogParserTests.swift
│   └── OpenCodeLogParserTests.swift
```

---

## Phase 0 — Prerequisites & Fixture Collection

### Task 0: Lock Prerequisites

**Files:**
- Create: Xcode project (manual GUI step)
- Create: `PixelPets/Resources/Fixtures/` (populated from real CLI data)

- [ ] **Step 1: Create Xcode project manually**

  File → New → Project → macOS → App.
  - Product Name: `PixelPets`
  - Bundle ID: `com.pixelpets.app`
  - Interface: SwiftUI, Language: Swift
  - Uncheck "Include Tests"

  Then: File → New → Target → Unit Testing Bundle → `PixelPetsTests`.

- [ ] **Step 2: Set deployment target**

  Project settings → PixelPets target → Deployment Info → macOS **13.0**.

- [ ] **Step 3: Suppress Dock icon**

  In `Info.plist`: add `LSUIElement` = YES (Boolean).

- [ ] **Step 4: Initialize git**

  ```bash
  cd /Users/panjuntao/Developer/pixel-pets
  git init
  git add .
  git commit -m "chore: xcode project, macOS 13 target, no dock icon"
  ```

- [ ] **Step 5: Collect Claude fixture**

  ```bash
  # Find the most recent Claude session file
  find ~/.claude/projects -name "*.jsonl" -newer ~/.claude/projects -maxdepth 3 | head -1
  # Copy 20 lines from it
  head -20 <that-file> > PixelPets/Resources/Fixtures/claude_sample.jsonl
  ```
  Verify it contains lines with `"usage"` key:
  ```bash
  grep -c '"usage"' PixelPets/Resources/Fixtures/claude_sample.jsonl
  ```
  Expected: count > 0. If 0, try a different file.

- [ ] **Step 6: Collect Gemini fixture**

  ```bash
  find ~/.gemini/tmp -name "*.json" | head -1
  cp <that-file> PixelPets/Resources/Fixtures/gemini_sample.json
  ```
  Verify:
  ```bash
  python3 -c "import json,sys; d=json.load(open('PixelPets/Resources/Fixtures/gemini_sample.json')); print(list(d.keys()))"
  ```

- [ ] **Step 7: Collect Codex fixture**

  ```bash
  find ~/.codex/sessions -name "*.jsonl" 2>/dev/null | head -1
  # If no sessions dir, check CODEX_HOME
  head -20 <that-file> > PixelPets/Resources/Fixtures/codex_sample.jsonl
  ```

- [ ] **Step 8: Collect OpenCode fixture**

  ```bash
  DB="$HOME/Library/Application Support/opencode/opencode.db"
  # Inspect schema
  sqlite3 "$DB" ".schema part" 2>/dev/null || echo "table 'part' not found"
  # Extract 5 rows with token data
  sqlite3 "$DB" "SELECT data FROM part LIMIT 20;" 2>/dev/null \
    | python3 -c "
  import sys, json
  for line in sys.stdin:
      try:
          d = json.loads(line.strip())
          if 'tokens' in d: print(json.dumps(d)); break
      except: pass
  " > PixelPets/Resources/Fixtures/opencode_sample.json
  cat PixelPets/Resources/Fixtures/opencode_sample.json
  ```
  If the DB path or table name differ, record the actual path here before proceeding.

- [ ] **Step 9: Verify Claude Keychain credential**

  ```bash
  security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | python3 -c "
  import sys, json
  d = json.loads(sys.stdin.read())
  key = 'claudeAiOauth' if 'claudeAiOauth' in d else 'claude.ai_oauth'
  token = d[key]['accessToken']
  print('Token prefix:', token[:20], '...')
  print('Expires:', d[key].get('expiresAt'))
  "
  ```
  If this fails, check `~/.claude/.credentials.json` instead. Record the actual key name found.

- [ ] **Step 10: Verify Claude quota API response**

  ```bash
  TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); k='claudeAiOauth' if 'claudeAiOauth' in d else 'claude.ai_oauth'; print(d[k]['accessToken'])")
  curl -s "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $TOKEN" \
    -H "anthropic-beta: oauth-2025-04-20" | python3 -m json.tool | head -30
  ```
  Record the actual top-level keys returned (e.g. `five_hour`, `seven_day`, etc.).

- [ ] **Step 11: Verify Codex credentials**

  ```bash
  cat ~/.codex/auth.json 2>/dev/null | python3 -c "
  import sys, json; d=json.load(sys.stdin)
  print('auth_mode:', d.get('auth_mode'))
  print('has tokens:', 'tokens' in d)
  " || echo "auth.json not found"
  ```

- [ ] **Step 12: Check Node.js**

  ```bash
  which node && node --version || echo "node not found"
  ```

- [ ] **Step 13: Commit fixtures**

  ```bash
  git add PixelPets/Resources/Fixtures/
  git commit -m "chore: real fixture files from local CLI data for parser tests"
  ```

---

## Phase 1 — Models + Renderer + Panel UI (Mock Data)

### Task 1: Core Models

**Files:**
- Create: `PixelPets/Models/PetState.swift`
- Create: `PixelPets/Models/AgentSkin.swift`
- Create: `PixelPets/Models/QuotaTier.swift`
- Create: `PixelPets/Models/Accessory.swift`
- Create: `PixelPets/Models/PetViewModel.swift`
- Create: `PixelPets/Renderer/PixelColor.swift`

- [ ] **Step 1: `PetState.swift`**

  ```swift
  enum PetState: Equatable {
      case idle, thinking, typing, juggling, conducting
      case success, error, sleeping, auth, fast, searching, evolving
  }
  ```

- [ ] **Step 2: `AgentSkin.swift`**

  ```swift
  import SwiftUI

  enum AgentSkin: String, CaseIterable, Codable {
      case claude, gemini, codex, opencode

      var displayName: String {
          switch self {
          case .claude:   return "Claude Code"
          case .gemini:   return "Gemini CLI"
          case .codex:    return "Codex"
          case .opencode: return "OpenCode"
          }
      }

      var personalityTag: String {
          switch self {
          case .claude:   return "CLAUDE / 热血程序员"
          case .gemini:   return "GEMINI / 赛博法师"
          case .codex:    return "CODEX / 冷酷分析师"
          case .opencode: return "OPENCODE / 暗网黑客"
          }
      }
  }
  ```

- [ ] **Step 3: `PixelColor.swift`**

  ```swift
  import SwiftUI

  extension Color {
      init(hex: String) {
          let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
          var n: UInt64 = 0
          Scanner(string: h).scanHexInt64(&n)
          self.init(red: Double((n>>16)&0xFF)/255,
                    green: Double((n>>8)&0xFF)/255,
                    blue: Double(n&0xFF)/255)
      }
  }

  enum AgentPalette {
      static let claude      = Color(hex: "D97757")
      static let codexTop    = Color(hex: "7851FB")
      static let codexBottom = Color(hex: "2853FF")
      static let opencode    = Color(hex: "000000")
      static let outline     = Color(hex: "000000")
      static let screen      = Color.white
      static let quotaGreen  = Color(hex: "34A853")
      static let quotaYellow = Color(hex: "FBBC05")
      static let quotaRed    = Color(hex: "EA4335")
  }
  ```

- [ ] **Step 4: `QuotaTier.swift`**

  ```swift
  import Foundation

  enum QuotaFetchResult {
      case success([QuotaTier])
      case unavailable(String)   // reason, shown in UI
      case estimated([QuotaTier])
  }

  struct QuotaTier: Identifiable {
      let id: String           // "five_hour", "seven_day", "rolling", "weekly"
      var utilization: Double  // fraction used (0.0–1.0)
      var resetsAt: Date?
      var isEstimated: Bool

      var remaining: Double { max(0, 1 - utilization) }

      var displayLabel: String {
          switch id {
          case "five_hour":            return "Current session"
          case "rolling":              return "Rolling"
          case "seven_day", "weekly":  return "Weekly"
          default:                     return id
          }
      }

      var resetsInString: String {
          guard let date = resetsAt else { return "Unknown" }
          let s = date.timeIntervalSinceNow
          guard s > 0 else { return "Resetting…" }
          let h = Int(s) / 3600; let m = (Int(s) % 3600) / 60
          if h >= 24 { return "Resets in \(h/24)d \(h%24)h" }
          if h > 0   { return "Resets in \(h)h \(m)m" }
          return "Resets in \(m)m"
      }
  }
  ```

- [ ] **Step 5: `Accessory.swift`**

  ```swift
  enum AccessorySlot { case top, back, side }

  enum Accessory: String, CaseIterable, Codable {
      case sprout, headset, halo, antenna          // top
      case battery, jetpack, cape                  // back
      case minidrone, codecloud                    // side

      var slot: AccessorySlot {
          switch self {
          case .sprout, .headset, .halo, .antenna: return .top
          case .battery, .jetpack, .cape:           return .back
          case .minidrone, .codecloud:              return .side
          }
      }

      var tokenThreshold: Int {
          switch self {
          case .sprout:    return 500_000
          case .battery:   return 2_000_000
          case .minidrone: return 5_000_000
          case .halo:      return 10_000_000
          case .headset:   return 3_000_000
          case .jetpack:   return 8_000_000
          case .cape:      return 15_000_000
          case .antenna:   return 20_000_000
          case .codecloud: return 12_000_000
          }
      }
  }
  ```

- [ ] **Step 6: `PetViewModel.swift`** (ObservableObject, macOS 13 compatible)

  ```swift
  import Foundation
  import Combine

  struct CliQuotaInfo: Identifiable {
      let id: AgentSkin
      var fetchResult: QuotaFetchResult = .unavailable("未检测到")
      var todayTokens: Int = 0
      var weekTokens: Int = 0
      var planBadge: String = ""
      var isDetected: Bool = false

      var tiers: [QuotaTier] {
          switch fetchResult {
          case .success(let t), .estimated(let t): return t
          case .unavailable: return []
          }
      }
      var isUnavailable: Bool {
          if case .unavailable = fetchResult { return true }
          return false
      }
  }

  final class PetViewModel: ObservableObject {
      @Published var state: PetState = .idle
      @Published var activeSkin: AgentSkin = .claude
      @Published var level: Int = 1
      @Published var accessories: [Accessory] = []
      @Published var cliInfos: [CliQuotaInfo] = []
      @Published var totalLifetimeTokens: Int = 0
      @Published var hooksAvailable: Bool = false   // false if node missing

      var visibleClis: [CliQuotaInfo] { cliInfos.filter(\.isDetected) }

      static func mock() -> PetViewModel {
          let vm = PetViewModel()
          vm.state = .idle
          vm.activeSkin = .claude
          vm.hooksAvailable = true
          vm.cliInfos = [
              CliQuotaInfo(
                  id: .claude,
                  fetchResult: .success([
                      QuotaTier(id: "five_hour", utilization: 0.33,
                                resetsAt: Date().addingTimeInterval(4940), isEstimated: false),
                      QuotaTier(id: "seven_day", utilization: 0.34,
                                resetsAt: Date().addingTimeInterval(432000), isEstimated: false)
                  ]),
                  todayTokens: 2_300_000, weekTokens: 8_100_000,
                  planBadge: "Pro", isDetected: true
              ),
              CliQuotaInfo(
                  id: .opencode,
                  fetchResult: .estimated([
                      QuotaTier(id: "rolling", utilization: 0.07,
                                resetsAt: Date().addingTimeInterval(8520), isEstimated: true),
                      QuotaTier(id: "weekly", utilization: 0.50,
                                resetsAt: Date().addingTimeInterval(504000), isEstimated: true)
                  ]),
                  todayTokens: 1_100_000, weekTokens: 4_200_000,
                  planBadge: "Go", isDetected: true
              )
          ]
          vm.totalLifetimeTokens = 42_100_000
          return vm
      }
  }
  ```

- [ ] **Step 7: Build**

  ⌘B. Expected: compiles cleanly.

- [ ] **Step 8: Commit**

  ```bash
  git add PixelPets/Models/ PixelPets/Renderer/PixelColor.swift
  git commit -m "feat: core models — PetState, AgentSkin, QuotaTier, Accessory, PetViewModel (ObservableObject)"
  ```

---

### Task 2: BitBot Renderer + Animation Clock

**Files:**
- Create: `PixelPets/Renderer/FaceProvider.swift`
- Create: `PixelPets/Renderer/AnimationClock.swift`
- Create: `PixelPets/Renderer/BitBotRenderer.swift`

- [ ] **Step 1: `AnimationClock.swift`**

  ```swift
  import SwiftUI

  struct AnimationClock<Content: View>: View {
      let fps: Double
      @ViewBuilder let content: (Int) -> Content
      @State private var frame = 0

      var body: some View {
          TimelineView(.periodic(from: .now, by: 1.0 / fps)) { ctx in
              content(frame)
                  .onChange(of: ctx.date) { _, _ in frame += 1 }
          }
      }
  }
  ```

- [ ] **Step 2: `FaceProvider.swift`** (protocol + pixel helper)

  ```swift
  import SwiftUI

  protocol FaceProvider {
      func draw(in ctx: GraphicsContext, state: PetState, frame: Int, scale: CGFloat)
  }

  extension GraphicsContext {
      func fillPixel(x: Int, y: Int, color: Color, scale: CGFloat) {
          fill(Path(CGRect(x: CGFloat(x)*scale, y: CGFloat(y)*scale,
                           width: scale, height: scale)),
               with: .color(color))
      }
  }
  ```

- [ ] **Step 3: `BitBotRenderer.swift`** — 6 layers, idle face only for now

  ```swift
  import SwiftUI

  struct BitBotRenderer: View {
      @ObservedObject var viewModel: PetViewModel
      let size: CGFloat
      let frame: Int

      var body: some View {
          Canvas { ctx, sz in
              let scale = sz.width / 16.0
              drawSkin(ctx, scale: scale)
              drawShading(ctx, scale: scale)
              drawBody(ctx, scale: scale)
              drawFace(ctx, scale: scale)
              drawAccessories(ctx, scale: scale)
              drawFX(ctx, scale: scale)
          }
          .frame(width: size, height: size)
      }

      // Layer 1: Agent skin fill
      private func drawSkin(_ ctx: GraphicsContext, scale: CGFloat) {
          let color: Color
          switch viewModel.activeSkin {
          case .claude:   color = AgentPalette.claude
          case .opencode: color = AgentPalette.opencode
          case .gemini:   color = AgentPalette.claude    // P1: proper gradient
          case .codex:    color = AgentPalette.codexTop  // P1: proper gradient
          }
          for y in 0..<16 { for x in 0..<16 {
              guard isBody(x: x, y: y) else { continue }
              ctx.fillPixel(x: x, y: y, color: color, scale: scale)
          }}
      }

      // Layer 2: Shading (1px highlight top-left, shadow bottom-right)
      private func drawShading(_ ctx: GraphicsContext, scale: CGFloat) {
          for (x,y) in [(2,2),(3,2),(2,3)] {
              ctx.fillPixel(x: x, y: y, color: .white.opacity(0.2), scale: scale)
          }
          for (x,y) in [(12,13),(13,12),(13,13)] {
              ctx.fillPixel(x: x, y: y, color: .black.opacity(0.2), scale: scale)
          }
      }

      // Layer 3: Outline + screen border + legs
      private func drawBody(_ ctx: GraphicsContext, scale: CGFloat) {
          let c = AgentPalette.outline
          for x in 1..<15 { ctx.fillPixel(x: x, y: 0, color: c, scale: scale)
                             ctx.fillPixel(x: x, y: 15, color: c, scale: scale) }
          for y in 1..<15 { ctx.fillPixel(x: 0, y: y, color: c, scale: scale)
                             ctx.fillPixel(x: 15, y: y, color: c, scale: scale) }
          // Screen border rows 5–10, cols 3–12
          for x in 3..<13 { ctx.fillPixel(x: x, y: 5, color: c, scale: scale)
                             ctx.fillPixel(x: x, y: 10, color: c, scale: scale) }
          for y in 6..<10 { ctx.fillPixel(x: 3, y: y, color: c, scale: scale)
                             ctx.fillPixel(x: 12, y: y, color: c, scale: scale) }
          // Legs
          ctx.fillPixel(x: 5, y: 14, color: c, scale: scale)
          ctx.fillPixel(x: 10, y: 14, color: c, scale: scale)
      }

      // Layer 4: Face (screen content)
      private func drawFace(_ ctx: GraphicsContext, scale: CGFloat) {
          // Screen fill
          for y in 6..<10 { for x in 4..<12 {
              ctx.fillPixel(x: x, y: y, color: AgentPalette.screen, scale: scale)
          }}
          BitBotFaceProvider().draw(in: ctx, state: viewModel.state, frame: frame, scale: scale)
      }

      // Layer 5: Accessories
      private func drawAccessories(_ ctx: GraphicsContext, scale: CGFloat) {
          if viewModel.accessories.contains(.sprout) { drawSprout(ctx, scale: scale) }
      }

      private func drawSprout(_ ctx: GraphicsContext, scale: CGFloat) {
          ctx.fillPixel(x: 8, y: 1, color: Color(hex: "5A8A2A"), scale: scale)
          ctx.fillPixel(x: 7, y: 0, color: Color(hex: "34A853"), scale: scale)
      }

      // Layer 6: FX (placeholder, P1)
      private func drawFX(_ ctx: GraphicsContext, scale: CGFloat) { }

      private func isBody(x: Int, y: Int) -> Bool {
          ![[0,0],[15,0],[0,15],[15,15]].contains([x,y])
      }
  }
  ```

- [ ] **Step 4: `BitBotFaceProvider`** — add to `FaceProvider.swift`

  ```swift
  struct BitBotFaceProvider: FaceProvider {
      func draw(in ctx: GraphicsContext, state: PetState, frame: Int, scale: CGFloat) {
          switch state {
          case .idle:      drawIdle(ctx, frame: frame, scale: scale)
          case .thinking:  drawThinking(ctx, frame: frame, scale: scale)
          case .typing:    drawTyping(ctx, frame: frame, scale: scale)
          case .success:   drawSuccess(ctx, scale: scale)
          case .error:     drawError(ctx, frame: frame, scale: scale)
          case .sleeping:  drawSleeping(ctx, frame: frame, scale: scale)
          case .auth:      drawAuth(ctx, frame: frame, scale: scale)
          default:         drawIdle(ctx, frame: frame, scale: scale)
          }
      }

      private func drawIdle(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
          let blink = (frame % 60) < 55
          let eye = Color(hex: "333333")
          let y = blink ? 7 : 8
          ctx.fillPixel(x: 5, y: y, color: eye, scale: scale)
          ctx.fillPixel(x: 9, y: y, color: eye, scale: scale)
      }

      private func drawThinking(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
          let col = Color(hex: "4285F4")
          let scan = (frame / 2) % 8
          for x in 0..<8 {
              ctx.fillPixel(x: x+4, y: 7, color: col.opacity(x == scan ? 1.0 : 0.3), scale: scale)
          }
      }

      private func drawTyping(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
          let col = Color(hex: "333333")
          let shift = (frame / 3) % 3
          for x in [4+shift, 6+shift, 8+shift] where x < 12 {
              ctx.fillPixel(x: x, y: 7, color: col, scale: scale)
              ctx.fillPixel(x: x, y: 8, color: col, scale: scale)
          }
      }

      private func drawSuccess(_ ctx: GraphicsContext, scale: CGFloat) {
          let c = Color(hex: "333333")
          for (x,y) in [(5,6),(9,6),(4,7),(10,7)] { ctx.fillPixel(x: x, y: y, color: c, scale: scale) }
          for x in 5..<10 { ctx.fillPixel(x: x, y: 9, color: c, scale: scale) }
      }

      private func drawError(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
          let col = (frame%10 < 5) ? Color(hex:"EA4335") : Color(hex:"333333")
          for (x,y) in [(4,6),(6,8),(6,6),(4,8),(8,6),(10,8),(10,6),(8,8)] {
              ctx.fillPixel(x: x, y: y, color: col, scale: scale)
          }
      }

      private func drawSleeping(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
          let c = Color(hex: "888888")
          for (x,y) in [(4,8),(5,8),(8,8),(9,8)] { ctx.fillPixel(x: x, y: y, color: c, scale: scale) }
      }

      private func drawAuth(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
          let pulse = 0.6 + 0.4 * abs(sin(Double(frame) * 0.1))
          let c = Color(hex: "FBBC05").opacity(pulse)
          for (x,y) in [(6,5),(7,5),(5,6),(8,6)] { ctx.fillPixel(x: x, y: y, color: c, scale: scale) }
          for y in 7..<10 { for x in 5..<9 { ctx.fillPixel(x: x, y: y, color: c, scale: scale) } }
      }
  }
  ```

- [ ] **Step 5: Build and run**

  ⌘R. In Xcode, temporarily in `AppCoordinator.start()`:
  ```swift
  let vm = PetViewModel.mock()
  let view = AnimationClock(fps: 30) { frame in
      BitBotRenderer(viewModel: vm, size: 16, frame: frame)
  }
  let iconView = NSHostingView(rootView: view)
  iconView.frame = NSRect(x: 0, y: 0, width: 16, height: 16)
  statusItem.button?.addSubview(iconView)
  ```
  Expected: orange robot in menu bar, blinking every ~2 seconds.

- [ ] **Step 6: Commit**

  ```bash
  git add PixelPets/Renderer/
  git commit -m "feat: BitBot 6-layer Canvas renderer, 7 face states, idle blink"
  ```

---

### Task 3: Popover Panel UI

**Files:**
- Create: `PixelPets/UI/QuotaBarView.swift`
- Create: `PixelPets/UI/CliCardView.swift`
- Create: `PixelPets/UI/PetDisplayView.swift`
- Create: `PixelPets/UI/PopoverView.swift`

- [ ] **Step 1: `QuotaBarView.swift`**

  ```swift
  import SwiftUI

  struct QuotaBarView: View {
      let tier: QuotaTier

      private var barColor: Color {
          if tier.remaining > 0.40 { return AgentPalette.quotaGreen }
          if tier.remaining > 0.10 { return AgentPalette.quotaYellow }
          return AgentPalette.quotaRed
      }

      var body: some View {
          VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 2) {
                  Text(tier.displayLabel).font(.system(size: 10, weight: .medium))
                  if tier.isEstimated {
                      Text("~").font(.system(size: 9)).foregroundStyle(.secondary)
                  }
              }
              Text(tier.resetsInString).font(.system(size: 9)).foregroundStyle(.secondary)
              HStack(spacing: 4) {
                  GeometryReader { geo in
                      ZStack(alignment: .leading) {
                          Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 5)
                          Capsule().fill(barColor)
                              .frame(width: geo.size.width * min(tier.utilization, 1.0), height: 5)
                      }
                  }.frame(height: 5)
                  Text("\(Int(tier.utilization * 100))%")
                      .font(.system(size: 9, weight: .semibold))
                      .foregroundStyle(.secondary).frame(width: 26, alignment: .trailing)
              }
          }
      }
  }
  ```

- [ ] **Step 2: `CliCardView.swift`**

  ```swift
  import SwiftUI

  struct CliCardView: View {
      let info: CliQuotaInfo

      private var sessionTier: QuotaTier? { info.tiers.first { $0.id == "five_hour" || $0.id == "rolling" } }
      private var weeklyTier: QuotaTier?  { info.tiers.first { $0.id == "seven_day" || $0.id == "weekly" } }

      var body: some View {
          VStack(alignment: .leading, spacing: 8) {
              HStack {
                  Text(info.id.displayName).font(.system(size: 12, weight: .semibold))
                  Spacer()
                  if !info.planBadge.isEmpty {
                      Text(info.planBadge)
                          .font(.system(size: 10, weight: .medium))
                          .padding(.horizontal, 6).padding(.vertical, 2)
                          .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
                  }
              }

              if info.isUnavailable {
                  Text("未连接 · 无法读取配额")
                      .font(.system(size: 10)).foregroundStyle(.secondary)
              } else {
                  HStack(alignment: .top, spacing: 12) {
                      if let s = sessionTier { QuotaBarView(tier: s).frame(maxWidth: .infinity) }
                      if let w = weeklyTier  { QuotaBarView(tier: w).frame(maxWidth: .infinity) }
                  }
              }

              Text("今日 \(fmt(info.todayTokens)) · 本周 \(fmt(info.weekTokens)) tokens")
                  .font(.system(size: 9)).foregroundStyle(.secondary)
          }
          .padding(12)
          .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }

      private func fmt(_ n: Int) -> String {
          if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
          if n >= 1_000     { return String(format: "%.0fK", Double(n)/1_000) }
          return "\(n)"
      }
  }
  ```

- [ ] **Step 3: `PetDisplayView.swift`**

  ```swift
  import SwiftUI

  struct PetDisplayView: View {
      @ObservedObject var viewModel: PetViewModel

      var body: some View {
          VStack(spacing: 6) {
              AnimationClock(fps: 30) { frame in
                  BitBotRenderer(viewModel: viewModel, size: 22, frame: frame)
                      .scaleEffect(3).frame(width: 66, height: 66)
              }
              Text(viewModel.activeSkin.personalityTag)
                  .font(.system(size: 10, weight: .medium, design: .monospaced))
                  .foregroundStyle(.secondary).tracking(1)
              if !viewModel.hooksAvailable {
                  Text("实时 Hook 不可用 · 未检测到 Node.js")
                      .font(.system(size: 9)).foregroundStyle(.orange)
              }
          }
          .frame(maxWidth: .infinity).frame(height: 110)
      }
  }
  ```

- [ ] **Step 4: `PopoverView.swift`**

  ```swift
  import SwiftUI

  struct PopoverView: View {
      @ObservedObject var viewModel: PetViewModel

      var body: some View {
          VStack(spacing: 0) {
              PetDisplayView(viewModel: viewModel)
              Divider()
              ScrollView {
                  VStack(spacing: 8) {
                      ForEach(viewModel.visibleClis) { info in CliCardView(info: info) }
                  }.padding(12)
              }
              Divider()
              HStack {
                  Text("累计 \(fmt(viewModel.totalLifetimeTokens)) tokens")
                      .font(.system(size: 9)).foregroundStyle(.secondary)
                  Spacer()
                  Button { } label: {
                      Image(systemName: "arrow.clockwise")
                          .font(.system(size: 12)).foregroundStyle(.secondary)
                  }.buttonStyle(.plain).help("刷新配额")
                  Button { } label: {
                      Image(systemName: "gearshape")
                          .font(.system(size: 13)).foregroundStyle(.secondary)
                  }.buttonStyle(.plain)
              }.padding(.horizontal, 12).padding(.vertical, 8)
          }.frame(width: 360)
      }

      private func fmt(_ n: Int) -> String {
          n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000) : "\(n)"
      }
  }
  ```

- [ ] **Step 5: Run and verify**

  Click menu bar icon. Expected: 360px popover, Bit-Bot animation top, Claude + OpenCode mock cards with dual progress bars, bottom stats bar.

- [ ] **Step 6: Commit**

  ```bash
  git add PixelPets/UI/
  git commit -m "feat: popover UI — pet display, CLI cards, dual quota bars, bottom bar"
  ```

---

## Phase 2 — State Machine + Hook Server

### Task 4: PetStateMachine

**Files:**
- Create: `PixelPets/Core/PetStateMachine.swift`
- Create: `PixelPetsTests/PetStateMachineTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  import XCTest
  @testable import PixelPets

  final class PetStateMachineTests: XCTestCase {
      var m: PetStateMachine!
      override func setUp() { m = PetStateMachine() }

      func test_initial_isIdle()                    { XCTAssertEqual(m.currentState, .idle) }
      func test_UserPromptSubmit_thinking()         { m.handle("UserPromptSubmit", [:]); XCTAssertEqual(m.currentState, .thinking) }
      func test_PreToolUse_typing()                 { m.handle("PreToolUse", [:]); XCTAssertEqual(m.currentState, .typing) }
      func test_PreToolUse_webSearch_searching()    { m.handle("PreToolUse", ["tool_name":"web_search"]); XCTAssertEqual(m.currentState, .searching) }
      func test_Stop_success()                      { m.handle("Stop", [:]); XCTAssertEqual(m.currentState, .success) }
      func test_PostToolUseFailure_error()          { m.handle("PostToolUseFailure", [:]); XCTAssertEqual(m.currentState, .error) }
      func test_oneSubagent_juggling()              { m.handle("SubagentStart", [:]); XCTAssertEqual(m.currentState, .juggling) }
      func test_twoSubagents_conducting()           { m.handle("SubagentStart", [:]); m.handle("SubagentStart", [:]); XCTAssertEqual(m.currentState, .conducting) }
      func test_PermissionRequest_auth()            { m.handle("PermissionRequest", [:]); XCTAssertEqual(m.currentState, .auth) }
      func test_SessionEnd_resetsSubagentCount()    { m.handle("SubagentStart", [:]); m.handle("SessionEnd", [:]); XCTAssertEqual(m.activeSubagentCount, 0) }
      func test_applyQuotaRecommendation_sleeping() { m.applyQuotaRecommendation(.sleeping); XCTAssertEqual(m.currentState, .sleeping) }
      func test_applyQuotaRecommendation_onlyWhenIdle() {
          m.handle("UserPromptSubmit", [:])   // thinking
          m.applyQuotaRecommendation(.sleeping)
          XCTAssertEqual(m.currentState, .thinking)  // hook wins
      }
  }
  ```

- [ ] **Step 2: Run — expect compiler error**

- [ ] **Step 3: `PetStateMachine.swift`**

  ```swift
  import Foundation

  final class PetStateMachine {
      private(set) var currentState: PetState = .idle
      private(set) var activeSubagentCount: Int = 0
      private var lastHookEvent: Date?

      func handle(_ event: String, _ payload: [String: Any]) {
          lastHookEvent = Date()
          switch event {
          case "UserPromptSubmit": transition(.thinking)
          case "PreToolUse":
              let tool = payload["tool_name"] as? String ?? ""
              transition(["web_search","read_file","web_fetch","glob","grep"].contains(tool) ? .searching : .typing)
          case "PostToolUse":  transition(.typing)
          case "PostToolUseFailure", "StopFailure": transition(.error)
          case "Stop":  activeSubagentCount = 0; transition(.success)
          case "SubagentStart":
              activeSubagentCount += 1
              transition(activeSubagentCount >= 2 ? .conducting : .juggling)
          case "SubagentStop":
              activeSubagentCount = max(0, activeSubagentCount - 1)
              if activeSubagentCount == 0 { transition(.typing) }
          case "PermissionRequest": transition(.auth)
          case "SessionEnd": activeSubagentCount = 0; transition(.idle)
          case "PreCompact": transition(.searching)
          default: break
          }
      }

      /// Quota monitor calls this. Only takes effect when machine is in idle/sleeping — hook events win.
      func applyQuotaRecommendation(_ state: PetState) {
          guard currentState == .idle || currentState == .sleeping else { return }
          transition(state)
      }

      func forceEvolve() { transition(.evolving) }

      private func transition(_ state: PetState) { currentState = state }
  }
  ```

- [ ] **Step 4: Run — all 12 tests pass**

- [ ] **Step 5: Commit**

  ```bash
  git add PixelPets/Core/PetStateMachine.swift PixelPetsTests/PetStateMachineTests.swift
  git commit -m "feat: PetStateMachine — 12-state hook handler, applyQuotaRecommendation API"
  ```

---

### Task 5: HookServer + NodeGate

**Files:**
- Create: `PixelPets/Senses/NodeGate.swift`
- Create: `PixelPets/Senses/HookServer.swift`

- [ ] **Step 1: `NodeGate.swift`**

  ```swift
  import Foundation

  enum NodeAvailability {
      case available(path: String)
      case unavailable
  }

  final class NodeGate {
      static func detect() -> NodeAvailability {
          let candidates = ["/usr/local/bin/node", "/opt/homebrew/bin/node", "/usr/bin/node"]
          // Check $PATH via `which node`
          let task = Process(); task.launchPath = "/bin/zsh"; task.arguments = ["-c", "which node"]
          let pipe = Pipe(); task.standardOutput = pipe
          try? task.run(); task.waitUntilExit()
          let found = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
              .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          if !found.isEmpty { return .available(path: found) }
          // Fallback: check known paths
          for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
              return .available(path: path)
          }
          return .unavailable
      }
  }
  ```

- [ ] **Step 2: `HookServer.swift`**

  ```swift
  import Foundation
  import Network

  final class HookServer {
      static let port: UInt16 = 15799
      var onEvent: ((String, [String: Any]) -> Void)?
      private var listener: NWListener?

      func start() {
          let params = NWParameters.tcp
          params.acceptLocalOnly = true
          guard let port = NWEndpoint.Port(rawValue: Self.port) else { return }
          listener = try? NWListener(using: params, on: port)
          listener?.newConnectionHandler = { [weak self] c in self?.handle(c) }
          listener?.start(queue: .global(qos: .utility))
      }

      func stop() { listener?.cancel(); listener = nil }

      private func handle(_ conn: NWConnection) {
          conn.start(queue: .global(qos: .utility))
          conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
              defer { conn.cancel() }
              guard let data, let raw = String(data: data, encoding: .utf8) else { return }
              let parts = raw.components(separatedBy: "\r\n\r\n")
              guard parts.count >= 2 else { return }
              let body = parts[1...].joined(separator: "\r\n\r\n")
              if let jdata = body.data(using: .utf8),
                 let json = try? JSONSerialization.jsonObject(with: jdata) as? [String: Any],
                 let event = json["event"] as? String {
                  DispatchQueue.main.async { self?.onEvent?(event, json) }
              }
              let resp = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
              conn.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in conn.cancel() })
          }
      }
  }
  ```

- [ ] **Step 3: Smoke test**

  Run app. In Terminal:
  ```bash
  curl -s -X POST http://localhost:15799/state \
    -H "Content-Type: application/json" \
    -d '{"event":"UserPromptSubmit","session_id":"test"}'
  ```
  Expected: Bit-Bot switches to Thinking face (scanning dashes).

- [ ] **Step 4: Commit**

  ```bash
  git add PixelPets/Senses/NodeGate.swift PixelPets/Senses/HookServer.swift
  git commit -m "feat: HookServer NWListener on 15799, NodeGate detection"
  ```

---

### Task 6: HookPermissionView + HookRegistrar

**Files:**
- Create: `PixelPets/UI/HookPermissionView.swift`
- Create: `PixelPets/Senses/HookRegistrar.swift`

- [ ] **Step 1: `HookPermissionView.swift`** — first-launch dialog

  ```swift
  import SwiftUI

  struct CLIHookOption: Identifiable {
      let id: AgentSkin
      let configPath: String
      var enabled: Bool = true
      var detected: Bool
  }

  struct HookPermissionView: View {
      @Binding var options: [CLIHookOption]
      let onConfirm: () -> Void
      let onSkip: () -> Void

      var body: some View {
          VStack(alignment: .leading, spacing: 16) {
              Text("启用实时 Hook").font(.headline)
              Text("PixelPets 需要在以下 CLI 配置文件中注册 Hook 脚本，以感知实时状态。\n每个配置文件将自动备份为 *.pixelpets.bak。")
                  .font(.system(size: 12)).foregroundStyle(.secondary)

              ForEach($options) { $opt in
                  if opt.detected {
                      HStack {
                          Toggle("", isOn: $opt.enabled).labelsHidden()
                          VStack(alignment: .leading, spacing: 2) {
                              Text(opt.id.displayName).font(.system(size: 12, weight: .medium))
                              Text(opt.configPath).font(.system(size: 10, design: .monospaced))
                                  .foregroundStyle(.secondary)
                          }
                      }
                  }
              }

              HStack {
                  Button("跳过") { onSkip() }
                  Spacer()
                  Button("注册选中的 Hook") { onConfirm() }.buttonStyle(.borderedProminent)
              }
          }.padding(20).frame(width: 400)
      }
  }
  ```

- [ ] **Step 2: `HookRegistrar.swift`**

  ```swift
  import Foundation

  struct HookRegistration {
      let cli: AgentSkin
      let configPath: String
      var detected: Bool
  }

  final class HookRegistrar {
      private let fm = FileManager.default
      private let home = FileManager.default.homeDirectoryForCurrentUser.path
      private var nodePath: String = "node"

      func setNodePath(_ path: String) { nodePath = path }

      // MARK: - Detection (dry-run, no writes)
      func detectAll() -> [HookRegistration] {
          [
              HookRegistration(cli: .claude,   configPath: "\(home)/.claude/settings.json",
                               detected: fm.fileExists(atPath: "\(home)/.claude/settings.json")),
              HookRegistration(cli: .gemini,   configPath: "\(home)/.gemini/settings.json",
                               detected: fm.fileExists(atPath: "\(home)/.gemini/settings.json")),
              HookRegistration(cli: .codex,    configPath: "\(home)/.codex/hooks.json",
                               detected: fm.fileExists(atPath: "\(home)/.codex") || fm.fileExists(atPath: "\(home)/.codex/hooks.json")),
              HookRegistration(cli: .opencode, configPath: "~/.config/opencode/opencode.json",
                               detected: fm.fileExists(atPath: "\(home)/.config/opencode/opencode.json")),
          ]
      }

      // MARK: - Registration (writes + backup)
      func register(cli: AgentSkin) {
          switch cli {
          case .claude:   registerClaude()
          case .gemini:   registerGemini()
          case .codex:    registerCodex()
          case .opencode: break  // OpenCode plugin registration is manual in MVP
          }
      }

      func unregisterAll() {
          unregister(configPath: "\(home)/.claude/settings.json",   marker: "pixelpets")
          unregister(configPath: "\(home)/.gemini/settings.json",   marker: "pixelpets")
          unregister(configPath: "\(home)/.codex/hooks.json",       marker: "pixelpets")
      }

      // MARK: - Claude
      private func registerClaude() {
          let path = "\(home)/.claude/settings.json"
          guard var json = readJSON(path) else { return }
          backup(path)
          let hookScript = bundledPath("pixelpets-hook")
          var hooks = json["hooks"] as? [[String: Any]] ?? []
          let events = ["UserPromptSubmit","PreToolUse","PostToolUse","PostToolUseFailure",
                        "Stop","StopFailure","SubagentStart","SubagentStop",
                        "PermissionRequest","SessionEnd","PreCompact"]
          for event in events where !hooks.contains(where: {
              ($0["event"] as? String) == event && ($0["command"] as? String)?.contains("pixelpets") == true
          }) {
              hooks.append(["event": event, "command": "\(nodePath) \"\(hookScript)\" \(event)"])
          }
          json["hooks"] = hooks
          writeJSON(json, to: path)
      }

      // MARK: - Gemini
      private func registerGemini() {
          let path = "\(home)/.gemini/settings.json"
          guard var json = readJSON(path) else { return }
          backup(path)
          let hookScript = bundledPath("gemini-hook")
          var hooks = json["hooks"] as? [[String: Any]] ?? []
          let cmd = "\(nodePath) \"\(hookScript)\""
          if !hooks.contains(where: { ($0["command"] as? String)?.contains("pixelpets") == true }) {
              hooks.append(["command": cmd])
          }
          json["hooks"] = hooks
          writeJSON(json, to: path)
      }

      // MARK: - Codex
      private func registerCodex() {
          let path = "\(home)/.codex/hooks.json"
          backup(path)
          var json = readJSON(path) ?? [:]
          let hookScript = bundledPath("codex-hook")
          let events = ["SessionStart","UserPromptSubmit","PreToolUse","PostToolUse","Stop"]
          for event in events {
              var list = json[event] as? [String] ?? []
              let cmd = "\(nodePath) \"\(hookScript)\" \(event)"
              if !list.contains(cmd) { list.append(cmd) }
              json[event] = list
          }
          writeJSON(json, to: path)
      }

      // MARK: - Unregister (remove pixelpets entries)
      private func unregister(configPath: String, marker: String) {
          guard var json = readJSON(configPath) else { return }
          if var hooks = json["hooks"] as? [[String: Any]] {
              hooks.removeAll { ($0["command"] as? String)?.contains(marker) == true }
              json["hooks"] = hooks
              writeJSON(json, to: configPath)
          } else if var allEvents = json as? [String: [String]] {
              for key in allEvents.keys {
                  allEvents[key]?.removeAll { $0.contains(marker) }
              }
              // Re-save
              if let data = try? JSONSerialization.data(withJSONObject: allEvents, options: .prettyPrinted) {
                  fm.createFile(atPath: configPath, contents: data)
              }
          }
      }

      // MARK: - Helpers
      private func backup(_ path: String) {
          guard fm.fileExists(atPath: path) else { return }
          let bak = path + ".pixelpets.bak"
          if !fm.fileExists(atPath: bak) { try? fm.copyItem(atPath: path, toPath: bak) }
      }

      private func bundledPath(_ name: String) -> String {
          Bundle.main.path(forResource: name, ofType: "js") ?? name
      }

      private func readJSON(_ path: String) -> [String: Any]? {
          guard let data = fm.contents(atPath: path) else { return nil }
          return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      }

      private func writeJSON(_ json: [String: Any], to path: String) {
          guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else { return }
          fm.createFile(atPath: path, contents: data)
      }
  }
  ```

- [ ] **Step 3: Add hook scripts to Xcode**

  Create `PixelPets/Resources/hooks/pixelpets-hook.js`:
  ```javascript
  #!/usr/bin/env node
  const http = require("http");
  const event = process.argv[2] || "unknown";
  let body = "";
  process.stdin.on("data", d => { body += d; });
  process.stdin.on("end", () => {
      let p = {}; try { p = JSON.parse(body); } catch {}
      const json = JSON.stringify({ event, session_id: p.session_id || "default",
          tool_name: p.tool_name, cwd: p.cwd });
      const req = http.request({ hostname:"127.0.0.1", port:15799, path:"/state",
          method:"POST", headers:{"Content-Type":"application/json",
          "Content-Length":Buffer.byteLength(json)} }, ()=>{});
      req.on("error", ()=>{}); req.setTimeout(100, ()=>req.destroy());
      req.write(json); req.end();
  });
  ```

  Create `PixelPets/Resources/hooks/gemini-hook.js`:
  ```javascript
  #!/usr/bin/env node
  const http = require("http");
  const MAP = { SessionStart:"SessionStart", SessionEnd:"SessionEnd",
      BeforeAgent:"UserPromptSubmit", BeforeTool:"PreToolUse",
      AfterTool:"PostToolUse", AfterAgent:"Stop", PreCompress:"PreCompact" };
  let body = "";
  process.stdin.on("data", d => { body += d; });
  process.stdin.on("end", () => {
      let p = {}; try { p = JSON.parse(body); } catch {}
      const hookName = p.hook_event_name || "";
      const event = MAP[hookName];
      if (hookName === "BeforeTool") process.stdout.write(JSON.stringify({decision:"allow"})+"\n");
      if (!event) return;
      const json = JSON.stringify({ event, session_id: p.session_id || "default" });
      const req = http.request({ hostname:"127.0.0.1", port:15799, path:"/state",
          method:"POST", headers:{"Content-Type":"application/json",
          "Content-Length":Buffer.byteLength(json)} }, ()=>{});
      req.on("error", ()=>{}); req.setTimeout(100, ()=>req.destroy());
      req.write(json); req.end();
  });
  ```

  Create `PixelPets/Resources/hooks/codex-hook.js`:
  ```javascript
  #!/usr/bin/env node
  const http = require("http");
  const MAP = { SessionStart:"SessionStart", UserPromptSubmit:"UserPromptSubmit",
      PreToolUse:"PreToolUse", PostToolUse:"PostToolUse", Stop:"Stop" };
  let body = "";
  process.stdin.on("data", d => { body += d; });
  process.stdin.on("end", () => {
      let p = {}; try { p = JSON.parse(body); } catch {}
      const event = MAP[process.argv[2]];
      if (!event) return;
      const json = JSON.stringify({ event, session_id: p.session_id||"default", tool_name: p.tool_name });
      const req = http.request({ hostname:"127.0.0.1", port:15799, path:"/state",
          method:"POST", headers:{"Content-Type":"application/json",
          "Content-Length":Buffer.byteLength(json)} }, ()=>{});
      req.on("error", ()=>{}); req.setTimeout(100, ()=>req.destroy());
      req.write(json); req.end();
  });
  ```

  In Xcode: Build Phases → Copy Bundle Resources → add the `hooks/` folder.

- [ ] **Step 4: Commit**

  ```bash
  git add PixelPets/UI/HookPermissionView.swift PixelPets/Senses/HookRegistrar.swift \
          PixelPets/Resources/hooks/
  git commit -m "feat: HookRegistrar with backup+unregister, HookPermissionView dialog, hook scripts"
  ```

---

## Phase 3 — Log Parsers (Fixture-Driven TDD)

### Task 7: Claude Log Parser

**Files:**
- Create: `PixelPets/Senses/ClaudeLogParser.swift`
- Create: `PixelPetsTests/ClaudeLogParserTests.swift`

- [ ] **Step 1: Inspect your fixture, identify the actual JSON structure**

  ```bash
  head -5 PixelPets/Resources/Fixtures/claude_sample.jsonl | python3 -m json.tool | grep -A5 '"usage"'
  ```
  Note the actual field names (should be `input_tokens`, `output_tokens`, `cache_read_input_tokens`).

- [ ] **Step 2: Write tests using the fixture file**

  ```swift
  import XCTest
  @testable import PixelPets

  final class ClaudeLogParserTests: XCTestCase {
      var fixturePath: String { Bundle(for: Self.self).path(forResource: "claude_sample", ofType: "jsonl")! }

      func test_parsesFixture_returnsNonZeroTokens() {
          let batch = ClaudeLogParser().parse(filePath: fixturePath)
          XCTAssertGreaterThan(batch.inputTokens + batch.outputTokens, 0,
              "Fixture must contain at least one usage entry")
      }

      func test_parsesInlineJSONL() throws {
          let jsonl = "{\"type\":\"assistant\",\"message\":{\"usage\":{\"input_tokens\":100,\"output_tokens\":200,\"cache_read_input_tokens\":50}}}\n"
          let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("t.jsonl")
          try jsonl.write(to: tmp, atomically: true, encoding: .utf8)
          let batch = ClaudeLogParser().parse(filePath: tmp.path)
          XCTAssertEqual(batch.inputTokens, 100)
          XCTAssertEqual(batch.outputTokens, 200)
          XCTAssertEqual(batch.cacheReadTokens, 50)
      }

      func test_emptyFile_returnsZero() throws {
          let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("empty.jsonl")
          try "".write(to: tmp, atomically: true, encoding: .utf8)
          let batch = ClaudeLogParser().parse(filePath: tmp.path)
          XCTAssertEqual(batch.totalTokens, 0)
      }

      func test_installedAtFilter_excludesOldEntries() throws {
          // Line with timestamp before installedAt should be excluded
          let future = Date().addingTimeInterval(3600)
          let jsonl = "{\"type\":\"assistant\",\"timestamp\":\"\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200)))\",\"message\":{\"usage\":{\"input_tokens\":999,\"output_tokens\":1}}}\n"
          let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("old.jsonl")
          try jsonl.write(to: tmp, atomically: true, encoding: .utf8)
          let batch = ClaudeLogParser(installedAt: future).parse(filePath: tmp.path)
          XCTAssertEqual(batch.inputTokens, 0, "Entries before installedAt must be excluded")
      }
  }
  ```

- [ ] **Step 3: Run — expect compiler error**

- [ ] **Step 4: `ClaudeLogParser.swift`**

  ```swift
  import Foundation

  struct TokenBatch {
      var inputTokens: Int = 0
      var outputTokens: Int = 0
      var cacheReadTokens: Int = 0
      var cacheWriteTokens: Int = 0
      var totalTokens: Int { inputTokens + outputTokens }
  }

  final class ClaudeLogParser {
      private let basePath: String
      private let installedAt: Date

      init(basePath: String? = nil, installedAt: Date = .distantPast) {
          self.basePath = basePath
              ?? (FileManager.default.homeDirectoryForCurrentUser.path + "/.claude/projects")
          self.installedAt = installedAt
      }

      func parseAll() -> TokenBatch {
          var combined = TokenBatch()
          for path in findJSONLFiles() {
              let b = parse(filePath: path)
              combined.inputTokens += b.inputTokens
              combined.outputTokens += b.outputTokens
              combined.cacheReadTokens += b.cacheReadTokens
              combined.cacheWriteTokens += b.cacheWriteTokens
          }
          return combined
      }

      func parse(filePath: String) -> TokenBatch {
          guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { return TokenBatch() }
          var batch = TokenBatch()
          let isoFmt = ISO8601DateFormatter()
          for line in content.components(separatedBy: "\n") {
              guard !line.isEmpty,
                    let data = line.data(using: .utf8),
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
              // installedAt filter
              if let tsStr = json["timestamp"] as? String,
                 let ts = isoFmt.date(from: tsStr), ts < installedAt { continue }
              guard let message = json["message"] as? [String: Any],
                    let usage = message["usage"] as? [String: Any] else { continue }
              batch.inputTokens += usage["input_tokens"] as? Int ?? 0
              batch.outputTokens += usage["output_tokens"] as? Int ?? 0
              batch.cacheReadTokens += usage["cache_read_input_tokens"] as? Int ?? 0
              batch.cacheWriteTokens += usage["cache_creation_input_tokens"] as? Int ?? 0
          }
          return batch
      }

      private func findJSONLFiles() -> [String] {
          guard let e = FileManager.default.enumerator(atPath: basePath) else { return [] }
          return e.compactMap { $0 as? String }.filter { $0.hasSuffix(".jsonl") }.map { "\(basePath)/\($0)" }
      }
  }
  ```

- [ ] **Step 5: Run — all 4 tests pass**

- [ ] **Step 6: Commit**

  ```bash
  git add PixelPets/Senses/ClaudeLogParser.swift PixelPetsTests/ClaudeLogParserTests.swift
  git commit -m "feat: ClaudeLogParser with installedAt filter + fixture-driven tests"
  ```

---

### Task 8: Gemini + Codex + OpenCode Parsers

**Files:**
- Create: `PixelPets/Senses/GeminiLogParser.swift`
- Create: `PixelPets/Senses/CodexLogParser.swift`
- Create: `PixelPets/Senses/OpenCodeLogParser.swift`
- Create: `PixelPetsTests/GeminiLogParserTests.swift`
- Create: `PixelPetsTests/CodexLogParserTests.swift`
- Create: `PixelPetsTests/OpenCodeLogParserTests.swift`

- [ ] **Step 1: Inspect Gemini fixture format**

  ```bash
  python3 -c "
  import json
  d = json.load(open('PixelPets/Resources/Fixtures/gemini_sample.json'))
  print('Top keys:', list(d.keys()))
  msgs = d.get('messages', d.get('history', []))
  if msgs:
      print('First message keys:', list(msgs[0].keys()))
      if 'usageMetadata' in msgs[0]: print('usageMetadata:', msgs[0]['usageMetadata'])
  "
  ```
  Adjust parser field names if they differ from `usageMetadata`.

- [ ] **Step 2: `GeminiLogParser.swift`**

  ```swift
  import Foundation

  final class GeminiLogParser {
      private let basePath: String
      private let installedAt: Date

      init(basePath: String? = nil, installedAt: Date = .distantPast) {
          self.basePath = basePath ?? (FileManager.default.homeDirectoryForCurrentUser.path + "/.gemini/tmp")
          self.installedAt = installedAt
      }

      func parseAll() -> TokenBatch {
          var combined = TokenBatch()
          for path in findFiles() {
              let b = parse(filePath: path)
              combined.inputTokens += b.inputTokens; combined.outputTokens += b.outputTokens
          }
          return combined
      }

      func parse(filePath: String) -> TokenBatch {
          guard let data = FileManager.default.contents(atPath: filePath),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return TokenBatch() }
          // Support both "messages" and "history" keys based on fixture inspection
          let messages = (json["messages"] ?? json["history"]) as? [[String: Any]] ?? []
          var batch = TokenBatch()
          for msg in messages {
              guard let usage = msg["usageMetadata"] as? [String: Any] else { continue }
              let prompt = usage["promptTokenCount"] as? Int ?? 0
              let total  = usage["totalTokenCount"] as? Int ?? 0
              batch.inputTokens += prompt
              batch.outputTokens += max(0, total - prompt)
          }
          return batch
      }

      private func findFiles() -> [String] {
          guard let e = FileManager.default.enumerator(atPath: basePath) else { return [] }
          return e.compactMap { $0 as? String }.filter { $0.hasSuffix(".json") && $0.contains("chat") }
              .map { "\(basePath)/\($0)" }
      }
  }
  ```

- [ ] **Step 3: Gemini test using fixture**

  ```swift
  final class GeminiLogParserTests: XCTestCase {
      var fixturePath: String { Bundle(for: Self.self).path(forResource: "gemini_sample", ofType: "json")! }

      func test_parsesFixture_nonZero() {
          let batch = GeminiLogParser().parse(filePath: fixturePath)
          XCTAssertGreaterThan(batch.inputTokens + batch.outputTokens, 0)
      }

      func test_inlineJSON() throws {
          let json = "{\"messages\":[{\"role\":\"model\",\"usageMetadata\":{\"promptTokenCount\":80,\"totalTokenCount\":200}}]}"
          let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("g.json")
          try json.write(to: tmp, atomically: true, encoding: .utf8)
          let batch = GeminiLogParser().parse(filePath: tmp.path)
          XCTAssertEqual(batch.inputTokens, 80)
          XCTAssertEqual(batch.outputTokens, 120)
      }
  }
  ```

- [ ] **Step 4: `CodexLogParser.swift`**

  ```swift
  import Foundation

  final class CodexLogParser {
      private let basePath: String
      private let installedAt: Date

      init(basePath: String? = nil, installedAt: Date = .distantPast) {
          let env = ProcessInfo.processInfo.environment["CODEX_HOME"]
          self.basePath = basePath ?? env
              ?? (FileManager.default.homeDirectoryForCurrentUser.path + "/.codex/sessions")
          self.installedAt = installedAt
      }

      func parseAll() -> TokenBatch {
          var combined = TokenBatch()
          for path in findJSONLFiles() {
              let b = parse(filePath: path)
              combined.inputTokens += b.inputTokens; combined.outputTokens += b.outputTokens
          }
          return combined
      }

      func parse(filePath: String) -> TokenBatch {
          guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { return TokenBatch() }
          var batch = TokenBatch()
          for line in content.components(separatedBy: "\n") {
              guard !line.isEmpty,
                    let data = line.data(using: .utf8),
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    (json["type"] as? String) == "response_item",
                    let response = json["response"] as? [String: Any],
                    let usage = response["usage"] as? [String: Any] else { continue }
              batch.inputTokens += usage["input_tokens"] as? Int ?? 0
              batch.outputTokens += usage["output_tokens"] as? Int ?? 0
          }
          return batch
      }

      private func findJSONLFiles() -> [String] {
          guard let e = FileManager.default.enumerator(atPath: basePath) else { return [] }
          return e.compactMap { $0 as? String }.filter { $0.hasSuffix(".jsonl") }.map { "\(basePath)/\($0)" }
      }
  }
  ```

- [ ] **Step 5: `OpenCodeLogParser.swift`**

  > Before writing this parser, verify the actual DB schema from Task 0 Step 8. If the table name or JSON field differs from what's shown below, adjust accordingly.

  ```swift
  import Foundation
  import SQLite3

  final class OpenCodeLogParser {
      private let dbPath: String
      private let installedAt: Date

      init(dbPath: String? = nil, installedAt: Date = .distantPast) {
          let xdg = ProcessInfo.processInfo.environment["XDG_DATA_HOME"]
              ?? (FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Application Support")
          self.dbPath = dbPath ?? "\(xdg)/opencode/opencode.db"
          self.installedAt = installedAt
      }

      func parseAll() -> TokenBatch {
          var batch = TokenBatch()
          guard FileManager.default.fileExists(atPath: dbPath) else { return batch }
          var db: OpaquePointer?
          guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return batch }
          defer { sqlite3_close(db) }

          // Query parts that look like step-finish (contain "tokens" key in data JSON)
          let sql = "SELECT data, time_created FROM part WHERE data LIKE '%\"tokens\"%'"
          var stmt: OpaquePointer?
          guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return batch }
          defer { sqlite3_finalize(stmt) }

          let installedMs = Int64(installedAt.timeIntervalSince1970 * 1000)
          while sqlite3_step(stmt) == SQLITE_ROW {
              let timeCreated = sqlite3_column_int64(stmt, 1)
              guard timeCreated >= installedMs else { continue }
              guard let raw = sqlite3_column_text(stmt, 0),
                    let data = String(cString: raw).data(using: .utf8),
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let tokens = json["tokens"] as? [String: Any] else { continue }
              batch.inputTokens += tokens["input"] as? Int ?? 0
              batch.outputTokens += tokens["output"] as? Int ?? 0
              if let cache = tokens["cache"] as? [String: Any] {
                  batch.cacheReadTokens += cache["read"] as? Int ?? 0
                  batch.cacheWriteTokens += cache["write"] as? Int ?? 0
              }
          }
          return batch
      }
  }
  ```

- [ ] **Step 6: OpenCode test using fixture JSON sample**

  ```swift
  final class OpenCodeLogParserTests: XCTestCase {
      func test_parsesSampleJSON_nonZero() throws {
          // Use the sample JSON collected in Task 0
          let fixturePath = Bundle(for: Self.self).path(forResource: "opencode_sample", ofType: "json")!
          let data = try Data(contentsOf: URL(fileURLWithPath: fixturePath))
          let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
          let tokens = json["tokens"] as? [String: Any]
          XCTAssertNotNil(tokens, "opencode_sample.json must contain a 'tokens' key")
          let input = tokens?["input"] as? Int ?? 0
          let output = tokens?["output"] as? Int ?? 0
          XCTAssertGreaterThan(input + output, 0)
      }
  }
  ```

- [ ] **Step 7: Run all parser tests — expect all pass**

- [ ] **Step 8: Commit**

  ```bash
  git add PixelPets/Senses/GeminiLogParser.swift PixelPets/Senses/CodexLogParser.swift \
          PixelPets/Senses/OpenCodeLogParser.swift \
          PixelPetsTests/GeminiLogParserTests.swift PixelPetsTests/CodexLogParserTests.swift \
          PixelPetsTests/OpenCodeLogParserTests.swift
  git commit -m "feat: Gemini/Codex/OpenCode log parsers with fixture-driven tests and installedAt filter"
  ```

---

### Task 9: GrowthEngine + GrowthStore

**Files:**
- Create: `PixelPets/Core/GrowthEngine.swift`
- Create: `PixelPets/Persistence/GrowthStore.swift`
- Create: `PixelPetsTests/GrowthEngineTests.swift`

- [ ] **Step 1: Write failing GrowthEngine tests**

  ```swift
  final class GrowthEngineTests: XCTestCase {
      let e = GrowthEngine()

      func test_below500k_noAccessories_level1() {
          let (lvl, acc) = e.compute(totalTokens: 100_000)
          XCTAssertEqual(lvl, 1); XCTAssertTrue(acc.isEmpty)
      }
      func test_at500k_sprout() {
          let (_, acc) = e.compute(totalTokens: 500_000)
          XCTAssertTrue(acc.contains(.sprout))
      }
      func test_at1M_level2() {
          XCTAssertEqual(e.compute(totalTokens: 1_000_000).level, 2)
      }
      func test_at2M_battery() {
          XCTAssertTrue(e.compute(totalTokens: 2_000_000).accessories.contains(.battery))
      }
      func test_milestones_400k_to_600k() {
          XCTAssertEqual(e.newMilestones(from: 400_000, to: 600_000), [.sprout])
      }
      func test_milestones_none_within_range() {
          XCTAssertTrue(e.newMilestones(from: 600_000, to: 900_000).isEmpty)
      }
  }
  ```

- [ ] **Step 2: `GrowthEngine.swift`**

  ```swift
  final class GrowthEngine {
      private let levelThresholds = [(1_000_000, 2), (5_000_000, 3), (20_000_000, 4)]
      private let accessoryThresholds: [(Int, Accessory)] = [
          (500_000, .sprout), (2_000_000, .battery), (3_000_000, .headset),
          (5_000_000, .minidrone), (8_000_000, .jetpack), (10_000_000, .halo),
          (12_000_000, .codecloud), (15_000_000, .cape), (20_000_000, .antenna)
      ]

      func compute(totalTokens: Int) -> (level: Int, accessories: [Accessory]) {
          let level = levelThresholds.last { totalTokens >= $0.0 }?.1 ?? 1
          return (level, accessoryThresholds.filter { totalTokens >= $0.0 }.map { $0.1 })
      }

      func newMilestones(from: Int, to: Int) -> [Accessory] {
          accessoryThresholds.filter { $0.0 > from && $0.0 <= to }.map { $0.1 }
      }
  }
  ```

- [ ] **Step 3: Run — all 6 tests pass**

- [ ] **Step 4: `GrowthStore.swift`**

  ```swift
  import Foundation
  import SQLite3

  final class GrowthStore {
      private let dbPath: String
      private var db: OpaquePointer?

      init() {
          let dir = FileManager.default.homeDirectoryForCurrentUser.path + "/.pixelpets"
          try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
          dbPath = dir + "/pixelpets.db"
          sqlite3_open(dbPath, &db)
          sqlite3_exec(db, """
          CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT NOT NULL DEFAULT '');
          CREATE TABLE IF NOT EXISTS log_cursor (path TEXT PRIMARY KEY, mtime REAL NOT NULL DEFAULT 0);
          """, nil, nil, nil)
      }

      deinit { sqlite3_close(db) }

      // MARK: - KV helpers
      private func set(_ key: String, _ value: String) {
          var s: OpaquePointer?
          sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO kv(key,value) VALUES(?,?);", -1, &s, nil)
          sqlite3_bind_text(s, 1, key, -1, nil); sqlite3_bind_text(s, 2, value, -1, nil)
          sqlite3_step(s); sqlite3_finalize(s)
      }

      private func get(_ key: String) -> String? {
          var s: OpaquePointer?
          sqlite3_prepare_v2(db, "SELECT value FROM kv WHERE key=?;", -1, &s, nil)
          sqlite3_bind_text(s, 1, key, -1, nil)
          defer { sqlite3_finalize(s) }
          guard sqlite3_step(s) == SQLITE_ROW, let t = sqlite3_column_text(s, 0) else { return nil }
          return String(cString: t)
      }

      // MARK: - Public API
      func saveTotalTokens(_ n: Int) { set("total_tokens", "\(n)") }
      func loadTotalTokens() -> Int  { Int(get("total_tokens") ?? "0") ?? 0 }

      func saveInstalledAt(_ date: Date) { set("installed_at", "\(date.timeIntervalSince1970)") }
      func loadInstalledAt() -> Date? {
          guard let s = get("installed_at"), let ts = Double(s) else { return nil }
          return Date(timeIntervalSince1970: ts)
      }

      func saveUnlockedAccessories(_ accessories: [Accessory]) {
          set("accessories", accessories.map(\.rawValue).joined(separator: ","))
      }
      func loadUnlockedAccessories() -> [Accessory] {
          (get("accessories") ?? "").components(separatedBy: ",")
              .compactMap { Accessory(rawValue: $0) }
      }

      // MARK: - File cursor (for incremental log parsing)
      func saveCursor(path: String, mtime: Double) {
          var s: OpaquePointer?
          sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO log_cursor(path,mtime) VALUES(?,?);", -1, &s, nil)
          sqlite3_bind_text(s, 1, path, -1, nil); sqlite3_bind_double(s, 2, mtime)
          sqlite3_step(s); sqlite3_finalize(s)
      }

      func loadCursor(path: String) -> Double {
          var s: OpaquePointer?
          sqlite3_prepare_v2(db, "SELECT mtime FROM log_cursor WHERE path=?;", -1, &s, nil)
          sqlite3_bind_text(s, 1, path, -1, nil)
          defer { sqlite3_finalize(s) }
          guard sqlite3_step(s) == SQLITE_ROW else { return 0 }
          return sqlite3_column_double(s, 0)
      }
  }
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add PixelPets/Core/GrowthEngine.swift PixelPets/Persistence/GrowthStore.swift \
          PixelPetsTests/GrowthEngineTests.swift
  git commit -m "feat: GrowthEngine + GrowthStore (mtime cursor, installedAt, kv persistence)"
  ```

---

## Phase 4 — Quota Clients + QuotaMonitor

### Task 10: ClaudeQuotaClient

**Files:**
- Create: `PixelPets/Senses/ClaudeQuotaClient.swift`

- [ ] **Step 1: Credential reader**

  ```swift
  import Foundation
  import Security

  private func readClaudeToken() -> String? {
      // Keychain first
      let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
          kSecAttrService as String: "Claude Code-credentials",
          kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
      var result: AnyObject?
      if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
         let data = result as? Data { return extractToken(from: data) }
      // File fallback
      let path = FileManager.default.homeDirectoryForCurrentUser
          .appendingPathComponent(".claude/.credentials.json").path
      guard let data = FileManager.default.contents(atPath: path) else { return nil }
      return extractToken(from: data)
  }

  private func extractToken(from data: Data) -> String? {
      guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
      let entry = (json["claudeAiOauth"] ?? json["claude.ai_oauth"]) as? [String: Any]
      return entry?["accessToken"] as? String
  }
  ```

- [ ] **Step 2: `ClaudeQuotaClient.swift`**

  ```swift
  import Foundation

  final class ClaudeQuotaClient {
      func fetch() async -> QuotaFetchResult {
          guard let token = readClaudeToken() else {
              return .unavailable("未找到 Claude Code 凭据")
          }
          guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
              return .unavailable("无效 URL")
          }
          var req = URLRequest(url: url)
          req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
          req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
          req.setValue("application/json", forHTTPHeaderField: "Accept")
          req.timeoutInterval = 10

          guard let (data, resp) = try? await URLSession.shared.data(for: req),
                (resp as? HTTPURLResponse)?.statusCode == 200,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
              return .unavailable("配额 API 请求失败")
          }

          let knownKeys = ["five_hour", "seven_day", "seven_day_opus", "seven_day_sonnet"]
          let tiers: [QuotaTier] = knownKeys.compactMap { key in
              guard let window = json[key] as? [String: Any],
                    let util = window["utilization"] as? Double else { return nil }
              let resetsAt = (window["resets_at"] as? String).flatMap {
                  ISO8601DateFormatter().date(from: $0)
              }
              return QuotaTier(id: key, utilization: util, resetsAt: resetsAt, isEstimated: false)
          }
          return tiers.isEmpty ? .unavailable("响应中无配额数据") : .success(tiers)
      }
  }
  ```

- [ ] **Step 3: Smoke test — run the curl from Task 0 Step 10 and confirm the fields match**

- [ ] **Step 4: Commit**

  ```bash
  git add PixelPets/Senses/ClaudeQuotaClient.swift
  git commit -m "feat: ClaudeQuotaClient — Keychain/file creds, graceful QuotaFetchResult degradation"
  ```

---

### Task 11: CodexQuotaClient + QuotaMonitor

**Files:**
- Create: `PixelPets/Senses/CodexQuotaClient.swift`
- Create: `PixelPets/Core/QuotaMonitor.swift`
- Create: `PixelPetsTests/QuotaMonitorTests.swift`

- [ ] **Step 1: `CodexQuotaClient.swift`**

  ```swift
  import Foundation

  final class CodexQuotaClient {
      func fetch() async -> QuotaFetchResult {
          guard let creds = readCodexCreds() else { return .unavailable("未找到 Codex 凭据") }
          guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else {
              return .unavailable("无效 URL")
          }
          var req = URLRequest(url: url)
          req.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
          req.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
          if let aid = creds.accountId { req.setValue(aid, forHTTPHeaderField: "ChatGPT-Account-Id") }
          req.timeoutInterval = 10

          guard let (data, resp) = try? await URLSession.shared.data(for: req),
                (resp as? HTTPURLResponse)?.statusCode == 200,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let rl = json["rate_limit"] as? [String: Any] else {
              return .unavailable("Codex 配额 API 请求失败")
          }
          var tiers: [QuotaTier] = []
          for key in ["primary_window", "secondary_window"] {
              guard let w = rl[key] as? [String: Any], let pct = w["used_percent"] as? Double else { continue }
              let secs = w["limit_window_seconds"] as? Int ?? 18000
              let resetsAt = (w["reset_at"] as? Int).map { Date(timeIntervalSince1970: TimeInterval($0)) }
              tiers.append(QuotaTier(id: secs >= 604800 ? "seven_day" : "five_hour",
                                     utilization: pct/100, resetsAt: resetsAt, isEstimated: false))
          }
          return tiers.isEmpty ? .unavailable("无配额窗口数据") : .success(tiers)
      }

      private func readCodexCreds() -> (token: String, accountId: String?)? {
          let path = FileManager.default.homeDirectoryForCurrentUser
              .appendingPathComponent(".codex/auth.json").path
          guard let data = FileManager.default.contents(atPath: path),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                (json["auth_mode"] as? String) == "chatgpt",
                let tokens = json["tokens"] as? [String: Any],
                let token = tokens["access_token"] as? String else { return nil }
          return (token, tokens["account_id"] as? String)
      }
  }
  ```

- [ ] **Step 2: Write QuotaMonitor tests**

  ```swift
  final class QuotaMonitorTests: XCTestCase {
      let m = QuotaMonitor()

      func test_exhausted_sleeping() {
          let t = QuotaTier(id: "five_hour", utilization: 0.97,
                            resetsAt: Date().addingTimeInterval(60), isEstimated: false)
          XCTAssertEqual(m.recommend(tiers: [t], lastRequest: Date()), .sleeping)
      }
      func test_recentRequest_idle() {
          let t = QuotaTier(id: "five_hour", utilization: 0.3,
                            resetsAt: Date().addingTimeInterval(3600), isEstimated: false)
          XCTAssertEqual(m.recommend(tiers: [t], lastRequest: Date().addingTimeInterval(-60)), .idle)
      }
      func test_longIdle_sleeping() {
          let t = QuotaTier(id: "five_hour", utilization: 0.3,
                            resetsAt: Date().addingTimeInterval(3600), isEstimated: false)
          XCTAssertEqual(m.recommend(tiers: [t], lastRequest: Date().addingTimeInterval(-3600)), .sleeping)
      }
      func test_noRequestEver_sleeping() {
          XCTAssertEqual(m.recommend(tiers: [], lastRequest: nil), .sleeping)
      }
  }
  ```

- [ ] **Step 3: `QuotaMonitor.swift`**

  ```swift
  import Foundation

  final class QuotaMonitor {
      private let idleThreshold: TimeInterval = 30 * 60
      private let exhaustionThreshold: Double = 0.95

      func recommend(tiers: [QuotaTier], lastRequest: Date?) -> PetState {
          if tiers.contains(where: { $0.utilization >= exhaustionThreshold }) { return .sleeping }
          guard let last = lastRequest else { return .sleeping }
          return Date().timeIntervalSince(last) >= idleThreshold ? .sleeping : .idle
      }
  }
  ```

- [ ] **Step 4: Run — all 4 tests pass**

- [ ] **Step 5: Commit**

  ```bash
  git add PixelPets/Senses/CodexQuotaClient.swift PixelPets/Core/QuotaMonitor.swift \
          PixelPetsTests/QuotaMonitorTests.swift
  git commit -m "feat: CodexQuotaClient, QuotaMonitor with idle/exhaustion sleep logic"
  ```

---

## Phase 5 — LogPoller + Full Integration

### Task 12: LogPoller (mtime cursor, installedAt filter)

**Files:**
- Create: `PixelPets/Senses/LogPoller.swift`

- [ ] **Step 1: `LogPoller.swift`**

  ```swift
  import Foundation

  final class LogPoller {
      var onUpdate: ((TokenBatch) -> Void)?
      private var timer: Timer?
      private let store: GrowthStore
      private let installedAt: Date
      private var parsers: [() -> TokenBatch] = []

      init(store: GrowthStore, installedAt: Date) {
          self.store = store
          self.installedAt = installedAt
          let claude   = ClaudeLogParser(installedAt: installedAt)
          let gemini   = GeminiLogParser(installedAt: installedAt)
          let codex    = CodexLogParser(installedAt: installedAt)
          let opencode = OpenCodeLogParser(installedAt: installedAt)
          parsers = [
              { claude.parseAll() },
              { gemini.parseAll() },
              { codex.parseAll() },
              { opencode.parseAll() }
          ]
      }

      func start() {
          poll()
          timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
              self?.poll()
          }
      }

      func stop() { timer?.invalidate() }

      private func poll() {
          DispatchQueue.global(qos: .utility).async { [weak self] in
              guard let self else { return }
              var combined = TokenBatch()
              for parse in self.parsers {
                  let b = parse()
                  combined.inputTokens += b.inputTokens
                  combined.outputTokens += b.outputTokens
                  combined.cacheReadTokens += b.cacheReadTokens
              }
              DispatchQueue.main.async { self.onUpdate?(combined) }
          }
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add PixelPets/Senses/LogPoller.swift
  git commit -m "feat: LogPoller — 30s polling, installedAt filter, aggregates all 4 CLIs"
  ```

---

### Task 13: AppCoordinator Full Integration

**Files:**
- Create: `PixelPets/App/AppCoordinator.swift` (full version)
- Create: `PixelPets/Persistence/SettingsStore.swift`

- [ ] **Step 1: `SettingsStore.swift`**

  ```swift
  import Foundation

  struct AppSettings: Codable {
      var hookPermissionAsked: Bool = false
      var enabledCLIs: [String: Bool] = [:]
      var hookPort: UInt16 = 15799
  }

  final class SettingsStore {
      private let path: String
      private(set) var settings: AppSettings

      init() {
          let dir = FileManager.default.homeDirectoryForCurrentUser.path + "/.pixelpets"
          try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
          path = dir + "/settings.json"
          if let data = FileManager.default.contents(atPath: path),
             let s = try? JSONDecoder().decode(AppSettings.self, from: data) {
              settings = s
          } else {
              settings = AppSettings()
          }
      }

      func save() {
          guard let data = try? JSONEncoder().encode(settings) else { return }
          FileManager.default.createFile(atPath: path, contents: data)
      }
  }
  ```

- [ ] **Step 2: `AppCoordinator.swift`** — full orchestration

  ```swift
  import AppKit
  import SwiftUI

  @MainActor
  final class AppCoordinator: NSObject {
      private var statusItem: NSStatusItem!
      private var popover: NSPopover!
      private var permissionWindow: NSWindow?

      let viewModel = PetViewModel()
      private let stateMachine  = PetStateMachine()
      private let growthEngine  = GrowthEngine()
      private let quotaMonitor  = QuotaMonitor()
      private let growthStore   = GrowthStore()
      private let settingsStore = SettingsStore()
      private let hookServer    = HookServer()
      private let registrar     = HookRegistrar()
      private let claudeQuota   = ClaudeQuotaClient()
      private let codexQuota    = CodexQuotaClient()

      private var logPoller: LogPoller!
      private var lastRequestDate: Date?

      func start() {
          setupInstalledAt()
          setupStatusItem()
          setupPopover()
          hookServer.onEvent = { [weak self] event, payload in self?.handleHookEvent(event, payload) }
          hookServer.start()
          Task { await fetchAllQuota() }
          Timer.scheduledTimer(withTimeInterval: 5*60, repeats: true) { [weak self] _ in
              Task { await self?.fetchAllQuota() }
          }
          let installedAt = growthStore.loadInstalledAt() ?? Date()
          logPoller = LogPoller(store: growthStore, installedAt: installedAt)
          logPoller.onUpdate = { [weak self] batch in self?.handleTokenUpdate(batch) }
          logPoller.start()
          restoreGrowthProgress()
          checkNodeAndHooks()
      }

      // MARK: - InstalledAt
      private func setupInstalledAt() {
          if growthStore.loadInstalledAt() == nil {
              growthStore.saveInstalledAt(Date())
          }
      }

      // MARK: - Status Item
      private func setupStatusItem() {
          statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
          let icon = NSHostingView(rootView:
              AnimationClock(fps: 30) { [weak self] frame -> BitBotRenderer? in
                  guard let self else { return nil }
                  return BitBotRenderer(viewModel: self.viewModel, size: 16, frame: frame)
              }
          )
          icon.frame = NSRect(x: 0, y: 0, width: 16, height: 16)
          statusItem.button?.addSubview(icon)
          statusItem.button?.action = #selector(togglePopover)
          statusItem.button?.target = self
      }

      // MARK: - Popover
      private func setupPopover() {
          popover = NSPopover()
          popover.contentSize = NSSize(width: 360, height: 520)
          popover.behavior = .transient
          popover.contentViewController = NSHostingController(rootView: PopoverView(viewModel: viewModel))
      }

      // MARK: - Hook Events
      private func handleHookEvent(_ event: String, _ payload: [String: Any]) {
          stateMachine.handle(event, payload)
          viewModel.state = stateMachine.currentState
          lastRequestDate = Date()
          // Detect active skin from cwd or session
          if let cwd = payload["cwd"] as? String { updateActiveSkin(from: cwd) }
      }

      private func updateActiveSkin(from cwd: String) {
          // Heuristic: check which CLI config dir is closest to cwd
          // For MVP: skin switches when hook event comes from that CLI's hook script
          // Improvement: pass agent_id from hook script
      }

      // MARK: - Token / Growth
      private func handleTokenUpdate(_ batch: TokenBatch) {
          let prev = viewModel.totalLifetimeTokens
          let newTotal = growthStore.loadTotalTokens() + batch.totalTokens
          guard newTotal > prev else { return }
          let milestones = growthEngine.newMilestones(from: prev, to: newTotal)
          let (level, accessories) = growthEngine.compute(totalTokens: newTotal)
          viewModel.totalLifetimeTokens = newTotal
          viewModel.level = level
          viewModel.accessories = accessories
          growthStore.saveTotalTokens(newTotal)
          growthStore.saveUnlockedAccessories(accessories)
          if !milestones.isEmpty {
              stateMachine.forceEvolve()
              viewModel.state = .evolving
              DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                  guard let self else { return }
                  self.viewModel.state = self.stateMachine.currentState
              }
          }
      }

      private func restoreGrowthProgress() {
          let tokens = growthStore.loadTotalTokens()
          let (level, accessories) = growthEngine.compute(totalTokens: tokens)
          viewModel.totalLifetimeTokens = tokens
          viewModel.level = level
          viewModel.accessories = accessories
      }

      // MARK: - Quota
      private func fetchAllQuota() async {
          async let c = claudeQuota.fetch()
          async let x = codexQuota.fetch()
          let (claudeResult, codexResult) = await (c, x)

          updateCliQuota(skin: .claude,   result: claudeResult, badge: "Pro")
          updateCliQuota(skin: .codex,    result: codexResult,  badge: "Plus")
          updateCliQuota(skin: .gemini,   result: .unavailable("~"), badge: "Free")
          updateCliQuota(skin: .opencode, result: .unavailable("~"), badge: "Go")

          // Quota-driven sleep/wake (only if not in active hook state)
          let allTiers = viewModel.cliInfos.flatMap { $0.tiers }
          let recommendation = quotaMonitor.recommend(tiers: allTiers, lastRequest: lastRequestDate)
          stateMachine.applyQuotaRecommendation(recommendation)
          if viewModel.state == .idle || viewModel.state == .sleeping {
              viewModel.state = stateMachine.currentState
          }
      }

      private func updateCliQuota(skin: AgentSkin, result: QuotaFetchResult, badge: String) {
          if let idx = viewModel.cliInfos.firstIndex(where: { $0.id == skin }) {
              viewModel.cliInfos[idx].fetchResult = result
              viewModel.cliInfos[idx].planBadge = badge
              viewModel.cliInfos[idx].isDetected = true
          } else {
              viewModel.cliInfos.append(CliQuotaInfo(
                  id: skin, fetchResult: result,
                  todayTokens: 0, weekTokens: 0, planBadge: badge,
                  isDetected: result != .unavailable("未检测到")
              ))
          }
      }

      // MARK: - Node + Hooks
      private func checkNodeAndHooks() {
          switch NodeGate.detect() {
          case .available(let path):
              registrar.setNodePath(path)
              viewModel.hooksAvailable = true
              if !settingsStore.settings.hookPermissionAsked {
                  showHookPermissionDialog()
              }
          case .unavailable:
              viewModel.hooksAvailable = false
          }
      }

      private func showHookPermissionDialog() {
          let detections = registrar.detectAll()
          var options = detections.map { r in
              CLIHookOption(id: r.cli, configPath: r.configPath, enabled: true, detected: r.detected)
          }.filter { $0.detected }
          guard !options.isEmpty else { return }

          let view = HookPermissionView(
              options: .init(get: { options }, set: { options = $0 }),
              onConfirm: { [weak self] in
                  guard let self else { return }
                  for opt in options where opt.enabled { self.registrar.register(cli: opt.id) }
                  self.settingsStore.settings.hookPermissionAsked = true
                  self.settingsStore.save()
                  self.permissionWindow?.close()
              },
              onSkip: { [weak self] in
                  self?.settingsStore.settings.hookPermissionAsked = true
                  self?.settingsStore.save()
                  self?.permissionWindow?.close()
              }
          )
          let window = NSWindow(
              contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
              styleMask: [.titled, .closable], backing: .buffered, defer: false)
          window.contentViewController = NSHostingController(rootView: view)
          window.center(); window.makeKeyAndOrderFront(nil)
          permissionWindow = window
      }

      @objc private func togglePopover() {
          guard let button = statusItem.button else { return }
          if popover.isShown { popover.performClose(nil) }
          else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
      }
  }
  ```

- [ ] **Step 3: Fix `AnimationClock` for optional content**

  Update `AnimationClock` to handle optional View:

  ```swift
  struct AnimationClock<Content: View>: View {
      let fps: Double
      @ViewBuilder let content: (Int) -> Content
      @State private var frame = 0

      var body: some View {
          TimelineView(.periodic(from: .now, by: 1.0/fps)) { ctx in
              content(frame).onChange(of: ctx.date) { _, _ in frame += 1 }
          }
      }
  }
  ```

- [ ] **Step 4: Full integration smoke test**

  Run app. Expected:
  - Bit-Bot appears in menu bar (orange, idle blinking)
  - If Node found and CLIs detected: permission dialog appears
  - Click icon: popover shows real Claude quota data (or "未连接" if creds missing)
  - In Terminal, run `claude` and send a prompt → Bit-Bot switches to Thinking

- [ ] **Step 5: Commit**

  ```bash
  git add PixelPets/App/AppCoordinator.swift PixelPets/Persistence/SettingsStore.swift
  git commit -m "feat: full integration — hook server, log poller, quota clients, growth engine, permission dialog"
  ```

---

## Phase 6 — Verification Checklist (Executable)

### Task 14: Acceptance Tests

- [ ] **T1: Build passes**

  ```bash
  xcodebuild -scheme PixelPets -destination "platform=macOS" build | tail -5
  ```
  Expected last line: `** BUILD SUCCEEDED **`

- [ ] **T2: Unit tests pass**

  ```bash
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" test 2>&1 | grep -E "Test Suite|passed|failed"
  ```
  Expected: all suites pass, 0 failures.

- [ ] **T3: Hook server reachable**

  Start app. Then:
  ```bash
  curl -s -w "\n%{http_code}" -X POST http://localhost:15799/state \
    -H "Content-Type: application/json" \
    -d '{"event":"UserPromptSubmit","session_id":"test"}'
  ```
  Expected: HTTP 200.

- [ ] **T4: State changes visible**

  With app running:
  ```bash
  for event in UserPromptSubmit PreToolUse Stop; do
    curl -s -X POST http://localhost:15799/state \
      -H "Content-Type: application/json" \
      -d "{\"event\":\"$event\"}" > /dev/null
    sleep 1
  done
  ```
  Expected: Bit-Bot visibly changes face each second.

- [ ] **T5: Claude fixture parse**

  ```bash
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" \
    -only-testing:PixelPetsTests/ClaudeLogParserTests/test_parsesFixture_returnsNonZeroTokens test 2>&1 \
    | grep -E "passed|failed"
  ```
  Expected: 1 test passed.

- [ ] **T6: Quota card shows real or "未连接"**

  Click menu bar icon. Inspect Claude card. Expected: shows percentage bars OR "未连接 · 无法读取配额". Never shows a fake percentage with no data.

- [ ] **T7: Hook backup created**

  Trigger hook registration (accept dialog). Then:
  ```bash
  ls ~/.claude/settings.json.pixelpets.bak 2>/dev/null && echo "backup exists" || echo "MISSING"
  ```
  Expected: `backup exists`

- [ ] **T8: Node missing degradation**

  Temporarily rename node: `sudo mv $(which node) $(which node).bak`
  Restart app. Expected: pet shows, hooksAvailable banner visible in popover, no crash.
  Restore: `sudo mv $(which node).bak $(which node)`

- [ ] **Final commit**

  ```bash
  git add .
  git commit -m "feat: PixelPets MVP complete — Bit-Bot, 4 CLIs, dual-track, fixture tests, acceptance verified"
  ```
