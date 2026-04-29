# PixelPets 视觉重设计 + 设置功能 — 设计文档

> 日期：2026-04-29  
> 审查方：DeepSeek V4 Pro、Gemini 3.1 Pro（2026-04-29 已回应并更新）

---

## 目标

1. **视觉重设计**：全新机器人形象 + 等距科幻场景 + macOS 原生信息区
2. **设置功能完善**：独立 `SettingsStore.swift`、CLI 开关、Hook 端口、场景偏好

---

## 一、机器人形象（BitBot v2）

### 造型规格

- 基础网格：**24×28 px**（比 v1 的 16×16 更高，以容纳大屏和手臂）
- 渲染尺寸：×3 放大 = 72×84 px，在 140px 高场景区内居中显示
- 风格：像素画（`image-rendering: pixelated`），硬边无抗锯齿
- **v1 `BitBotFaceProvider` 直接删除，v2 全面替代，无备用切换机制**

### 结构层（SwiftUI Canvas 绘制顺序）

| 层 | 内容 |
|----|------|
| 0 | 场景背景（独立 View，与机器人解耦） |
| 1 | 机身底色（按 AgentSkin 换色） |
| 2 | 明暗阴影（左上高光 + 右下阴影） |
| 3 | 轮廓线 + 结构（头框、身体、腿、手臂） |
| 4 | 侧天线（左右各一，蓝色 `#5DADE2`） |
| 5 | 大脸屏（占头部 80%，黑色背景，显示表情） |
| 6 | 表情像素（由 `BitBotV2FaceProvider` 根据 `PetState` + `frame` 驱动） |
| 7 | 配件（帽子、徽章等，成长解锁） |
| 8 | FX（升级星星、ZZZ 气泡、代码粒子） |

### 四种 AI 工具皮肤

| 皮肤 | 机身主色 | 高光色 | 阴影色 |
|------|---------|--------|--------|
| Claude | `#D4884A`（橙棕） | `#E8A870` | `#A06030` |
| OpenCode | `#2D4A3E`（深绿黑） | `#3D6A5A` | `#1A2E26` |
| Gemini | `#4A7ABF`（蓝） | `#6A9ADF` | `#2A5A9F` |
| Codex | `#C8C8D8`（银白） | `#E8E8F0` | `#A8A8C0` |

### 状态 × 表情 × 动作

> **帧率基准：所有"N 帧"均以 30fps 计算。** 例：60 帧 = 2 秒，30 帧 = 1 秒。

| PetState | 屏幕表情 | 动作 | 特效 |
|----------|---------|------|------|
| `working` | 绿色双眼 `▪▪`，底部代码滚动线 | 手臂微微前伸，每 8 帧切换"打字"姿势 | 屏幕绿色脉冲 |
| `thinking` | 蓝色双眼，屏幕中心旋转三点 `···` | 头部左倾 3px，每 40 帧摆回 | 无 |
| `idle` | 黄色笑眼 `◉◉` + 弧形嘴 | 每 60 帧（2秒）左右晃动 2px，偶尔看向舷窗 | 无 |
| `sleep` | 闭眼横线 `— —` | 站立微晃，屏幕逐渐变暗 | 小 `z` 气泡每 80 帧飘出 |
| `exhausted` | 屏幕全暗，仅显示 `□□` | 躺入充电舱/休眠舱动画（优先级最高，打断其他状态） | `Z Z Z` 大气泡持续飘 |
| `celebrating` | 星星眼 `★★` + 大笑嘴 | 每 15 帧跳起 4px，落回 | 4 颗星形粒子从头顶散射 |
| `error` | 红色 X 眼 `✕✕` | 身体微颤（每 4 帧左右 1px） | 屏幕红色闪烁 |

**状态防抖：** `working` 状态最小维持 800ms（24 帧），避免毫秒级脚本调用造成闪烁。`exhausted` 拥有最高打断优先级。已在 `PetStateMachine` 中实现，此处记录意图。

### FaceProvider 接口

```swift
protocol FaceProvider {
    func draw(in ctx: GraphicsContext, state: PetState, frame: Int, scale: CGFloat)
}

// v2 实现，替代旧版 BitBotFaceProvider
struct BitBotV2FaceProvider: FaceProvider { ... }
```

---

## 二、场景系统（HabitatScene）

### 架构

```
HabitatView                          ← 持有单一 AnimationClock（30fps）
├── HabitatSceneRenderer             ← 接收 (SceneID, PetState, frame)，纯渲染
│   └── 由 SceneRegistry 根据 SceneID 路由到具体实现
│       ├── SpaceStationScene
│       ├── CyberpunkLabScene
│       ├── SciFiQuartersScene
│       ├── UnderwaterScene
│       └── (未来) NebulaLabScene / EcoDomeScene
└── BitBotRenderer (v2)              ← 覆盖在场景上，位置由 robotPosition 决定
```

**依赖隔离原则：** `HabitatScene` 的实现只接收 `PetState` 和 `SceneID`（枚举），不持有 `SettingsStore` 引用。单向数据流由 `HabitatView` 负责注入。

**渲染暂停：** `HabitatView` 的 `AnimationClock`（`TimelineView`）绑定 Popover 显示状态。Popover 关闭时 `isAnimating = false`，彻底冻结场景帧循环，避免后台 CPU 唤醒。菜单栏图标保持事件驱动更新（不使用 `TimelineView`）。

### HabitatScene 协议

```swift
protocol HabitatScene {
    var id: SceneID { get }
    var displayName: String { get }
    // origin: 场景区左上角 (0, 0)，与 SwiftUI Canvas 坐标系一致
    func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int)
    func robotPosition(for state: PetState, in size: CGSize) -> CGPoint
}
```

**坐标约定：** `robotPosition` 返回的 `CGPoint` 以场景区**左上角为原点**，单位为 pt（与 SwiftUI Canvas 一致）。

### 场景注册表（SceneRegistry）

```swift
enum SceneID: String, CaseIterable, Codable {
    case spaceStation   = "space_station"
    case cyberpunkLab   = "cyberpunk_lab"
    case sciFiQuarters  = "scifi_quarters"
    case underwater     = "underwater"
    // 未来扩展
    case nebulaLab      = "nebula_lab"
    case ecoDome        = "eco_dome"
}

struct SceneRegistry {
    static func scene(for id: SceneID) -> any HabitatScene {
        switch id {
        case .spaceStation:  return SpaceStationScene()
        case .cyberpunkLab:  return CyberpunkLabScene()
        case .sciFiQuarters: return SciFiQuartersScene()
        case .underwater:    return UnderwaterScene()
        default:             return SpaceStationScene()
        }
    }
}
```

`ScenePreference` 直接使用 `SceneID`，消除字符串散落。

### 四个优先场景

#### 1. 太空站（SpaceStationScene）
- **背景**：深蓝黑渐变，20 颗随机星点（每颗有独立闪烁周期，以 `frame % (40..80)` 随机化）
- **等距地板**：深蓝菱形格，`#1A2A4A`
- **左墙**：全息终端（蓝色发光边框，屏幕有滚动代码线，每 4 帧下移 1px）
- **右墙**：圆形舷窗，外部橙色星球每 300 帧转 1°
- **状态位置**：`working` → 终端前；`idle` → 舷窗旁；`exhausted` → 右角充电柱

#### 2. 赛博朋克实验室（CyberpunkLabScene）
- **背景**：极暗紫黑，霓虹环境光（左 `#FF00FF`、右 `#00FFFF` 径向晕）
- **等距地板**：暗色菱形格 + 反光条
- **左墙**：霓虹招牌（`#FF00FF` 边框），以 `frame % 47` 随机闪烁
- **右墙**：服务器机架，三行指示灯交替闪烁（青/粉/青，每 12 帧循环）
- **地板**：全息投影圆盘，`working` 时激活（蓝紫色光圈每 30 帧扩散一次）
- **状态位置**：`working` → 投影台前；`idle` → 机架旁靠着；`exhausted` → 左角暗处蜷缩

#### 3. 星际生活舱（SciFiQuartersScene）
- **背景**：深蓝渐变，顶部蓝白环境光
- **等距地板**：浅灰蓝面板，有分缝线
- **左墙**：大型全景舷窗，外部橙红色星云（每 180 帧漂移 1px），窗框蓝色发光
- **右墙**：充电站（竖型金属柱，顶部指示灯，`exhausted` 时蓝灯亮起）
- **装饰**：悬浮植物盆栽（每 120 帧上下 2px 浮动）
- **状态位置**：`working` → 悬浮桌前；`idle` → 舷窗旁坐下；`exhausted` → 充电站内

#### 4. 像素水族箱（UnderwaterScene）
- **背景**：蓝绿渐变，3 条水面光波斜线（每帧微移）
- **底部**：像素珊瑚（橙/粉/绿，高低错落）
- **动画**：气泡每 30 帧从随机底部位置出发上升；小鱼每 200 帧从右向左游过
- **机器人**：头部加氧气罩 overlay，缓慢漂浮（每 40 帧 ±3px）
- **状态位置**：`working` → 操控台前；`idle` → 中部漂浮；`exhausted` → 沉底趴着

### 场景切换 UI

- 场景区**右下角**：小圆点导航，当前场景实心白，其余半透明
- 点击圆点 = **本次会话临时覆盖**，不写入 `scenePreference` 设置，重启后仍以设置为准
- 支持水平 **trackpad 双指滑动**切换场景（同圆点导航语义）
- 切换时 0.3s 淡入淡出过渡
- **默认行为**：每次启动 app 从 `scenePreference` 读取；若为 `.random`，从全部场景中随机选一个

---

## 三、弹窗整体布局（PopoverView 重构）

```
┌─────────────────────────────────┐  360px 宽
│  HabitatView (等距场景+机器人)   │  140px 高，场景始终深色（设计意图）
│  [activeSkin badge]  [● ○ ○ ○] │
├── 1px Divider ─────────────────┤  + 场景底部 4px 渐变 fade，自然过渡到信息区
│  ScrollView                     │  ~300px（弹性）
│  ┌─────────────────────────┐   │
│  │ CliCardView × N         │   │  仅显示 enabledCLIs 中为 true 的 CLI
│  │ （全禁用时显示空状态）    │   │
│  └─────────────────────────┘   │
├─────────────────────────────────┤
│  [累计 X tokens]       [↺] [⚙] │  36px
└─────────────────────────────────┘
```

**当前 AI badge：** 显示 `viewModel.activeSkin` 对应的 CLI 名称，由最近一次 hook 事件决定。

**累计 token：** 底部显示所有 CLI 自 `installedAt` 起的汇总 token 数。CliCardView 内的 today/week 统计仅针对单个 CLI。

**全 CLI 禁用空状态：** 当 `visibleClis` 为空时，ScrollView 区域显示：
```
[机器人图标] 所有终端已休眠
             在设置中启用至少一个 CLI
             [打开设置]
```

### CliCardView 重设计（macOS 原生）

- 背景：`NSColor.controlBackgroundColor`，圆角 10px
- 进度条颜色语义（轨道 `#E5E5EA`，高度 4px，圆角）：
  - `< 50%`：`#34C759`（绿）
  - `50–80%`：`#FF9500`（橙）
  - `> 80%`：`#FF3B30`（红）
- tier 标签：10px 灰色（"Current session" / "Weekly" / "Pro" / "Flash Lite" 等）
- 重置时间：10px 灰色，`resetsAt` 格式化
- token 统计：9px 浅灰，「今日 2.3M · 本周 8.1M」

**视觉信噪比原则：** 进度条颜色和场景区机器人是唯一的视觉重点；token 文字、plan badge 等退居次级，使用低饱和度灰度字色。

---

## 四、设置功能（SettingsStore + SettingsView）

### SettingsStore.swift（独立文件）

```swift
@MainActor
final class SettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings

    private let path: String

    init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".pixelpets").path
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)
        self.path = dir + "/settings.json"
        // 任何读取/解码失败均 fallback 到默认值，静默处理
        if let data = FileManager.default.contents(atPath: path),
           let s = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = s
        } else {
            self.settings = AppSettings()
        }
    }

    func update(_ block: (inout AppSettings) -> Void) {
        block(&settings)
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        FileManager.default.createFile(atPath: path, contents: data)
    }
}

struct AppSettings: Codable {
    var hookPermissionAsked: Bool = false
    // 空字典 = opt-out 模式：未出现在字典中的 CLI 视为已启用
    // 仅当 value == false 时隐藏对应 CLI 卡片
    var enabledCLIs: [String: Bool] = [:]
    var hookPort: UInt16 = 15799
    // 使用 SceneID 作为场景偏好，消除字符串散落
    var scenePreference: ScenePreference = .random
}

enum ScenePreference: String, Codable, CaseIterable {
    case random
    case spaceStation   = "space_station"
    case cyberpunkLab   = "cyberpunk_lab"
    case sciFiQuarters  = "scifi_quarters"
    case underwater     = "underwater"
}
```

**`enabledCLIs` 过滤逻辑：**
```swift
// visibleClis 过滤：未出现 = 启用；显式 false = 禁用
var visibleClis: [CliQuotaInfo] {
    cliInfos.filter { info in
        let key = info.id.rawValue
        return settingsStore.settings.enabledCLIs[key] != false && info.isDetected
    }
}
```

**`hookPort` 修改行为：** 仅持久化存储，不自动重启 hook server。修改后用户须手动点击"重新注册 Hook"按钮生效。

### SettingsView（macOS Settings 窗口）

通过 `Settings { SettingsView() }` 接入，`Cmd+,` 可打开，macOS 13+ 自动渲染为工具栏式 Tab。

**Tab 1 — 通用**
- 各 CLI 开关（图标 + 名称 + Toggle），对应 `enabledCLIs`
- 设置变更即时生效（`@Published` 驱动 SwiftUI 刷新）

**Tab 2 — 场景**
- `ScenePreference` Picker（随机 / 各场景名）
- 每个选项旁有 20×14px 像素缩略预览

**Tab 3 — 高级**
- Hook 端口（TextField，默认 15799）
- "重新注册 Hook" 按钮（若权限从未授权，触发权限申请流程）
- "重置所有设置" 按钮（二次确认 Alert）

---

## 五、菜单栏图标

- 尺寸：16×16 px
- 内容：BitBot v2 头部正面（大屏 + 侧天线），不含身体
- 颜色状态（非 Template 模式，保留彩色）：
  - `working`：屏幕亮绿色 `#34C759`
  - `exhausted`：屏幕暗灰 `#636366`
  - 其余：屏幕蓝白 `#5DADE2`
- Fallback：使用 SF Symbol `sparkles` 占位，待像素图标完成后替换
- 注意：因需保留色彩状态，**不使用 `isTemplate = true`**（模板模式会强制变为单色）

---

## 六、测试策略（Phase A 新增）

| 测试类 | 覆盖内容 |
|--------|---------|
| `SettingsStoreTests` | JSON 序列化/反序列化、损坏文件 fallback、update() 持久化 |
| `SceneRegistryTests` | 所有 `SceneID` 都有对应实例，无缺失分支 |
| `VisibleClisFilterTests` | enabledCLIs 空字典=全显示；显式 false=隐藏；全 false=空状态 |
| `PetStateMachineTests`（已有，扩展） | working 状态防抖 800ms |

---

## 七、实现优先级

### Phase A（本次实现）
1. `SettingsStore.swift` 独立文件（ObservableObject + JSON）
2. `SettingsView`（三 Tab）
3. `enabledCLIs` 接入 `visibleClis` 过滤 + 空状态 UI
4. `BitBotRenderer` v2（24×28，大屏，手臂，新状态表情）
5. `HabitatView` + `SceneRegistry` + `HabitatScene` 协议
6. **4 个场景**（太空站、赛博朋克、星际生活舱、水族箱）
7. 场景切换 UI（圆点 + trackpad 滑动 + 随机逻辑）
8. `CliCardView` 重设计（颜色语义进度条）
9. 菜单栏图标更新

### Phase B（后续扩展）
- 星云实验室、生态穹顶场景
- 更多配件解锁
- 场景内小鱼/NPC 丰富化

---

## 八、不在本次范围

- 场景编辑器（用户自定义布局）
- 声音效果
- iCloud 同步
- i18n / 多语言（当前仅中文）
- App Sandbox（app 需访问 `~/.claude` 等系统目录，不启用沙盒）
