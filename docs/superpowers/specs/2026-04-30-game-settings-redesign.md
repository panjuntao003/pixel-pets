# PixelPets 游戏化设置界面重设计

## 目标

将现有表单式 `SettingsView` 替换为游戏化侧边栏设置界面 `GameSettingsView`，遵循 macOS Tahoe 26 Liquid Glass 设计规范。用户体验从「填表」变为「选角色 → 装备配饰 → 选地图」的游戏流程。

## 核心体验定位

**状态镜子**：宠物实时反映 AI 工作状态（thinking / typing / error...），配饰是 token 积累奖励，场景是用户自由搭配的背景。重点是「实时感知」而非养成游戏。

## 设计规范

### 视觉风格：macOS Liquid Glass

- **侧边栏**：使用 `.glassEffect()` Liquid Glass 材质，浮动、圆角 14px、磨砂透明
- **内容区**：实底背景（不叠加玻璃，遵循 glass-on-glass 禁令）
- **选中态**：系统蓝色描边（Light `#007aff` / Dark `#0a84ff`），谨慎着色
- **圆角嵌套**：遵循 concentric shapes 规则，子元素圆角 = 父圆角 - padding
- **亮暗适配**：侧边栏透明度随系统外观翻转（Light rgba 0.45 / Dark rgba 0.08）
- **文字可达性**：文字始终在实底层，不放在玻璃上方

### 窗口尺寸

520 × 420（最小尺寸），替代现有 380 × 280。侧边栏约 150px，内容区约 360px。

UNIT 卡片网格使用 `LazyVGrid` + `.adaptive(minimum: 80)`，在内容区 360px 宽度下自然排为 4 列，窗口更窄时自动折为 3 列。

## 架构

### 导航结构

4 个标签页，侧边栏导航（类似「系统设置」）：

| 标签 | 图标 | 名称 | 对应功能 |
|------|------|------|----------|
| UNIT | 🤖 | 宠物 | 皮肤选择 + 宠物信息 |
| LOADOUT | 🎒 | 装备 | 配饰装备/卸下 |
| MAP | 🏔 | 场景 | 场景选择 + 预览 |
| SYS | ⚙️ | 系统 | Hook、CLI 开关、重置 |

### 文件结构

```
PixelPets/UI/Settings/
├── GameSettingsView.swift       // 主容器：侧边栏 + 内容区
├── UnitTab.swift                // 宠物选择标签
├── LoadoutTab.swift             // 装备管理标签
├── MapTab.swift                 // 场景选择标签
└── SysTab.swift                 // 系统设置标签
```

现有 `SettingsView.swift` 整体替换（删除）。

## 标签详细设计

### UNIT（宠物）

**布局**：上方 4 列卡片网格 + 下方详情卡

**卡片网格**（4 列 × 1 行）：
- 每张卡片：宠物缩略图（带皮肤对应背景色）、名称、状态标签
- 4 种状态：
  - `● 运行中`（绿色）— 该 AI 工具当前正在工作（通过 Hook 事件判断）
  - `○ 已检测`（灰色）— 已安装但未在工作
  - `已停用`（半透明 + 删除线）— 用户在 SYS 标签中关闭了该 CLI 的检测
  - `未检测`（半透明灰化）— 未安装对应 CLI
- 已停用的皮肤不可选择，不响应自动跟随
- 选中卡片蓝色描边

**详情卡**：
- 宠物大图 + 名称 + 个性标签
- 数据行：总 Token / 等级 / 已解锁配饰数
- 「使用中」标签或「设为当前」按钮

**皮肤切换逻辑**：
- 默认自动跟随：检测到哪个 AI 在工作，宠物自动切换为对应皮肤
- 用户可手动覆盖：点击其他已检测的皮肤卡片，手动锁定该皮肤
- 手动锁定持续有效，直到用户点击「自动跟随」按钮恢复自动模式
- 锁定状态下，详情卡顶部显示醒目提示条：「🔒 已锁定为 [皮肤名] · 点击恢复自动跟随」
- `AppSettings` 新增 `skinOverride: String?`（nil = 自动跟随，非 nil = 锁定指定皮肤）

**多 AI 同时工作时的优先级**：
- 当多个 AI 同时发送 Hook 事件时，以最近一次收到事件的 AI 为准（last-write-wins）
- `PetStateMachine` 已有 `lastHookEvent` 时间戳，扩展为记录对应的 `AgentSkin`

### LOADOUT（装备）

**布局**：上方已装备区 + 下方全部配饰网格

**已装备区**（3 个槽位水平排列）：
| 槽位 | 对应 AccessorySlot | 说明 |
|------|---------------------|------|
| 头顶 | `.top` | sprout / headset / halo / antenna |
| 背部 | `.back` | battery / jetpack / cape |
| 旁边 | `.side` | minidrone / codecloud |

- 已装备槽位：蓝色描边，显示配饰图标 + 名称
- 空槽位：虚线边框，显示「＋」图标

**全部配饰网格**（5 列）：
- 3 种状态：
  - `装备中`（蓝框蓝底）— 当前已装备
  - `已解锁`（绿色文字）— 可点击装备
  - `锁定`（灰化 + 显示 token 阈值）— 尚未达到解锁条件
- 点击已解锁配饰 → 装入对应槽位（如槽位已有，替换）
- 点击已装备配饰 → 卸下

**数据模型变更**：

`AppSettings` 新增字段：

```swift
var equippedAccessories: [String: String] = [:]
// key: AccessorySlot.rawValue, value: Accessory.rawValue
```

现有 `GrowthEngine.compute()` 继续负责计算解锁列表，但不再自动全部佩戴。用户从解锁列表中手动选择装备。

**数据迁移**：`equippedAccessories` 和 `skinOverride` 均使用 `decodeIfPresent`（与现有字段一致），缺失时返回空字典 / nil。无需迁移脚本——旧 settings.json 加载后，所有槽位默认为空，用户首次打开 LOADOUT 时自行装备。

### MAP（场景）

**布局**：上方场景预览 + 下方场景缩略图网格

**场景预览区**：
- 80px 高横幅，使用现有 `HabitatScene.drawBackground()` 动态渲染（Canvas，非静态图片）
- 渲染尺寸固定为 360×80，frame 固定为 0（静态帧，不消耗动画性能）
- 下方一行显示场景名称 + 描述 + 「使用中」标签

**场景网格**（2 列）：
- 每张场景卡：缩略色块背景 + emoji 图标 + 场景名称
- 选中蓝框高亮
- 点击切换，预览区即时更新

**现有场景**（4 个）：
| SceneID | 名称 | 描述 |
|---------|------|------|
| spaceStation | 太空站工作台 | 默认科技感场景 |
| cyberpunkLab | 赛博朋克实验室 | 高能工作场景 |
| sciFiQuarters | 星际生活舱 | 温和休息场景 |
| underwater | 像素水族箱 | 放松状态场景 |

保留 `ScenePreference.random` 选项，在网格顶部作为特殊卡片展示。

### SYS（系统）

**布局**：标准 macOS Form 分组，不做特殊游戏化处理

**分组内容**：
1. **AI 工具检测** — 4 个 `AgentSkin` 的 Toggle 开关（从现有 GeneralSettingsTab 移入）
   - 关闭某个 AI 的 Toggle 后，UNIT 标签中该卡片变为「已停用」状态
   - 如果当前 `skinOverride` 指向被停用的皮肤，自动清除 override 回到自动跟随
2. **Hook 服务器** — 端口显示（15799）+ 「重新注册 Hook」按钮
3. **重置** — 「重置所有设置」按钮 + 确认弹窗

## SwiftUI 实现要点

### Liquid Glass 侧边栏

```swift
// 侧边栏容器
List(selection: $selectedTab) {
    Label("宠物", systemImage: "cpu")
        .tag(SettingsTab.unit)
    Label("装备", systemImage: "backpack")
        .tag(SettingsTab.loadout)
    Label("场景", systemImage: "mountain.2")
        .tag(SettingsTab.map)
    Label("系统", systemImage: "gearshape")
        .tag(SettingsTab.sys)
}
.listStyle(.sidebar)
.glassEffect()
```

macOS Tahoe 26 的 `NavigationSplitView` + `.listStyle(.sidebar)` 默认带 Liquid Glass 效果，无需手动模拟。

### 配饰装备交互

```swift
// 点击配饰卡片
func toggleAccessory(_ accessory: Accessory) {
    let slot = accessory.slot.rawValue
    if settingsStore.settings.equippedAccessories[slot] == accessory.rawValue {
        // 已装备 → 卸下
        settingsStore.update { $0.equippedAccessories.removeValue(forKey: slot) }
    } else {
        // 未装备 → 装入（替换同槽位的）
        settingsStore.update { $0.equippedAccessories[slot] = accessory.rawValue }
    }
}
```

## 对现有代码的影响

| 文件 | 变更 |
|------|------|
| `SettingsView.swift` | 删除，替换为 `GameSettingsView.swift` |
| `AppSettings` | 新增 `equippedAccessories` 和 `skinOverride` 字段 |
| `SettingsStore` | 新增 `equippedAccessories` 解码/编码 |
| `AccessorySlot` | 新增 `rawValue`（如尚未实现 `String` 原始值）|
| `PetViewModel` | `accessories` 属性改为从 settings 读取已装备列表 |
| `BitBotV2Renderer` | 新增 `drawAccessory()` 层（独立任务，不在本 spec 范围内）|
| `PopoverView` 或 `App` | 打开设置时改为呈现 `GameSettingsView` |

## 边界情况

| 场景 | 处理 |
|------|------|
| 所有 AI 未检测到 | UNIT 显示 4 张灰化卡片，详情卡显示 BitBot 默认形态（claude 皮肤），提示「未检测到任何 AI 工具」 |
| skinOverride 指向的皮肤被 SYS 停用 | 自动清除 override，回退到自动跟随 |
| equippedAccessories 中的配饰不在解锁列表中（降级场景） | 渲染时忽略该槽位，LOADOUT 显示为空槽 |
| Hook 服务器离线 | SYS 标签 Hook 状态显示红色指示灯，不影响其他标签功能 |

## 不在本 spec 范围内

- 配饰的像素渲染（`drawAccessory`）— 单独任务
- 新宠物种族（A06-A10）— 当前只有 BitBot 机器人
- 新场景（B05-B08）— 当前只有 4 个场景
- 宣传图 / App Store 截图
- 进化动画触发接线

## 部署要求

- **最低系统版本提升至 macOS 26 (Tahoe)**，利用原生 Liquid Glass API（`.glassEffect()` / `NavigationSplitView` 自动 Glass 侧边栏）
- 现有项目目标为 macOS 13+，本次改动将 deployment target 升级至 macOS 26
- 理由：Liquid Glass 是 macOS 26 独占 API，无法在旧系统上 polyfill；项目尚未发布，无存量用户需要兼容
