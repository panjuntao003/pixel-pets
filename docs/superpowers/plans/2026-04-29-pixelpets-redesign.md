# PixelPets 视觉重设计 + 设置功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重设计 PixelPets 的视觉系统（BitBot v2 机器人、4 个等距科幻场景、场景切换）并完善设置功能（独立 SettingsStore、CLI 开关、Settings 窗口）。

**Architecture:** 新增 `HabitatView` 替换 `PetDisplayView`，内含 `AnimationClock` 驱动的场景渲染器和 BitBot v2；`SettingsStore` 从 `AppCoordinator` 提取为独立 `ObservableObject`，JSON 持久化到 `~/.pixelpets/settings.json`；`CliCardView` 采用颜色语义化进度条。所有场景通过 `SceneRegistry` 按 `SceneID` 路由，与 `SettingsStore` 解耦。

**Tech Stack:** Swift 5.9+, SwiftUI Canvas, TimelineView (AnimationClock), XcodeGen, XCTest

---

## 前置决策（执行前必读）

### 工程文件管理
**使用 XcodeGen**。`project.yml` 已配置目录级 sources，新 Swift 文件放入对应目录后执行 `xcodegen generate` 重新生成 `project.pbxproj`，**不手动编辑 pbxproj**。每个任务涉及新文件时，步骤统一写 `xcodegen generate`。

### hookPort 范围（本期）
`AppSettings.hookPort` 字段保留但**本期不生效**。`HookServer` 端口固定 `15799`，hook JS 也固定。Settings 高级 Tab 改为只读展示，文案为"当前 Hook 端口：15799"，不提供编辑入口。完整变更流程（重启 server + 重写 hook 脚本）留后期。

### 场景随机语义
`scenePreference = .random`：**每次打开 Popover**（`HabitatView.onAppear`）随机选一个场景。若用户锁定了某场景，`onAppear` 时直接显示锁定场景。

### PetState 映射（设计态 → 现有 enum）

| 设计态 | 对应 PetState 值 |
|--------|----------------|
| `working` | `.typing`, `.juggling`, `.conducting`, `.searching`, `.fast` |
| `thinking` | `.thinking` |
| `idle` | `.idle` |
| `sleep` | `.sleeping`, `.auth` |
| `celebrating` | `.success`, `.evolving` |
| `error` | `.error` |

BitBotV2FaceProvider 按此映射实现，**不新增 PetState 值，不改 PetStateMachine**。

### UserDefaults → JSON 迁移
`SettingsStore.init` 时检查 `UserDefaults.standard.bool(forKey: "hookPermissionAsked")`，若为 `true`，写入新 JSON 并清除旧 key，避免老用户重新看到权限提示。

### Dirty Worktree 基线
**执行第一步：提交所有现有未提交改动为基线 commit**，再按任务逐步提交。

---

## File Map

### 新建文件

| 文件 | 职责 |
|------|------|
| `PixelPets/Persistence/SettingsStore.swift` | AppSettings + ObservableObject JSON 持久化 |
| `PixelPets/UI/SettingsView.swift` | 三 Tab 设置窗口（通用/场景/高级） |
| `PixelPets/Renderer/HabitatScene.swift` | HabitatScene 协议 + SceneID + SceneRegistry |
| `PixelPets/Renderer/Scenes/SpaceStationScene.swift` | 太空站等距场景 |
| `PixelPets/Renderer/Scenes/CyberpunkLabScene.swift` | 赛博朋克实验室等距场景 |
| `PixelPets/Renderer/Scenes/SciFiQuartersScene.swift` | 星际生活舱等距场景 |
| `PixelPets/Renderer/Scenes/UnderwaterScene.swift` | 像素水族箱场景 |
| `PixelPets/Renderer/BitBotV2Renderer.swift` | 24×28 机器人渲染器 |
| `PixelPets/Renderer/BitBotV2FaceProvider.swift` | 7 种状态表情（大屏） |
| `PixelPets/UI/HabitatView.swift` | 场景容器：AnimationClock + 场景 + 机器人 + 圆点导航 |
| `PixelPets/Renderer/BitBotStatusIconRenderer.swift` | 仅渲染 16×16 头部，用于菜单栏图标 |
| `PixelPetsTests/SettingsStoreTests.swift` | SettingsStore 序列化/过滤测试 |
| `PixelPetsTests/SceneRegistryTests.swift` | SceneRegistry 映射完整性测试 |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `PixelPets/App/AppCoordinator.swift` | 删除内嵌 SettingsStore，引用新独立版；visibleClis 加 enabledCLIs 过滤 |
| `PixelPets/App/PixelPetsApp.swift` | `Settings { SettingsView() }` 替换 `EmptyView()` |
| `PixelPets/Models/PetViewModel.swift` | `visibleClis` 接受 `enabledCLIs` 参数过滤 |
| `PixelPets/Renderer/PixelColor.swift` | AgentPalette 补全 4 皮肤颜色 |
| `PixelPets/Renderer/FaceProvider.swift` | 删除 `BitBotFaceProvider`，保留协议和 `fillPixel` extension |
| `PixelPets/UI/PopoverView.swift` | 替换 `PetDisplayView` 为 `HabitatView`，加 Divider，加空状态 |
| `PixelPets/UI/CliCardView.swift` | 颜色语义化进度条（绿/橙/红阈值） |
| `PixelPets/UI/QuotaBarView.swift` | 使用新颜色逻辑 |
| `PixelPets/UI/PetDisplayView.swift` | 删除此文件（被 HabitatView 取代） |
| `PixelPets/Renderer/BitBotRenderer.swift` | 删除此文件（被 BitBotV2Renderer 取代） |
| `project.yml` → `xcodegen generate` | 每个任务新增文件后执行，自动更新 pbxproj |

---

## Task 0: Dirty Worktree 基线提交

**Files:** 所有现有未提交改动

- [ ] **Step 1: 确认现有改动范围**

  ```bash
  git status --short
  git diff --stat
  ```
  预期包含：ClaudeQuotaClient Gemini 三 tier 拆分、OpenCodeGoQuotaClient、AppCoordinator 改动、测试文件等。
  **确认这些改动都是预期的已完成工作后再继续。**

- [ ] **Step 2: 提交基线**

  ```bash
  git add -A
  git commit -m "chore: baseline — pre-redesign state with Gemini 3-tier + OpenCodeGoQuotaClient"
  ```

- [ ] **Step 3: 确认 worktree 干净**

  ```bash
  git status
  ```
  预期：`nothing to commit, working tree clean`

---

## Task 1: SettingsStore 独立文件

**Files:**
- Create: `PixelPets/Persistence/SettingsStore.swift`
- Create: `PixelPetsTests/SettingsStoreTests.swift`
- Modify: `PixelPets/App/AppCoordinator.swift` (删除末尾内嵌 SettingsStore)

- [ ] **Step 1: 写失败测试**

  创建 `PixelPetsTests/SettingsStoreTests.swift`：

  ```swift
  import XCTest
  @testable import PixelPets

  @MainActor
  final class SettingsStoreTests: XCTestCase {
      private var tempDir: URL!
      private var store: SettingsStore!

      override func setUp() {
          super.setUp()
          tempDir = FileManager.default.temporaryDirectory
              .appendingPathComponent(UUID().uuidString)
          try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
          store = SettingsStore(directory: tempDir.path)
      }

      override func tearDown() {
          try? FileManager.default.removeItem(at: tempDir)
          super.tearDown()
      }

      func test_defaults_enabledCLIs_isEmpty() {
          XCTAssertTrue(store.settings.enabledCLIs.isEmpty)
      }

      func test_defaults_hookPort_is15799() {
          XCTAssertEqual(store.settings.hookPort, 15799)
      }

      func test_defaults_scenePreference_isRandom() {
          XCTAssertEqual(store.settings.scenePreference, .random)
      }

      func test_update_persistsToDisk() {
          store.update { $0.hookPort = 9000 }
          let store2 = SettingsStore(directory: tempDir.path)
          XCTAssertEqual(store2.settings.hookPort, 9000)
      }

      func test_corruptFile_fallsBackToDefaults() {
          let path = tempDir.appendingPathComponent("settings.json").path
          FileManager.default.createFile(atPath: path, contents: Data("CORRUPT".utf8))
          let store2 = SettingsStore(directory: tempDir.path)
          XCTAssertEqual(store2.settings.hookPort, 15799)
      }

      func test_enabledCLIs_emptyMeansAllEnabled() {
          // opt-out 语义：空字典 = 全部启用
          for skin in AgentSkin.allCases {
              XCTAssertTrue(store.settings.isEnabled(skin))
          }
      }

      func test_enabledCLIs_explicitFalseDisables() {
          store.update { $0.enabledCLIs[AgentSkin.codex.rawValue] = false }
          XCTAssertFalse(store.settings.isEnabled(.codex))
          XCTAssertTrue(store.settings.isEnabled(.claude))
      }

      func test_hookPermissionAsked_roundtrips() {
          store.update { $0.hookPermissionAsked = true }
          let store2 = SettingsStore(directory: tempDir.path)
          XCTAssertTrue(store2.settings.hookPermissionAsked)
      }

      func test_migratesUserDefaultsHookPermission() {
          UserDefaults.standard.set(true, forKey: "hookPermissionAsked")
          let migrated = SettingsStore(directory: tempDir.path)
          XCTAssertTrue(migrated.settings.hookPermissionAsked)
          XCTAssertFalse(UserDefaults.standard.bool(forKey: "hookPermissionAsked"),
                         "old UserDefaults key should be cleared after migration")
      }
  }
  ```

- [ ] **Step 2: 运行测试确认失败**

  ```bash
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" \
    -only-testing:PixelPetsTests/SettingsStoreTests test 2>&1 | grep -E "error:|BUILD"
  ```
  预期：编译错误（SettingsStore 还不存在）。

- [ ] **Step 3: 创建 `PixelPets/Persistence/SettingsStore.swift`**

  ```swift
  import Foundation
  import Combine

  struct AppSettings: Codable {
      var hookPermissionAsked: Bool = false
      // opt-out: 空字典 = 全部启用；显式 false = 禁用
      var enabledCLIs: [String: Bool] = [:]
      var hookPort: UInt16 = 15799
      var scenePreference: ScenePreference = .random

      func isEnabled(_ skin: AgentSkin) -> Bool {
          enabledCLIs[skin.rawValue] != false
      }
  }

  enum ScenePreference: String, Codable, CaseIterable {
      case random
      case spaceStation  = "space_station"
      case cyberpunkLab  = "cyberpunk_lab"
      case sciFiQuarters = "scifi_quarters"
      case underwater    = "underwater"

      var displayName: String {
          switch self {
          case .random:       return "随机"
          case .spaceStation: return "太空站"
          case .cyberpunkLab: return "赛博朋克实验室"
          case .sciFiQuarters: return "星际生活舱"
          case .underwater:   return "像素水族箱"
          }
      }
  }

  @MainActor
  final class SettingsStore: ObservableObject {
      @Published private(set) var settings: AppSettings

      private let path: String

      /// 生产环境使用默认目录 ~/.pixelpets/
      convenience init() {
          let dir = FileManager.default.homeDirectoryForCurrentUser
              .appendingPathComponent(".pixelpets").path
          self.init(directory: dir)
      }

      /// 测试时传入临时目录
      init(directory: String) {
          try? FileManager.default.createDirectory(
              atPath: directory, withIntermediateDirectories: true)
          self.path = (directory as NSString).appendingPathComponent("settings.json")
          var loaded: AppSettings
          if let data = FileManager.default.contents(atPath: path),
             let s = try? JSONDecoder().decode(AppSettings.self, from: data) {
              loaded = s
          } else {
              loaded = AppSettings()
          }
          // 迁移旧 UserDefaults hookPermissionAsked → JSON（一次性）
          let ud = UserDefaults.standard
          if ud.bool(forKey: "hookPermissionAsked") {
              loaded.hookPermissionAsked = true
              ud.removeObject(forKey: "hookPermissionAsked")
          }
          self.settings = loaded
      }

      func update(_ block: (inout AppSettings) -> Void) {
          block(&settings)
          save()
      }

      var hookPermissionAsked: Bool {
          get { settings.hookPermissionAsked }
          set { update { $0.hookPermissionAsked = newValue } }
      }

      private func save() {
          guard let data = try? JSONEncoder().encode(settings) else { return }
          FileManager.default.createFile(atPath: path, contents: data)
      }
  }
  ```

- [ ] **Step 4: 删除 AppCoordinator.swift 末尾的内嵌 SettingsStore**

  打开 `PixelPets/App/AppCoordinator.swift`，找到末尾的：
  ```swift
  final class SettingsStore {
      private let defaults: UserDefaults
      ...
  }
  ```
  删除整段（约 462–474 行），保留文件其余所有内容不变。

- [ ] **Step 5: 重新生成 Xcode project**

  ```bash
  xcodegen generate
  ```
  XcodeGen 自动将 `PixelPets/Persistence/SettingsStore.swift` 和 `PixelPetsTests/SettingsStoreTests.swift` 纳入对应 target。
- [ ] **Step 6: 运行测试确认全通过**

  ```bash
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" \
    -only-testing:PixelPetsTests/SettingsStoreTests test 2>&1 | grep -E "passed|failed|SUCCEEDED|FAILED"
  ```
  预期：`SettingsStoreTests` 8 个测试全部 passed，其他套件也不受影响。

- [ ] **Step 7: Commit**

  ```bash
  git add PixelPets/Persistence/SettingsStore.swift \
          PixelPetsTests/SettingsStoreTests.swift \
          PixelPets/App/AppCoordinator.swift \
          PixelPets.xcodeproj/
  git commit -m "feat: extract SettingsStore — JSON persistence, ScenePreference, enabledCLIs opt-out"
  ```

---

## Task 2: enabledCLIs 过滤 + 空状态 UI

**Files:**
- Modify: `PixelPets/Models/PetViewModel.swift`
- Modify: `PixelPets/App/AppCoordinator.swift`
- Modify: `PixelPets/UI/PopoverView.swift` (空状态部分)
- Create: `PixelPetsTests/EnabledCLIsFilterTests.swift`

- [ ] **Step 1: 写失败测试**

  创建 `PixelPetsTests/EnabledCLIsFilterTests.swift`：

  ```swift
  import XCTest
  @testable import PixelPets

  @MainActor
  final class EnabledCLIsFilterTests: XCTestCase {

      private func makeInfo(_ skin: AgentSkin, detected: Bool = true) -> CliQuotaInfo {
          var info = CliQuotaInfo(id: skin, isDetected: detected)
          return info
      }

      func test_emptyEnabledCLIs_showsAllDetected() {
          let settings = AppSettings()  // enabledCLIs = [:]
          let all: [CliQuotaInfo] = AgentSkin.allCases.map { makeInfo($0) }
          let visible = all.filter { settings.isEnabled($0.id) && $0.isDetected }
          XCTAssertEqual(visible.count, AgentSkin.allCases.count)
      }

      func test_explicitFalse_hidesOneCLI() {
          var settings = AppSettings()
          settings.enabledCLIs[AgentSkin.codex.rawValue] = false
          let all: [CliQuotaInfo] = AgentSkin.allCases.map { makeInfo($0) }
          let visible = all.filter { settings.isEnabled($0.id) && $0.isDetected }
          XCTAssertEqual(visible.count, AgentSkin.allCases.count - 1)
          XCTAssertFalse(visible.contains(where: { $0.id == .codex }))
      }

      func test_allDisabled_returnsEmpty() {
          var settings = AppSettings()
          for skin in AgentSkin.allCases {
              settings.enabledCLIs[skin.rawValue] = false
          }
          let all: [CliQuotaInfo] = AgentSkin.allCases.map { makeInfo($0) }
          let visible = all.filter { settings.isEnabled($0.id) && $0.isDetected }
          XCTAssertTrue(visible.isEmpty)
      }

      func test_notDetected_hiddenRegardlessOfSettings() {
          let settings = AppSettings()
          let undetected = makeInfo(.claude, detected: false)
          let visible = [undetected].filter { settings.isEnabled($0.id) && $0.isDetected }
          XCTAssertTrue(visible.isEmpty)
      }
  }
  ```

- [ ] **Step 2: 运行测试确认失败**

  ```bash
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" \
    -only-testing:PixelPetsTests/EnabledCLIsFilterTests test 2>&1 | grep -E "error:|passed|failed"
  ```
  预期：`CliQuotaInfo(id:isDetected:)` 初始化器不存在，编译错误。

- [ ] **Step 3: 给 CliQuotaInfo 加简便初始化器**

  在 `PixelPets/Models/PetViewModel.swift` 中，`CliQuotaInfo` struct 末尾添加：

  ```swift
  init(id: AgentSkin, isDetected: Bool = false) {
      self.id = id
      self.isDetected = isDetected
  }
  ```

- [ ] **Step 4: 更新 `visibleClis` 加入 enabledCLIs 过滤**

  `PetViewModel.swift` 中的 `visibleClis` 当前是：
  ```swift
  var visibleClis: [CliQuotaInfo] { cliInfos.filter(\.isDetected) }
  ```

  改为：
  ```swift
  var enabledCLIFilter: ((CliQuotaInfo) -> Bool) = { _ in true }

  var visibleClis: [CliQuotaInfo] {
      cliInfos.filter { $0.isDetected && enabledCLIFilter($0) }
  }
  ```

- [ ] **Step 5: 在 AppCoordinator 中设置 filter**

  在 `AppCoordinator` 的 `start()` 方法里，`ensureInstalledAt()` 之后加：

  ```swift
  viewModel.enabledCLIFilter = { [weak self] info in
      self?.settingsStore.settings.isEnabled(info.id) ?? true
  }
  ```

  同时在 `settingsStore` 的 `@Published` 变化时触发 viewModel 刷新，在 `start()` 中 `ensureInstalledAt()` 之后添加：

  ```swift
  settingsStore.$settings
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
          self?.viewModel.objectWillChange.send()
      }
      .store(in: &cancellables)
  ```

  （确认 `AppCoordinator` 有 `cancellables: Set<AnyCancellable>` — 若没有则添加 `private var cancellables: Set<AnyCancellable> = []`）

- [ ] **Step 6: 重新生成 Xcode project**

  ```bash
  xcodegen generate
  ```
- [ ] **Step 7: 运行测试确认全通过**

  ```bash
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" test 2>&1 | tail -3
  ```
  预期：`** TEST SUCCEEDED **`

- [ ] **Step 8: Commit**

  ```bash
  git add PixelPets/Models/PetViewModel.swift \
          PixelPets/App/AppCoordinator.swift \
          PixelPetsTests/EnabledCLIsFilterTests.swift \
          PixelPets.xcodeproj/
  git commit -m "feat: enabledCLIs opt-out filter wired into visibleClis"
  ```

---

## Task 3: SettingsView + PixelPetsApp wiring

**Files:**
- Create: `PixelPets/UI/SettingsView.swift`
- Modify: `PixelPets/App/PixelPetsApp.swift`

- [ ] **Step 1: 创建 `PixelPets/UI/SettingsView.swift`**

  ```swift
  import SwiftUI

  struct SettingsView: View {
      @EnvironmentObject private var settingsStore: SettingsStore
      var onRegisterHooks: () -> Void = {}

      var body: some View {
          TabView {
              GeneralSettingsTab()
                  .tabItem { Label("通用", systemImage: "gearshape") }
              SceneSettingsTab()
                  .tabItem { Label("场景", systemImage: "sparkles") }
              AdvancedSettingsTab(onRegisterHooks: onRegisterHooks)
                  .tabItem { Label("高级", systemImage: "wrench.and.screwdriver") }
          }
          .environmentObject(settingsStore)
          .frame(width: 380, height: 280)
      }
  }

  private struct GeneralSettingsTab: View {
      @EnvironmentObject private var store: SettingsStore

      var body: some View {
          Form {
              Section("AI 工具") {
                  ForEach(AgentSkin.allCases, id: \.self) { skin in
                      Toggle(skin.displayName, isOn: Binding(
                          get: { store.settings.isEnabled(skin) },
                          set: { enabled in
                              store.update { $0.enabledCLIs[skin.rawValue] = enabled ? nil : false }
                          }
                      ))
                  }
              }
          }
          .formStyle(.grouped)
          .padding()
      }
  }

  private struct SceneSettingsTab: View {
      @EnvironmentObject private var store: SettingsStore

      var body: some View {
          Form {
              Section("默认场景") {
                  Picker("场景偏好", selection: Binding(
                      get: { store.settings.scenePreference },
                      set: { store.update { $0.scenePreference = $1 } }
                  )) {
                      ForEach(ScenePreference.allCases, id: \.self) { pref in
                          Text(pref.displayName).tag(pref)
                      }
                  }
                  .pickerStyle(.radioGroup)
              }
          }
          .formStyle(.grouped)
          .padding()
      }
  }

  private struct AdvancedSettingsTab: View {
      @EnvironmentObject private var store: SettingsStore
      var onRegisterHooks: () -> Void = {}
      @State private var showResetAlert = false

      var body: some View {
          Form {
              Section("Hook 服务器") {
                  HStack {
                      Text("Hook 端口")
                      Spacer()
                      Text("15799")
                          .foregroundStyle(.secondary)
                  }
                  Text("端口固定为 15799，可变端口支持将在后续版本提供。")
                      .font(.caption).foregroundStyle(.secondary)
                  Button("重新注册 Hook", action: onRegisterHooks)
              }
              Section {
                  Button("重置所有设置", role: .destructive) { showResetAlert = true }
              }
          }
          .formStyle(.grouped)
          .padding()
          .alert("确定重置？", isPresented: $showResetAlert) {
              Button("重置", role: .destructive) {
                  store.update { $0 = AppSettings() }
              }
              Button("取消", role: .cancel) {}
          } message: {
              Text("所有设置将恢复默认值，不可撤销。")
          }
      }


  }
  ```

- [ ] **Step 2: 修改 `PixelPets/App/PixelPetsApp.swift`**

  将：
  ```swift
  Settings {
      EmptyView()
  }
  ```
  替换为：
  ```swift
  Settings {
      SettingsView(onRegisterHooks: appDelegate.coordinator.registerDetectedHooks)
          .environmentObject(appDelegate.coordinator.settingsStore)
  }
  ```

  同时在 `AppDelegate` 顶部暴露 coordinator（若已私有则改为 `internal`）：
  ```swift
  let coordinator = AppCoordinator()  // 从 private 改为 internal
  ```

- [ ] **Step 3: 确保 AppCoordinator.settingsStore 可访问**

  在 `AppCoordinator.swift` 中，将：
  ```swift
  private let settingsStore = SettingsStore()
  ```
  改为：
  ```swift
  let settingsStore = SettingsStore()
  ```

- [ ] **Step 4: 重新生成 Xcode project**

  ```bash
  xcodegen generate
  ```
- [ ] **Step 5: 构建验证**

  ```bash
  xcodebuild -scheme PixelPets -destination "platform=macOS" build 2>&1 | tail -3
  ```
  预期：`** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

  ```bash
  git add PixelPets/UI/SettingsView.swift \
          PixelPets/App/PixelPetsApp.swift \
          PixelPets/App/AppCoordinator.swift \
          PixelPets.xcodeproj/
  git commit -m "feat: SettingsView — 3 tabs: general CLI toggles, scene picker, advanced port/reset"
  ```

---

## Task 4: AgentPalette v2 + HabitatScene 协议 + SceneRegistry

**Files:**
- Modify: `PixelPets/Renderer/PixelColor.swift`
- Create: `PixelPets/Renderer/HabitatScene.swift`
- Create: `PixelPetsTests/SceneRegistryTests.swift`

- [ ] **Step 1: 写失败测试**

  创建 `PixelPetsTests/SceneRegistryTests.swift`：

  ```swift
  import XCTest
  @testable import PixelPets

  final class SceneRegistryTests: XCTestCase {

      func test_allSceneIDsHaveRegisteredScene() {
          let registerable: [ScenePreference] = [
              .spaceStation, .cyberpunkLab, .sciFiQuarters, .underwater
          ]
          for pref in registerable {
              guard let id = pref.sceneID else {
                  XCTFail("ScenePreference.\(pref) has no sceneID"); continue
              }
              let scene = SceneRegistry.scene(for: id)
              XCTAssertEqual(scene.id, id, "Scene id mismatch for \(id)")
          }
      }

      func test_randomPreference_returnsNilSceneID() {
          XCTAssertNil(ScenePreference.random.sceneID)
      }

      func test_randomPick_returnsOneOfFourScenes() {
          let picked = SceneRegistry.randomScene()
          let ids = SceneID.allCases
          XCTAssertTrue(ids.contains(picked.id))
      }
  }
  ```

- [ ] **Step 2: 运行测试确认失败**

  ```bash
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" \
    -only-testing:PixelPetsTests/SceneRegistryTests test 2>&1 | grep "error:"
  ```
  预期：编译错误（SceneID、SceneRegistry 不存在）。

- [ ] **Step 3: 更新 `PixelPets/Renderer/PixelColor.swift` — AgentPalette v2**

  将整个 `AgentPalette` enum 替换为：

  ```swift
  enum AgentPalette {
      // 机身主色
      static let claudeBody    = Color(hex: "D4884A")
      static let claudeLight   = Color(hex: "E8A870")
      static let claudeShadow  = Color(hex: "A06030")

      static let opencodeBody  = Color(hex: "2D4A3E")
      static let opencodeLight = Color(hex: "3D6A5A")
      static let opencodeShadow = Color(hex: "1A2E26")

      static let geminiBody    = Color(hex: "4A7ABF")
      static let geminiLight   = Color(hex: "6A9ADF")
      static let geminiShadow  = Color(hex: "2A5A9F")

      static let codexBody     = Color(hex: "C8C8D8")
      static let codexLight    = Color(hex: "E8E8F0")
      static let codexShadow   = Color(hex: "A8A8C0")

      // 天线颜色
      static let antenna       = Color(hex: "5DADE2")

      // 进度条语义色
      static let quotaGreen    = Color(hex: "34C759")
      static let quotaOrange   = Color(hex: "FF9500")
      static let quotaRed      = Color(hex: "FF3B30")
      static let quotaTrack    = Color(hex: "E5E5EA")

      // 旧名（保留向后兼容，过渡期用）
      static let claude        = Color(hex: "D4884A")
      static let opencode      = Color(hex: "2D4A3E")
      static let codexTop      = Color(hex: "C8C8D8")
      static let codexBottom   = Color(hex: "A8A8C0")
      static let outline       = Color(hex: "000000")
      static let screen        = Color.white
      static let quotaYellow   = Color(hex: "FF9500")

      static func bodyColor(for skin: AgentSkin) -> Color {
          switch skin {
          case .claude:    return claudeBody
          case .opencode:  return opencodeBody
          case .gemini:    return geminiBody
          case .codex:     return codexBody
          }
      }

      static func lightColor(for skin: AgentSkin) -> Color {
          switch skin {
          case .claude:    return claudeLight
          case .opencode:  return opencodeLight
          case .gemini:    return geminiLight
          case .codex:     return codexLight
          }
      }

      static func shadowColor(for skin: AgentSkin) -> Color {
          switch skin {
          case .claude:    return claudeShadow
          case .opencode:  return opencodeShadow
          case .gemini:    return geminiShadow
          case .codex:     return codexShadow
          }
      }
  }
  ```

- [ ] **Step 4: 创建 `PixelPets/Renderer/HabitatScene.swift`**

  ```swift
  import SwiftUI

  // MARK: - SceneID

  enum SceneID: String, CaseIterable, Codable {
      case spaceStation  = "space_station"
      case cyberpunkLab  = "cyberpunk_lab"
      case sciFiQuarters = "scifi_quarters"
      case underwater    = "underwater"
  }

  extension ScenePreference {
      var sceneID: SceneID? {
          switch self {
          case .random:       return nil
          case .spaceStation: return .spaceStation
          case .cyberpunkLab: return .cyberpunkLab
          case .sciFiQuarters: return .sciFiQuarters
          case .underwater:   return .underwater
          }
      }
  }

  // MARK: - Protocol

  /// origin: 场景区左上角 (0,0)，与 SwiftUI Canvas 一致（pt 单位）
  protocol HabitatScene {
      var id: SceneID { get }
      var displayName: String { get }
      /// 绘制等距背景、装饰和动画元素
      func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int)
      /// 机器人在该状态下的中心点坐标（相对场景区左上角）
      func robotCenter(for state: PetState, in size: CGSize) -> CGPoint
  }

  // MARK: - SceneRegistry

  struct SceneRegistry {
      static func scene(for id: SceneID) -> any HabitatScene {
          switch id {
          case .spaceStation:  return SpaceStationScene()
          case .cyberpunkLab:  return CyberpunkLabScene()
          case .sciFiQuarters: return SciFiQuartersScene()
          case .underwater:    return UnderwaterScene()
          }
      }

      static func randomScene() -> any HabitatScene {
          let id = SceneID.allCases.randomElement()!
          return scene(for: id)
      }

      static func scene(for preference: ScenePreference) -> any HabitatScene {
          if let id = preference.sceneID {
              return scene(for: id)
          }
          return randomScene()
      }
  }
  ```

  > **注意：** `SpaceStationScene`、`CyberpunkLabScene`、`SciFiQuartersScene`、`UnderwaterScene` 将在 Task 5 创建。此时可先添加空实现让代码编译：
  >
  > ```swift
  > // HabitatScene.swift 末尾临时占位（Task 5 替换为独立文件）
  > struct SpaceStationScene: HabitatScene {
  >     let id: SceneID = .spaceStation
  >     let displayName = "太空站"
  >     func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {}
  >     func robotCenter(for state: PetState, in size: CGSize) -> CGPoint { CGPoint(x: size.width/2, y: size.height/2) }
  > }
  > struct CyberpunkLabScene: HabitatScene {
  >     let id: SceneID = .cyberpunkLab
  >     let displayName = "赛博朋克实验室"
  >     func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {}
  >     func robotCenter(for state: PetState, in size: CGSize) -> CGPoint { CGPoint(x: size.width/2, y: size.height/2) }
  > }
  > struct SciFiQuartersScene: HabitatScene {
  >     let id: SceneID = .sciFiQuarters
  >     let displayName = "星际生活舱"
  >     func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {}
  >     func robotCenter(for state: PetState, in size: CGSize) -> CGPoint { CGPoint(x: size.width/2, y: size.height/2) }
  > }
  > struct UnderwaterScene: HabitatScene {
  >     let id: SceneID = .underwater
  >     let displayName = "像素水族箱"
  >     func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {}
  >     func robotCenter(for state: PetState, in size: CGSize) -> CGPoint { CGPoint(x: size.width/2, y: size.height/2) }
  > }
  > ```

- [ ] **Step 5: 重新生成 Xcode project**

  ```bash
  xcodegen generate
  ```

- [ ] **Step 6: 运行测试确认通过**

  ```bash
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" \
    -only-testing:PixelPetsTests/SceneRegistryTests test 2>&1 | grep -E "passed|failed"
  ```
  预期：3 个测试全部 passed。

- [ ] **Step 7: Commit**

  ```bash
  git add PixelPets/Renderer/PixelColor.swift \
          PixelPets/Renderer/HabitatScene.swift \
          PixelPetsTests/SceneRegistryTests.swift \
          PixelPets.xcodeproj/
  git commit -m "feat: HabitatScene protocol + SceneRegistry + AgentPalette v2"
  ```

---

## Task 5: BitBot v2 渲染器 + 表情提供器

**Files:**
- Create: `PixelPets/Renderer/BitBotV2Renderer.swift`
- Create: `PixelPets/Renderer/BitBotV2FaceProvider.swift`
- Modify: `PixelPets/Renderer/FaceProvider.swift` (删除 BitBotFaceProvider)

- [ ] **Step 1: 更新 `PixelPets/Renderer/FaceProvider.swift`**

  删除整个 `BitBotFaceProvider` struct（保留协议和 `fillPixel` extension）：

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

- [ ] **Step 2: 创建 `PixelPets/Renderer/BitBotV2FaceProvider.swift`**

  BitBot v2 的头部屏幕区域：列 3–20（宽 18px），行 4–14（高 11px），网格 24×28。
  屏幕背景黑色（`#1A1A2E`），表情像素在其中绘制。

  ```swift
  import SwiftUI

  struct BitBotV2FaceProvider: FaceProvider {
      // 屏幕区域（相对 24×28 网格）
      private static let screenX = 3...20
      private static let screenY = 4...14

      private static let green  = Color(hex: "00FF88")
      private static let yellow = Color(hex: "FFD700")
      private static let blue   = Color(hex: "5DADE2")
      private static let red    = Color(hex: "FF3B30")
      private static let gray   = Color(hex: "888888")
      private static let dark   = Color(hex: "1A1A2E")

      func draw(in ctx: GraphicsContext, state: PetState, frame: Int, scale: CGFloat) {
          // 屏幕背景
          for y in Self.screenY { for x in Self.screenX {
              ctx.fillPixel(x: x, y: y, color: Self.dark, scale: scale)
          }}

          switch state {
          case .idle:                  drawIdle(ctx, frame: frame, scale: scale)
          case .thinking:              drawThinking(ctx, frame: frame, scale: scale)
          case .typing, .searching,
               .juggling, .conducting,
               .fast:                  drawWorking(ctx, frame: frame, scale: scale)
          case .success, .evolving:   drawCelebrating(ctx, frame: frame, scale: scale)
          case .error:                 drawError(ctx, frame: frame, scale: scale)
          case .sleeping, .auth:       drawSleep(ctx, frame: frame, scale: scale)
          }
      }

      // MARK: - Idle: 黄色笑眼 + 弧形嘴，每 60 帧眨眼
      private func drawIdle(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
          let blink = (frame % 60) > 56
          if blink {
              // 闭眼横线
              for x in 7...9  { ctx.fillPixel(x: x, y: 7, color: Self.yellow, scale: scale) }
              for x in 13...15 { ctx.fillPixel(x: x, y: 7, color: Self.yellow, scale: scale) }
          } else {
              // 圆眼
              for (dx,dy) in [(0,0),(1,0),(0,1),(1,1)] {
                  ctx.fillPixel(x: 7+dx, y: 6+dy, color: Self.yellow, scale: scale)
                  ctx.fillPixel(x: 14+dx, y: 6+dy, color: Self.yellow, scale: scale)
              }
          }
          // 笑嘴弧
          for x in 9...14 { ctx.fillPixel(x: x, y: 11, color: Self.yellow, scale: scale) }
          ctx.fillPixel(x: 8,  y: 10, color: Self.yellow, scale: scale)
          ctx.fillPixel(x: 15, y: 10, color: Self.yellow, scale: scale)
      }

      // MARK: - Thinking: 蓝色双眼 + 旋转省略号
      private func drawThinking(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
          for (dx,dy) in [(0,0),(1,0),(0,1),(1,1)] {
              ctx.fillPixel(x: 7+dx, y: 6+dy, color: Self.blue, scale: scale)
              ctx.fillPixel(x: 14+dx, y: 6+dy, color: Self.blue, scale: scale)
          }
          let dotX = [9, 12, 15]
          for (i, x) in dotX.enumerated() {
              let phase = (frame / 8 + i) % 3
              let alpha = phase == 0 ? 1.0 : (phase == 1 ? 0.5 : 0.2)
              ctx.fillPixel(x: x, y: 11, color: Self.blue.opacity(alpha), scale: scale)
          }
      }

      // MARK: - Working: 绿色双眼 + 代码滚动行
      private func drawWorking(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
          // 脉冲亮度
          let pulse = (frame % 16) < 8 ? 1.0 : 0.7
          for (dx,dy) in [(0,0),(1,0),(0,1),(1,1)] {
              ctx.fillPixel(x: 7+dx, y: 6+dy, color: Self.green.opacity(pulse), scale: scale)
              ctx.fillPixel(x: 14+dx, y: 6+dy, color: Self.green.opacity(pulse), scale: scale)
          }
          // 滚动代码线（3行，错开偏移）
          let scroll = frame % 12
          for row in 0..<3 {
              let y = 9 + row
              let width = [14, 10, 12][row]
              let offset = (scroll + row * 4) % 6
              for x in (3+offset)..<(3+offset+width) where x <= 20 {
                  ctx.fillPixel(x: x, y: y, color: Self.green.opacity(0.4), scale: scale)
              }
          }
      }

      // MARK: - Celebrating: 星星眼 + 大笑嘴
      private func drawCelebrating(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
          // 星星眼（旋转感）
          let starPts1: [(Int,Int)] = [(7,6),(9,6),(8,7),(7,8),(9,8)]
          let starPts2: [(Int,Int)] = [(14,6),(16,6),(15,7),(14,8),(16,8)]
          for (x,y) in starPts1 { ctx.fillPixel(x: x, y: y, color: Self.yellow, scale: scale) }
          for (x,y) in starPts2 { ctx.fillPixel(x: x, y: y, color: Self.yellow, scale: scale) }
          // 大笑嘴
          for x in 8...15 { ctx.fillPixel(x: x, y: 12, color: Self.yellow, scale: scale) }
          ctx.fillPixel(x: 7,  y: 11, color: Self.yellow, scale: scale)
          ctx.fillPixel(x: 16, y: 11, color: Self.yellow, scale: scale)
          ctx.fillPixel(x: 7,  y: 10, color: Self.yellow, scale: scale)
          ctx.fillPixel(x: 16, y: 10, color: Self.yellow, scale: scale)
      }

      // MARK: - Error: 红色 X 眼 + 屏幕闪烁
      private func drawError(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
          let col = (frame % 10) < 5 ? Self.red : Self.red.opacity(0.4)
          let x1pts: [(Int,Int)] = [(7,6),(9,8),(8,7),(9,6),(7,8)]
          let x2pts: [(Int,Int)] = [(14,6),(16,8),(15,7),(16,6),(14,8)]
          for (x,y) in x1pts { ctx.fillPixel(x: x, y: y, color: col, scale: scale) }
          for (x,y) in x2pts { ctx.fillPixel(x: x, y: y, color: col, scale: scale) }
      }

      // MARK: - Sleep: 闭眼横线 + ZZZ（大图）
      private func drawSleep(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
          let dim = Self.gray.opacity(0.7)
          for x in 7...9  { ctx.fillPixel(x: x, y: 7, color: dim, scale: scale) }
          for x in 13...15 { ctx.fillPixel(x: x, y: 7, color: dim, scale: scale) }
          // 小 zzz 在屏幕右上
          let zAlpha = 0.3 + 0.3 * abs(sin(Double(frame) * 0.05))
          ctx.fillPixel(x: 18, y: 5, color: Self.gray.opacity(zAlpha), scale: scale)
          ctx.fillPixel(x: 19, y: 5, color: Self.gray.opacity(zAlpha * 0.7), scale: scale)
      }
  }
  ```

- [ ] **Step 3: 创建 `PixelPets/Renderer/BitBotV2Renderer.swift`**

  ```swift
  import SwiftUI

  /// 24×28 像素机器人，渲染时缩放到 size×size。
  struct BitBotV2Renderer: View {
      let skin: AgentSkin
      let state: PetState
      let frame: Int
      let size: CGFloat
      private let faceProvider = BitBotV2FaceProvider()

      // 网格常量
      private let W = 24, H = 28

      var body: some View {
          Canvas { ctx, sz in
              let scale = sz.width / CGFloat(W)
              drawBody(ctx, scale: scale)
              drawFace(ctx, scale: scale)
              drawFX(ctx, scale: scale)
          }
          .frame(width: size, height: size * CGFloat(H) / CGFloat(W))
      }

      private func drawBody(_ ctx: GraphicsContext, scale: CGFloat) {
          let body  = AgentPalette.bodyColor(for: skin)
          let light = AgentPalette.lightColor(for: skin)
          let shadow = AgentPalette.shadowColor(for: skin)
          let ant   = AgentPalette.antenna
          let black = Color.black

          // ── 天线 (左右侧) ──
          for y in 4...6 {
              ctx.fillPixel(x: 0, y: y, color: ant, scale: scale)
              ctx.fillPixel(x: 1, y: y, color: ant, scale: scale)
              ctx.fillPixel(x: 22, y: y, color: ant, scale: scale)
              ctx.fillPixel(x: 23, y: y, color: ant, scale: scale)
          }

          // ── 头部 (cols 2–21, rows 1–17) ──
          for y in 1...17 { for x in 2...21 {
              ctx.fillPixel(x: x, y: y, color: body, scale: scale)
          }}
          // 头部轮廓
          for x in 2...21 {
              ctx.fillPixel(x: x, y: 0,  color: black, scale: scale)
              ctx.fillPixel(x: x, y: 17, color: black, scale: scale)
          }
          for y in 1...17 {
              ctx.fillPixel(x: 2,  y: y, color: black, scale: scale)
              ctx.fillPixel(x: 21, y: y, color: black, scale: scale)
          }

          // ── 高光 (左上) ──
          for (x,y) in [(3,2),(4,2),(3,3)] {
              ctx.fillPixel(x: x, y: y, color: light, scale: scale)
          }
          // ── 阴影 (右下) ──
          for (x,y) in [(19,15),(20,14),(20,15)] {
              ctx.fillPixel(x: x, y: y, color: shadow, scale: scale)
          }

          // ── 屏幕边框 (cols 3–20, rows 3–15) ──
          for x in 3...20 {
              ctx.fillPixel(x: x, y: 3,  color: black, scale: scale)
              ctx.fillPixel(x: x, y: 15, color: black, scale: scale)
          }
          for y in 4...14 {
              ctx.fillPixel(x: 3,  y: y, color: black, scale: scale)
              ctx.fillPixel(x: 20, y: y, color: black, scale: scale)
          }

          // ── 身体 (cols 5–18, rows 18–23) ──
          for y in 18...23 { for x in 5...18 {
              ctx.fillPixel(x: x, y: y, color: body, scale: scale)
          }}
          // 身体轮廓
          for x in 5...18 {
              ctx.fillPixel(x: x, y: 23, color: black, scale: scale)
          }
          for y in 18...23 {
              ctx.fillPixel(x: 5,  y: y, color: black, scale: scale)
              ctx.fillPixel(x: 18, y: y, color: black, scale: scale)
          }

          // ── 双臂 (左: cols 2–4, 右: cols 19–21, rows 18–21) ──
          for y in 18...21 {
              for x in 2...4  { ctx.fillPixel(x: x, y: y, color: body, scale: scale) }
              for x in 19...21 { ctx.fillPixel(x: x, y: y, color: body, scale: scale) }
          }

          // ── 双腿 (cols 7–9, 14–16, rows 24–27) ──
          for y in 24...27 {
              for x in 7...9  { ctx.fillPixel(x: x, y: y, color: body, scale: scale) }
              for x in 14...16 { ctx.fillPixel(x: x, y: y, color: body, scale: scale) }
          }
          for x in 7...9  { ctx.fillPixel(x: x, y: 27, color: black, scale: scale) }
          for x in 14...16 { ctx.fillPixel(x: x, y: 27, color: black, scale: scale) }
      }

      private func drawFace(_ ctx: GraphicsContext, scale: CGFloat) {
          faceProvider.draw(in: ctx, state: state, frame: frame, scale: scale)
      }

      private func drawFX(_ ctx: GraphicsContext, scale: CGFloat) {
          guard state == .success || state == .evolving else { return }
          // 4 颗星形粒子从头顶散射（每 15 帧跳一次）
          let phase = (frame % 30)
          guard phase < 15 else { return }
          let progress = CGFloat(phase) / 15
          let offsets: [(CGFloat, CGFloat)] = [(-3,-1),(3,-1),(-2,-3),(2,-3)]
          for (dx, dy) in offsets {
              let x = Int(12 + dx * progress * 3)
              let y = Int(0 + dy * progress * 2)
              guard x >= 0 && x < 24 && y >= 0 else { continue }
              ctx.fillPixel(x: x, y: y, color: Color(hex: "FFD700"), scale: scale)
          }
      }
  }
  ```

- [ ] **Step 4: 重新生成 Xcode project**

  ```bash
  xcodegen generate
  ```

- [ ] **Step 5: 构建验证**

  ```bash
  xcodebuild -scheme PixelPets -destination "platform=macOS" build 2>&1 | tail -3
  ```
  预期：`** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

  ```bash
  git add PixelPets/Renderer/FaceProvider.swift \
          PixelPets/Renderer/BitBotV2Renderer.swift \
          PixelPets/Renderer/BitBotV2FaceProvider.swift \
          PixelPets/Renderer/PixelColor.swift \
          PixelPets.xcodeproj/
  git commit -m "feat: BitBot v2 — 24×28 grid, 7-state large-screen face provider, AgentPalette v2"
  ```

---

## Task 6: 四个场景实现

**Files:**
- Create: `PixelPets/Renderer/Scenes/SpaceStationScene.swift`
- Create: `PixelPets/Renderer/Scenes/CyberpunkLabScene.swift`
- Create: `PixelPets/Renderer/Scenes/SciFiQuartersScene.swift`
- Create: `PixelPets/Renderer/Scenes/UnderwaterScene.swift`
- Modify: `PixelPets/Renderer/HabitatScene.swift` (删除末尾占位 structs)

所有场景的 `drawBackground` 都接收 30fps 的 `frame` 计数器，用 `frame % period` 驱动循环动画。`robotCenter` 返回机器人中心点（pt，相对场景左上角）。

- [ ] **Step 1: 创建 `Scenes/` 目录**

  ```bash
  mkdir -p /Users/panjuntao/Developer/pixel-pets/PixelPets/Renderer/Scenes
  ```

- [ ] **Step 2: 创建 `SpaceStationScene.swift`**

  ```swift
  import SwiftUI

  struct SpaceStationScene: HabitatScene {
      let id: SceneID = .spaceStation
      let displayName = "太空站"

      // 固定随机星点（每次场景实例化时生成，保持一致）
      private let stars: [(x: CGFloat, y: CGFloat, period: Int)] = {
          var result = [(CGFloat, CGFloat, Int)]()
          var rng = SystemRandomNumberGenerator()
          for _ in 0..<20 {
              let x = CGFloat.random(in: 0...1, using: &rng)
              let y = CGFloat.random(in: 0...0.6, using: &rng)
              let period = Int.random(in: 40...80, using: &rng)
              result.append((x, y, period))
          }
          return result
      }()

      func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {
          // 深空渐变背景
          ctx.fill(Path(CGRect(origin: .zero, size: size)),
                   with: .linearGradient(
                       Gradient(colors: [Color(hex: "050510"), Color(hex: "0A1525")]),
                       startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

          // 闪烁星点
          for star in stars {
              let phase = frame % star.period
              let alpha = 0.4 + 0.6 * abs(sin(Double(phase) * .pi / Double(star.period)))
              let pt = CGPoint(x: star.x * size.width, y: star.y * size.height)
              ctx.fill(Path(ellipseIn: CGRect(x: pt.x-1, y: pt.y-1, width: 2, height: 2)),
                       with: .color(.white.opacity(alpha)))
          }

          let f = size  // 简写

          // ── 等距地板 ──
          let floorY = f.height * 0.72
          drawIsometricFloor(ctx, size: size, floorY: floorY,
                             color1: Color(hex: "1A2A4A"), color2: Color(hex: "111E35"))

          // ── 左墙：全息终端 ──
          let termX = f.width * 0.08, termY = floorY - 50
          // 终端屏幕
          ctx.fill(Path(CGRect(x: termX, y: termY, width: 60, height: 40)),
                   with: .color(Color(hex: "001A3A")))
          ctx.stroke(Path(CGRect(x: termX, y: termY, width: 60, height: 40)),
                     with: .color(Color(hex: "0066FF").opacity(0.8)), lineWidth: 1)
          // 滚动代码线（每 4 帧下移）
          let scroll = (frame / 4) % 8
          for i in 0..<5 {
              let lineY = termY + 6 + CGFloat((i + scroll) % 8) * 5
              guard lineY < termY + 40 else { continue }
              ctx.fill(Path(CGRect(x: termX+4, y: lineY, width: CGFloat([45,30,38,25,40][i % 5]), height: 2)),
                       with: .color(Color(hex: "00AAFF").opacity(0.6)))
          }

          // ── 右墙：圆形舷窗 ──
          let portX = f.width * 0.78, portY = floorY - 65
          let portR: CGFloat = 24
          ctx.fill(Path(ellipseIn: CGRect(x: portX-portR, y: portY-portR,
                                         width: portR*2, height: portR*2)),
                   with: .color(Color(hex: "000510")))
          ctx.stroke(Path(ellipseIn: CGRect(x: portX-portR, y: portY-portR,
                                           width: portR*2, height: portR*2)),
                     with: .color(Color(hex: "223355")), lineWidth: 2)
          // 星球（缓慢旋转：每 300 帧转 1 度，影响星球纹理偏移）
          let planetOffset = CGFloat(frame % 300) / 300
          ctx.fill(Path(ellipseIn: CGRect(x: portX-12+planetOffset*2, y: portY-10,
                                         width: 20, height: 18)),
                   with: .linearGradient(
                       Gradient(colors: [Color(hex: "4A90D9"), Color(hex: "1A5FA0")]),
                       startPoint: CGPoint(x: portX-10, y: portY-10),
                       endPoint: CGPoint(x: portX+10, y: portY+10)))
      }

      func robotCenter(for state: PetState, in size: CGSize) -> CGPoint {
          let floorY = size.height * 0.72
          switch state {
          case .typing, .searching, .juggling, .conducting, .fast, .thinking:
              return CGPoint(x: size.width * 0.32, y: floorY - 30)
          case .sleeping:
              return CGPoint(x: size.width * 0.82, y: floorY - 20)
          default:
              return CGPoint(x: size.width * 0.5, y: floorY - 28)
          }
      }

      private func drawIsometricFloor(_ ctx: GraphicsContext, size: CGSize,
                                       floorY: CGFloat, color1: Color, color2: Color) {
          // 简化等距地板：菱形格纹
          let tileW: CGFloat = 40, tileH: CGFloat = 20
          let cols = Int(size.width / tileW) + 2
          for col in -1...cols {
              let x = CGFloat(col) * tileW
              let path = Path { p in
                  p.move(to: CGPoint(x: x, y: floorY))
                  p.addLine(to: CGPoint(x: x + tileW/2, y: floorY - tileH/2))
                  p.addLine(to: CGPoint(x: x + tileW, y: floorY))
                  p.addLine(to: CGPoint(x: x + tileW/2, y: floorY + tileH/2))
                  p.closeSubpath()
              }
              ctx.fill(path, with: .color(col % 2 == 0 ? color1 : color2))
              ctx.stroke(path, with: .color(Color(hex: "2A4A6A").opacity(0.5)), lineWidth: 0.5)
          }
      }
  }
  ```

- [ ] **Step 3: 创建 `CyberpunkLabScene.swift`**

  ```swift
  import SwiftUI

  struct CyberpunkLabScene: HabitatScene {
      let id: SceneID = .cyberpunkLab
      let displayName = "赛博朋克实验室"

      func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {
          // 极暗背景
          ctx.fill(Path(CGRect(origin: .zero, size: size)),
                   with: .color(Color(hex: "08000F")))

          // 霓虹环境光晕
          ctx.drawLayer { inner in
              inner.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                             Gradient(colors: [Color(hex: "FF00FF").opacity(0.12), .clear]),
                             center: CGPoint(x: size.width*0.2, y: size.height*0.5),
                             startRadius: 0, endRadius: size.width*0.5))
              inner.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(
                             Gradient(colors: [Color(hex: "00FFFF").opacity(0.10), .clear]),
                             center: CGPoint(x: size.width*0.8, y: size.height*0.4),
                             startRadius: 0, endRadius: size.width*0.4))
          }

          let floorY = size.height * 0.74
          drawIsometricFloor(ctx, size: size, floorY: floorY)

          // ── 左墙霓虹招牌 ──
          let signX = size.width * 0.06, signY = floorY - 55
          let signFlicker = (frame % 47) > 40
          let signColor = signFlicker ? Color(hex: "FF00FF").opacity(0.3) : Color(hex: "FF00FF")
          ctx.stroke(Path(CGRect(x: signX, y: signY, width: 55, height: 14)),
                     with: .color(signColor), lineWidth: 1.5)

          // ── 右墙服务器机架 ──
          let rackX = size.width * 0.78, rackY = floorY - 65
          ctx.fill(Path(CGRect(x: rackX, y: rackY, width: 30, height: 55)),
                   with: .color(Color(hex: "0A0A1A")))
          ctx.stroke(Path(CGRect(x: rackX, y: rackY, width: 30, height: 55)),
                     with: .color(Color(hex: "00FFFF").opacity(0.2)), lineWidth: 0.5)
          // 指示灯（3行，交替青/粉）
          let indicatorColors = [Color(hex: "00FFFF"), Color(hex: "FF00FF"), Color(hex: "00FFFF")]
          for row in 0..<3 {
              let phase = (frame / 12 + row) % 3
              let y = rackY + 10 + CGFloat(row) * 15
              let color = indicatorColors[row].opacity(phase == 0 ? 1.0 : 0.2)
              ctx.fill(Path(ellipseIn: CGRect(x: rackX+8, y: y, width: 5, height: 5)),
                       with: .color(color))
          }

          // ── 全息投影圆盘（working 时激活感 —— 基于 frame 动） ──
          let diskX = size.width * 0.45, diskY = floorY - 8
          let diskPhase = CGFloat(frame % 30) / 30
          let diskAlpha = 0.3 + 0.3 * sin(diskPhase * .pi * 2)
          ctx.stroke(Path(ellipseIn: CGRect(x: diskX-20, y: diskY-6, width: 40, height: 12)),
                     with: .color(Color(hex: "9900FF").opacity(diskAlpha)), lineWidth: 1)
      }

      func robotCenter(for state: PetState, in size: CGSize) -> CGPoint {
          let floorY = size.height * 0.74
          switch state {
          case .typing, .searching, .juggling, .conducting, .fast, .thinking:
              return CGPoint(x: size.width * 0.45, y: floorY - 28)
          case .sleeping:
              return CGPoint(x: size.width * 0.12, y: floorY - 20)
          default:
              return CGPoint(x: size.width * 0.62, y: floorY - 28)
          }
      }

      private func drawIsometricFloor(_ ctx: GraphicsContext, size: CGSize, floorY: CGFloat) {
          let tileW: CGFloat = 36, tileH: CGFloat = 18
          let cols = Int(size.width / tileW) + 2
          for col in -1...cols {
              let x = CGFloat(col) * tileW
              let path = Path { p in
                  p.move(to: CGPoint(x: x, y: floorY))
                  p.addLine(to: CGPoint(x: x + tileW/2, y: floorY - tileH/2))
                  p.addLine(to: CGPoint(x: x + tileW, y: floorY))
                  p.addLine(to: CGPoint(x: x + tileW/2, y: floorY + tileH/2))
                  p.closeSubpath()
              }
              ctx.fill(path, with: .color(Color(hex: "110018")))
              ctx.stroke(path, with: .color(Color(hex: "440044").opacity(0.6)), lineWidth: 0.5)
          }
          // 地板反光条
          for i in 0..<3 {
              let x = size.width * CGFloat(i + 1) / 4
              ctx.stroke(Path { p in
                  p.move(to: CGPoint(x: x-20, y: floorY-5))
                  p.addLine(to: CGPoint(x: x+20, y: floorY+5))
              }, with: .color(Color(hex: "FF00FF").opacity(0.08)), lineWidth: 1)
          }
      }
  }
  ```

- [ ] **Step 4: 创建 `SciFiQuartersScene.swift`**

  ```swift
  import SwiftUI

  struct SciFiQuartersScene: HabitatScene {
      let id: SceneID = .sciFiQuarters
      let displayName = "星际生活舱"

      private let nebulaDrift: CGFloat = 0  // 用 frame 计算

      func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {
          ctx.fill(Path(CGRect(origin: .zero, size: size)),
                   with: .linearGradient(
                       Gradient(colors: [Color(hex: "0A1520"), Color(hex: "060F18")]),
                       startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

          let floorY = size.height * 0.73
          drawIsometricFloor(ctx, size: size, floorY: floorY)

          // ── 左墙：大型全景舷窗 ──
          let winX = size.width * 0.06, winY = floorY - 80
          let winW: CGFloat = 90, winH: CGFloat = 65
          ctx.fill(Path(CGRect(x: winX, y: winY, width: winW, height: winH)),
                   with: .color(Color(hex: "001830")))
          ctx.stroke(Path(CGRect(x: winX, y: winY, width: winW, height: winH)),
                     with: .color(Color(hex: "336699")), lineWidth: 1.5)
          // 星云（缓慢漂移，每 180 帧移动 1pt）
          let drift = CGFloat(frame % 180) / 180
          ctx.drawLayer { inner in
              inner.clip(to: Path(CGRect(x: winX+1, y: winY+1, width: winW-2, height: winH-2)))
              inner.fill(Path(ellipseIn: CGRect(x: winX+5+drift*3, y: winY+8, width: 40, height: 28)),
                         with: .radialGradient(
                             Gradient(colors: [Color(hex: "FF6B35").opacity(0.7), .clear]),
                             center: CGPoint(x: winX+25, y: winY+22),
                             startRadius: 0, endRadius: 25))
              inner.fill(Path(ellipseIn: CGRect(x: winX+30, y: winY+25, width: 28, height: 20)),
                         with: .radialGradient(
                             Gradient(colors: [Color(hex: "C0392B").opacity(0.5), .clear]),
                             center: CGPoint(x: winX+44, y: winY+35),
                             startRadius: 0, endRadius: 18))
          }

          // ── 右墙：充电站 ──
          let chargeX = size.width * 0.80, chargeY = floorY - 55
          ctx.fill(Path(CGRect(x: chargeX, y: chargeY, width: 22, height: 45)),
                   with: .color(Color(hex: "0A1830")))
          ctx.stroke(Path(CGRect(x: chargeX, y: chargeY, width: 22, height: 45)),
                     with: .color(Color(hex: "0066AA")), lineWidth: 1)
          // 充电指示灯（呼吸效果）
          let breathe = 0.5 + 0.5 * sin(Double(frame) * 0.08)
          ctx.fill(Path(ellipseIn: CGRect(x: chargeX+7, y: chargeY+6, width: 8, height: 8)),
                   with: .color(Color(hex: "00AAFF").opacity(breathe)))

          // ── 悬浮植物（上下浮动）──
          let plantY = floorY - 30 - 2 * sin(Double(frame % 120) / 120 * .pi * 2)
          ctx.fill(Path(ellipseIn: CGRect(x: size.width*0.48, y: plantY-10, width: 16, height: 12)),
                   with: .color(Color(hex: "228B22").opacity(0.8)))
          ctx.fill(Path(CGRect(x: size.width*0.50+2, y: plantY, width: 3, height: 10)),
                   with: .color(Color(hex: "6B8E23")))
      }

      func robotCenter(for state: PetState, in size: CGSize) -> CGPoint {
          let floorY = size.height * 0.73
          switch state {
          case .typing, .searching, .juggling, .conducting, .fast, .thinking:
              return CGPoint(x: size.width * 0.55, y: floorY - 30)
          case .sleeping:
              return CGPoint(x: size.width * 0.82, y: floorY - 22)
          default:
              return CGPoint(x: size.width * 0.22, y: floorY - 28)
          }
      }

      private func drawIsometricFloor(_ ctx: GraphicsContext, size: CGSize, floorY: CGFloat) {
          let tileW: CGFloat = 44, tileH: CGFloat = 22
          let cols = Int(size.width / tileW) + 2
          for col in -1...cols {
              let x = CGFloat(col) * tileW
              let path = Path { p in
                  p.move(to: CGPoint(x: x, y: floorY))
                  p.addLine(to: CGPoint(x: x + tileW/2, y: floorY - tileH/2))
                  p.addLine(to: CGPoint(x: x + tileW, y: floorY))
                  p.addLine(to: CGPoint(x: x + tileW/2, y: floorY + tileH/2))
                  p.closeSubpath()
              }
              ctx.fill(path, with: .color(Color(hex: "111E2E")))
              ctx.stroke(path, with: .color(Color(hex: "2A4A6A").opacity(0.4)), lineWidth: 0.5)
          }
      }
  }
  ```

- [ ] **Step 5: 创建 `UnderwaterScene.swift`**

  ```swift
  import SwiftUI

  struct UnderwaterScene: HabitatScene {
      let id: SceneID = .underwater
      let displayName = "像素水族箱"

      // 珊瑚固定位置
      private let corals: [(x: CGFloat, height: CGFloat, color: String)] = [
          (0.06, 0.28, "E17055"), (0.10, 0.20, "FD79A8"), (0.14, 0.35, "00B894"),
          (0.72, 0.22, "A29BFE"), (0.78, 0.32, "00CEC9"), (0.85, 0.18, "FDCB6E"),
          (0.24, 0.15, "FF7675"), (0.62, 0.25, "6C5CE7"),
      ]

      func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {
          // 水体渐变
          ctx.fill(Path(CGRect(origin: .zero, size: size)),
                   with: .linearGradient(
                       Gradient(colors: [Color(hex: "4ECDC4"), Color(hex: "2D8A80"), Color(hex: "1A5F58")]),
                       startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

          // 水面光波（3条斜线，每帧微移）
          for i in 0..<3 {
              let offset = CGFloat((frame + i*20) % 40) * 0.5
              let y = CGFloat(i+1) * size.height * 0.08
              ctx.stroke(Path { p in
                  p.move(to: CGPoint(x: offset, y: y))
                  p.addLine(to: CGPoint(x: size.width * 0.6 + offset, y: y + 4))
              }, with: .color(.white.opacity(0.12)), lineWidth: 1)
          }

          // 气泡（每 30 帧新气泡出现，从随机 x 上升）
          for i in 0..<4 {
              let bubbleSeed = (i * 73 + 17)
              let xFrac = CGFloat(bubbleSeed % 60 + 20) / 100
              let period = 90 + i * 20
              let progress = CGFloat((frame + i * (period/4)) % period) / CGFloat(period)
              let bubbleY = size.height * (0.9 - progress * 0.9)
              let alpha = 0.3 + 0.4 * (1 - progress)
              let r: CGFloat = i % 2 == 0 ? 3 : 2
              ctx.fill(Path(ellipseIn: CGRect(
                  x: xFrac * size.width - r, y: bubbleY - r, width: r*2, height: r*2)),
                       with: .color(.white.opacity(alpha)))
          }

          // 小鱼（每 200 帧从右向左游过）
          let fishProgress = CGFloat(frame % 200) / 200
          if fishProgress < 0.7 {  // 只显示大部分过程
              let fishX = size.width * (1.1 - fishProgress * 1.4)
              let fishY = size.height * 0.35
              drawPixelFish(ctx, x: fishX, y: fishY)
          }

          // 底部沙地
          ctx.fill(Path(CGRect(x: 0, y: size.height*0.85, width: size.width, height: size.height*0.15)),
                   with: .color(Color(hex: "C4956A").opacity(0.6)))

          // 珊瑚
          for coral in corals {
              let x = coral.x * size.width
              let h = coral.height * size.height
              let y = size.height * 0.85 - h
              ctx.fill(Path(CGRect(x: x, y: y, width: 6, height: h)),
                       with: .color(Color(hex: coral.color)))
          }
      }

      func robotCenter(for state: PetState, in size: CGSize) -> CGPoint {
          // 机器人在水中漂浮（上下浮动 3pt）
          // 使用固定 frame=0 的近似，实际浮动由 HabitatView 加 offset 动画
          switch state {
          case .typing, .searching, .juggling, .conducting, .fast, .thinking:
              return CGPoint(x: size.width * 0.4, y: size.height * 0.55)
          case .sleeping:
              return CGPoint(x: size.width * 0.5, y: size.height * 0.75)
          default:
              return CGPoint(x: size.width * 0.5, y: size.height * 0.45)
          }
      }

      private func drawPixelFish(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat) {
          let c = Color(hex: "FF9F43")
          ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 14, height: 8)), with: .color(c))
          ctx.fill(Path { p in
              p.move(to: CGPoint(x: x+14, y: y+4))
              p.addLine(to: CGPoint(x: x+20, y: y))
              p.addLine(to: CGPoint(x: x+20, y: y+8))
              p.closeSubpath()
          }, with: .color(c))
          ctx.fill(Path(ellipseIn: CGRect(x: x+2, y: y+2, width: 3, height: 3)),
                   with: .color(.black.opacity(0.7)))
      }
  }
  ```

- [ ] **Step 6: 删除 `HabitatScene.swift` 末尾的占位 structs**

  打开 `PixelPets/Renderer/HabitatScene.swift`，删除 Task 4 Step 4 中添加的所有临时占位 struct（`SpaceStationScene`、`CyberpunkLabScene`、`SciFiQuartersScene`、`UnderwaterScene`）。

- [ ] **Step 7: 重新生成 Xcode project**

  ```bash
  xcodegen generate
  ```

- [ ] **Step 8: 构建验证**

  ```bash
  xcodebuild -scheme PixelPets -destination "platform=macOS" build 2>&1 | tail -3
  ```
  预期：`** BUILD SUCCEEDED **`

- [ ] **Step 9: 运行 SceneRegistry 测试**

  ```bash
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" \
    -only-testing:PixelPetsTests/SceneRegistryTests test 2>&1 | grep -E "passed|failed"
  ```
  预期：3 个测试全部 passed。

- [ ] **Step 10: Commit**

  ```bash
  git add PixelPets/Renderer/Scenes/ \
          PixelPets/Renderer/HabitatScene.swift \
          PixelPets.xcodeproj/
  git commit -m "feat: 4 isometric scenes — SpaceStation, CyberpunkLab, SciFiQuarters, Underwater"
  ```

---

## Task 7: HabitatView（场景容器 + 机器人 + 圆点导航）

**Files:**
- Create: `PixelPets/UI/HabitatView.swift`
- Modify: `PixelPets/UI/PopoverView.swift`
- Modify: `PixelPets/App/PixelPetsApp.swift`

- [ ] **Step 1: 创建 `PixelPets/UI/HabitatView.swift`**

  ```swift
  import SwiftUI

  struct HabitatView: View {
      @ObservedObject var viewModel: PetViewModel
      @EnvironmentObject var settingsStore: SettingsStore
      @State private var currentSceneID: SceneID = SceneID.allCases.randomElement()!

      private var currentScene: any HabitatScene {
          SceneRegistry.scene(for: currentSceneID)
      }

      var body: some View {
          ZStack(alignment: .bottomTrailing) {
              AnimationClock(fps: 30) { frame in
                  SceneWithRobot(scene: currentScene, viewModel: viewModel, frame: frame)
              }
              SceneDotNav(
                  scenes: SceneID.allCases,
                  current: currentSceneID,
                  onSelect: { switchScene(to: $0) }
              )
              .padding(.trailing, 8).padding(.bottom, 6)
          }
          .frame(height: 140)
          .clipped()
          .gesture(
              DragGesture(minimumDistance: 30)
                  .onEnded { value in
                      if value.translation.width < -30 { cycleScene(forward: true) }
                      else if value.translation.width > 30 { cycleScene(forward: false) }
                  }
          )
          .onAppear { applyScenePreference() }
          .onChange(of: settingsStore.settings.scenePreference) { _ in
              // 设置变更时若锁定到具体场景则切换，随机则不变
              if let id = settingsStore.settings.scenePreference.sceneID {
                  withAnimation(.easeInOut(duration: 0.3)) { currentSceneID = id }
              }
          }
      }

      private func applyScenePreference() {
          let pref = settingsStore.settings.scenePreference
          if let id = pref.sceneID {
              currentSceneID = id
          } else {
              // .random：每次打开 Popover 随机选一个
              currentSceneID = SceneID.allCases.randomElement()!
          }
      }

      private func switchScene(to id: SceneID) {
          // 点圆点 = 临时覆盖，不写入 scenePreference
          withAnimation(.easeInOut(duration: 0.3)) { currentSceneID = id }
      }

      private func cycleScene(forward: Bool) {
          let all = SceneID.allCases
          guard let idx = all.firstIndex(of: currentSceneID) else { return }
          let next = forward
              ? all[(idx + 1) % all.count]
              : all[(idx + all.count - 1) % all.count]
          withAnimation(.easeInOut(duration: 0.3)) { currentSceneID = next }
      }
  }

  // MARK: - SceneWithRobot

  private struct SceneWithRobot: View {
      let scene: any HabitatScene
      let viewModel: PetViewModel
      let frame: Int

      var body: some View {
          GeometryReader { geo in
              Canvas { ctx, size in
                  scene.drawBackground(ctx, size: size, frame: frame)
              }
              let center = scene.robotCenter(for: viewModel.state, in: geo.size)
              let floatOffset: CGFloat = scene.id == .underwater
                  ? 3.0 * sin(Double(frame % 40) / 40 * .pi * 2)
                  : 0
              BitBotV2Renderer(
                  skin: viewModel.activeSkin,
                  state: viewModel.state,
                  frame: frame,
                  size: 60
              )
              .position(x: center.x, y: center.y + floatOffset)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
  }

  // MARK: - SceneDotNav

  private struct SceneDotNav: View {
      let scenes: [SceneID]
      let current: SceneID
      let onSelect: (SceneID) -> Void

      var body: some View {
          HStack(spacing: 4) {
              ForEach(scenes, id: \.self) { id in
                  Circle()
                      .fill(id == current ? Color.white : Color.white.opacity(0.35))
                      .frame(width: id == current ? 7 : 5, height: id == current ? 7 : 5)
                      .onTapGesture { onSelect(id) }
              }
          }
          .padding(4)
          .background(Color.black.opacity(0.3))
          .clipShape(Capsule())
      }
  }
  ```

- [ ] **Step 2: 更新 `PopoverView.swift`**

  完整替换 `PopoverView`：

  ```swift
  import SwiftUI

  struct PopoverView: View {
      @ObservedObject var viewModel: PetViewModel
      @EnvironmentObject var settingsStore: SettingsStore
      var onRefresh: () -> Void = {}
      var onConfigureHooks: () -> Void = {}

      var body: some View {
          VStack(spacing: 0) {
              HabitatView(viewModel: viewModel)
                  .environmentObject(settingsStore)

              // 场景到信息区过渡
              Divider()
              LinearGradient(
                  colors: [Color(nsColor: .windowBackgroundColor).opacity(0),
                           Color(nsColor: .windowBackgroundColor)],
                  startPoint: .top, endPoint: .bottom
              ).frame(height: 4)

              ScrollView {
                  if viewModel.visibleClis.isEmpty {
                      EmptyStateView()
                          .padding(20)
                  } else {
                      VStack(spacing: 8) {
                          ForEach(viewModel.visibleClis) { info in
                              CliCardView(info: info)
                          }
                      }.padding(12)
                  }
              }

              Divider()

              HStack {
                  Text("累计 \(fmt(viewModel.totalLifetimeTokens)) tokens")
                      .font(.system(size: 9)).foregroundStyle(.secondary)
                  Spacer()
                  Button { onRefresh() } label: {
                      Image(systemName: "arrow.clockwise")
                          .font(.system(size: 12)).foregroundStyle(.secondary)
                  }.buttonStyle(.plain).help("刷新配额")
                  Button { openSettings() } label: {
                      Image(systemName: "gearshape")
                          .font(.system(size: 13)).foregroundStyle(.secondary)
                  }.buttonStyle(.plain).help("设置")
              }.padding(.horizontal, 12).padding(.vertical, 8)
          }
          .frame(width: 360)
      }

      private func openSettings() {
          NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
      }

      private func fmt(_ n: Int) -> String {
          if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
          if n >= 1_000     { return String(format: "%.0fK", Double(n)/1_000) }
          return "\(n)"
      }
  }

  private struct EmptyStateView: View {
      var body: some View {
          VStack(spacing: 12) {
              Image(systemName: "powerplug.portrait")
                  .font(.system(size: 32)).foregroundStyle(.secondary)
              Text("所有终端已休眠").font(.system(size: 13, weight: .medium))
              Text("在设置中启用至少一个 CLI")
                  .font(.system(size: 11)).foregroundStyle(.secondary)
              Button("打开设置") {
                  NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
              }
              .buttonStyle(.borderedProminent).controlSize(.small)
          }
          .frame(maxWidth: .infinity)
      }
  }
  ```

- [ ] **Step 3: 更新 `PixelPetsApp.swift` 传递 `settingsStore`**

  `AppDelegate.setupPopover()` 中更新：
  ```swift
  popover.contentViewController = NSHostingController(
      rootView: PopoverView(
          viewModel: coordinator.viewModel,
          onRefresh: coordinator.refresh,
          onConfigureHooks: coordinator.registerDetectedHooks
      )
      .environmentObject(coordinator.settingsStore)
  )
  ```

- [ ] **Step 4: 重新生成 Xcode project**

  ```bash
  xcodegen generate
  ```

- [ ] **Step 5: 构建验证**

  ```bash
  xcodebuild -scheme PixelPets -destination "platform=macOS" build 2>&1 | tail -3
  ```
  预期：`** BUILD SUCCEEDED **`，无 error。

- [ ] **Step 6: 运行完整测试**

  ```bash
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" test 2>&1 | tail -3
  ```
  预期：`** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

  ```bash
  git add PixelPets/UI/HabitatView.swift \
          PixelPets/UI/PopoverView.swift \
          PixelPets/App/PixelPetsApp.swift \
          PixelPets.xcodeproj/
  git commit -m "feat: HabitatView — isometric scene + BitBot v2 + dot nav + swipe gesture"
  ```

---

## Task 8: CliCardView 重设计 + QuotaBarView 颜色语义化

**Files:**
- Modify: `PixelPets/UI/CliCardView.swift`
- Modify: `PixelPets/UI/QuotaBarView.swift`

- [ ] **Step 1: 更新 `QuotaBarView.swift`**

  ```swift
  import SwiftUI

  struct QuotaBarView: View {
      let tier: QuotaTier

      private var barColor: Color {
          let used = tier.utilization
          if used < 0.5  { return AgentPalette.quotaGreen }
          if used < 0.8  { return AgentPalette.quotaOrange }
          return AgentPalette.quotaRed
      }

      var body: some View {
          VStack(alignment: .leading, spacing: 3) {
              HStack(spacing: 3) {
                  Text(tier.displayLabel)
                      .font(.system(size: 10, weight: .medium))
                      .foregroundStyle(.primary)
                  if tier.isEstimated {
                      Text("~").font(.system(size: 9)).foregroundStyle(.secondary)
                  }
              }
              GeometryReader { geo in
                  ZStack(alignment: .leading) {
                      Capsule()
                          .fill(AgentPalette.quotaTrack)
                          .frame(height: 4)
                      Capsule()
                          .fill(barColor)
                          .frame(width: geo.size.width * min(tier.utilization, 1.0), height: 4)
                  }
              }.frame(height: 4)
              HStack {
                  Text("\(Int(tier.utilization * 100))%")
                      .font(.system(size: 9, weight: .semibold))
                      .foregroundStyle(.secondary)
                  Spacer()
                  if let d = tier.resetsAt {
                      Text(tier.resetsInString)
                          .font(.system(size: 9))
                          .foregroundStyle(.secondary)
                  }
              }
          }
      }
  }
  ```

- [ ] **Step 2: 更新 `CliCardView.swift`**

  ```swift
  import SwiftUI

  struct CliCardView: View {
      let info: CliQuotaInfo

      private var displayedTiers: [QuotaTier] {
          let priority = [
              info.tiers.first { ["five_hour","rolling","daily"].contains($0.id) },
              info.tiers.first { ["seven_day","weekly"].contains($0.id) }
          ].compactMap { $0 }
          return priority.isEmpty ? Array(info.tiers.prefix(2)) : priority
      }

      var body: some View {
          VStack(alignment: .leading, spacing: 6) {
              // 标题行
              HStack(alignment: .center, spacing: 6) {
                  Text(info.id.displayName)
                      .font(.system(size: 12, weight: .semibold))
                  if !info.planBadge.isEmpty {
                      Text(info.planBadge)
                          .font(.system(size: 10, weight: .medium))
                          .foregroundStyle(.secondary)
                          .padding(.horizontal, 6).padding(.vertical, 1)
                          .background(Color(nsColor: .separatorColor).opacity(0.5))
                          .clipShape(Capsule())
                  }
                  Spacer()
              }

              // 配额区
              if info.isUnavailable {
                  Text(info.unavailableReason ?? "未连接 · 无法读取配额")
                      .font(.system(size: 10))
                      .foregroundStyle(.secondary)
              } else {
                  HStack(alignment: .top, spacing: 10) {
                      ForEach(displayedTiers) { tier in
                          QuotaBarView(tier: tier).frame(maxWidth: .infinity)
                      }
                  }
              }

              // Token 统计
              Text("今日 \(fmt(info.todayTokens)) · 本周 \(fmt(info.weekTokens)) tokens")
                  .font(.system(size: 9))
                  .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
          }
          .padding(12)
          .background(Color(nsColor: .controlBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .overlay(
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                  .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
          )
      }

      private func fmt(_ n: Int) -> String {
          if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
          if n >= 1_000     { return String(format: "%.0fK", Double(n)/1_000) }
          return "\(n)"
      }
  }
  ```

- [ ] **Step 3: 运行完整测试套件**

  ```bash
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" test 2>&1 | tail -3
  ```
  预期：`** TEST SUCCEEDED **`

- [ ] **Step 4: Commit**

  ```bash
  git add PixelPets/UI/CliCardView.swift PixelPets/UI/QuotaBarView.swift
  git commit -m "feat: CliCardView + QuotaBarView redesign — color-semantic progress bar (green/orange/red)"
  ```

---

## Task 9: 菜单栏图标更新 + 最终清理

**Files:**
- Create: `PixelPets/Renderer/BitBotStatusIconRenderer.swift`
- Modify: `PixelPets/App/PixelPetsApp.swift` (图标渲染)
- Delete: `PixelPets/Renderer/BitBotRenderer.swift` (从 Xcode 移除)
- Delete: `PixelPets/UI/PetDisplayView.swift` (从 Xcode 移除)
- Run: `xcodegen generate` (after deleting old files)

- [ ] **Step 1: 创建 `PixelPets/Renderer/BitBotStatusIconRenderer.swift`**

  只渲染机器人头部（16×16 对应 24×18 子网格），避免全身缩放糊图：

  ```swift
  import SwiftUI

  /// 菜单栏专用：只渲染 BitBot v2 的头部正面（16×16 pt）
  struct BitBotStatusIconRenderer: View {
      let skin: AgentSkin
      let state: PetState
      let size: CGFloat

      private let faceProvider = BitBotV2FaceProvider()

      // 头部占 24×28 网格的前 18 行（含天线 + 头部 + 屏幕）
      private let gridW = 24, gridH = 18

      var body: some View {
          Canvas { ctx, sz in
              let scale = sz.width / CGFloat(gridW)
              drawHead(ctx, scale: scale)
              drawFace(ctx, scale: scale)
          }
          .frame(width: size, height: size)
      }

      private func drawHead(_ ctx: GraphicsContext, scale: CGFloat) {
          let body   = AgentPalette.bodyColor(for: skin)
          let light  = AgentPalette.lightColor(for: skin)
          let ant    = AgentPalette.antenna
          let black  = Color.black

          // 天线
          for y in 4...6 {
              ctx.fillPixel(x: 0,  y: y, color: ant, scale: scale)
              ctx.fillPixel(x: 1,  y: y, color: ant, scale: scale)
              ctx.fillPixel(x: 22, y: y, color: ant, scale: scale)
              ctx.fillPixel(x: 23, y: y, color: ant, scale: scale)
          }
          // 头部填充
          for y in 1...17 { for x in 2...21 {
              ctx.fillPixel(x: x, y: y, color: body, scale: scale)
          }}
          // 轮廓
          for x in 2...21 {
              ctx.fillPixel(x: x, y: 0,  color: black, scale: scale)
              ctx.fillPixel(x: x, y: 17, color: black, scale: scale)
          }
          for y in 1...17 {
              ctx.fillPixel(x: 2,  y: y, color: black, scale: scale)
              ctx.fillPixel(x: 21, y: y, color: black, scale: scale)
          }
          // 高光
          for (x, y) in [(3,2),(4,2),(3,3)] {
              ctx.fillPixel(x: x, y: y, color: light, scale: scale)
          }
          // 屏幕边框
          for x in 3...20 {
              ctx.fillPixel(x: x, y: 3,  color: black, scale: scale)
              ctx.fillPixel(x: x, y: 15, color: black, scale: scale)
          }
          for y in 4...14 {
              ctx.fillPixel(x: 3,  y: y, color: black, scale: scale)
              ctx.fillPixel(x: 20, y: y, color: black, scale: scale)
          }
      }

      private func drawFace(_ ctx: GraphicsContext, scale: CGFloat) {
          faceProvider.draw(in: ctx, state: state, frame: 0, scale: scale)
      }
  }
  ```

- [ ] **Step 2: 更新菜单栏图标渲染**

  在 `AppDelegate` 的 `setupStatusItem()` 方法中，将：
  ```swift
  item.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "PixelPets")
  ```
  替换为：
  ```swift
  private func makeStatusIcon(state: PetState) -> NSImage {
      // 只渲染头部（16×16），不使用全身 BitBotV2Renderer 以避免压缩糊图
      let renderer = ImageRenderer(content:
          BitBotStatusIconRenderer(
              skin: coordinator.viewModel.activeSkin,
              state: state,
              size: 16
          )
      )
      renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
      guard let cgImage = renderer.cgImage else {
          return NSImage(systemSymbolName: "sparkles", accessibilityDescription: "PixelPets")!
      }
      let img = NSImage(cgImage: cgImage, size: NSSize(width: 16, height: 16))
      img.isTemplate = false  // 保留彩色状态，不用 template
      return img
  }
  ```

  同时在 `statusItem` 初始化后：
  ```swift
  item.button?.image = makeStatusIcon(state: coordinator.viewModel.state)
  ```

  添加状态变化监听（Combine）：
  ```swift
  coordinator.viewModel.$state
      .receive(on: RunLoop.main)
      .sink { [weak self] state in
          self?.statusItem?.button?.image = self?.makeStatusIcon(state: state)
      }
      .store(in: &cancellables)
  ```

- [ ] **Step 2: 删除旧文件并重新生成 Xcode project**

  ```bash
  rm PixelPets/Renderer/BitBotRenderer.swift
  rm PixelPets/UI/PetDisplayView.swift
  xcodegen generate
  ```
  XcodeGen 在文件不存在后自动从 project 中移除引用。
- [ ] **Step 3: 运行完整测试套件**

  ```bash
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" test 2>&1 | tail -3
  ```
  预期：`** TEST SUCCEEDED **`

- [ ] **Step 4: 完整构建验证**

  ```bash
  xcodebuild -scheme PixelPets -destination "platform=macOS" build 2>&1 | tail -3
  ```
  预期：`** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

  ```bash
  git add -A
  git commit -m "feat: menu bar icon v2 + remove legacy BitBotRenderer and PetDisplayView"
  ```

---

## Task 10: AppCoordinatorTests 更新 + 验收检查

**Files:**
- Modify: `PixelPetsTests/AppCoordinatorTests.swift`

- [ ] **Step 1: 更新 AppCoordinatorTests**

  将 `AppCoordinatorTests.swift` 替换为：

  ```swift
  import XCTest
  @testable import PixelPets

  @MainActor
  final class AppCoordinatorTests: XCTestCase {

      func test_detectedGeminiPlaceholderWaitsForRealQuota() {
          let result = AppCoordinator.detectedPlaceholderFetchResult(for: .gemini)
          guard case .unavailable(let reason) = result else {
              return XCTFail("Gemini detected placeholder should not expose estimated quota")
          }
          XCTAssertEqual(reason, "正在读取配额")
      }

      func test_detectedOpenCodePlaceholderWaitsForRealQuota() {
          let result = AppCoordinator.detectedPlaceholderFetchResult(for: .opencode)
          guard case .unavailable(let reason) = result else {
              return XCTFail("OpenCode detected placeholder should not expose estimated quota")
          }
          XCTAssertEqual(reason, "正在读取配额")
      }

      func test_allSceneIDs_haveRegisteredScene() {
          // 确定性测试：每个 SceneID 都能得到正确的场景实例
          for id in SceneID.allCases {
              let scene = SceneRegistry.scene(for: id)
              XCTAssertEqual(scene.id, id, "SceneRegistry missing scene for \(id)")
          }
      }

      func test_randomScene_idBelongsToAllCases() {
          // randomScene 只需验证返回值属于 allCases，不测分布
          let scene = SceneRegistry.randomScene()
          XCTAssertTrue(SceneID.allCases.contains(scene.id))
      }
  }
  ```

- [ ] **Step 2: 运行完整测试套件（最终验收）**

  ```bash
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" test 2>&1 | grep -E "Test Suite.*passed|Test Suite.*failed|SUCCEEDED|FAILED"
  ```
  预期：所有套件 passed，0 failures。

- [ ] **Step 3: 验收检查**

  ```bash
  # T1: Build passes
  xcodebuild -scheme PixelPets -destination "platform=macOS" build 2>&1 | tail -1
  # 预期: ** BUILD SUCCEEDED **

  # T2: Tests pass
  xcodebuild -scheme PixelPetsTests -destination "platform=macOS" test 2>&1 | tail -1
  # 预期: ** TEST SUCCEEDED **
  ```

- [ ] **Step 4: 最终 commit**

  ```bash
  git add PixelPetsTests/AppCoordinatorTests.swift
  git commit -m "test: update AppCoordinatorTests for v2 + scene randomness coverage"
  ```

---

## 自检清单

| Spec 要求 | 实现任务 |
|-----------|---------|
| SettingsStore 独立文件，JSON，ObservableObject | Task 1 |
| enabledCLIs opt-out 语义 | Task 1 + Task 2 |
| visibleClis 过滤 + 空状态 UI | Task 2 + Task 7 |
| SettingsView 三 Tab | Task 3 |
| hookPort 保留字段 + Settings 只读展示（本期不生效） | Task 3 |
| ScenePreference 枚举 + SceneRegistry 工厂 | Task 4 |
| BitBot v2（24×28，大屏，7状态） | Task 5 |
| AgentPalette v2（4皮肤颜色） | Task 4 |
| 太空站、赛博朋克、星际生活舱、水族箱 | Task 6 |
| HabitatView + AnimationClock 驱动 | Task 7 |
| 圆点导航 + swipe gesture | Task 7 |
| 临时覆盖不写入 scenePreference | Task 7 |
| CliCardView 颜色语义化进度条 | Task 8 |
| Divider + 过渡 fade | Task 7 |
| 菜单栏图标 v2 | Task 9 |
| 旧 BitBotRenderer / PetDisplayView 删除 | Task 9 |
| 测试：SettingsStore, SceneRegistry, enabledCLIs | Task 1/2/4 |
