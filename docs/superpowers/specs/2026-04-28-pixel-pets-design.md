# PixelPets 设计规格文档

**日期**：2026-04-28  
**版本**：v2.0  
**状态**：已审核，待实现  
**参考原型**：`docs/reference/BitBot-Concept-Preview-Final.html`（UI + 动画定稿）

---

## 一、产品定位

macOS 菜单栏原生 App。将用户的 AI CLI 工具订阅额度与用量，具象化为一只有生命、会成长的像素宠物。

| 维度 | 定位 |
|------|------|
| 核心价值 | AI 额度可视化 + 像素宠物陪伴感 |
| 目标用户 | 同时使用多个 AI CLI（Claude Code / Codex / Gemini CLI / OpenCode）的开发者 |
| 首只宠物 | Bit-Bot（小破站机器人）——模块化母机，验证全部架构 |
| 扩展目标 | 第二只宠物开发成本 < 首只的 30% |

---

## 二、视觉与技术标准

### 2.1 像素网格规范

- 菜单栏图标：**16×16 像素**绝对物理网格
- 面板大图：**64×64 像素**（`transform: scale(3)` 放大展示）
- **禁用抗锯齿**：Swift 中使用 `interpolationQuality = .none`（等效 `image-rendering: pixelated`）
- **绝对黑边**：1px 纯黑 `#000000` 轮廓线
- **视觉圆角**：移除四角像素（非 CSS 圆角），实现 Kawaii Look

### 2.2 六层分层渲染架构（顺序不可变）

| 层级 | 名称 | 内容 | 动态性 |
|:---|:---|:---|:---|
| 1 | **Skin** | 基础色 / Agent 渐变填充 | 随 Agent 切换 |
| 2 | **Shading** | 左上角 1px 白色（opacity 0.2）高光 + 右下角 1px 黑色（opacity 0.2）暗部 | 静态，营造立体感 |
| 3 | **Body** | 黑色轮廓与结构线（四角已移除） | 静态 |
| 4 | **Face** | 屏幕 / 表情（12 种状态帧） | 随 Hook 事件切换 |
| 5 | **Accessories** | 配件插槽（耳机、天线、披风等） | 随等级解锁 |
| 6 | **FX** | 环境特效（Zzz、礼花、扫描线、火焰拖影） | 随状态触发 |

> **Swift 实现**：使用 `Canvas` + `TimelineView` 逐层绘制，Retina 屏强制 `nearestNeighbor` 采样。

### 2.3 Agent 配色映射（定稿）

| Agent | 颜色值 | 类型 | 备注 |
|:---|:---|:---|:---|
| **Claude Code** | `#D97757` | 纯色 | Terracotta 橙，白色屏幕 |
| **Gemini CLI** | `conic-gradient(#EA4335, #FBBC05, #34A853, #4285F4, #EA4335)` | 圆锥四色渐变 | 顺时针旋转，模拟星芒感 |
| **Codex** | `linear-gradient(135deg, #7851FB, #2853FF)` | 蓝紫对角渐变 | 基于官方 App 图标取色 |
| **OpenCode** | `#000000` | 纯色 | 纯黑机身，白色屏幕，高对比风格 |

---

## 三、五大种族规划

MVP 实现 Bit-Bot，架构验证后按序扩展。

### 3.1 机器人系 Bit-Bot（MVP 首发）

- **造型**：圆角几何体、金属光泽、机械天线，类复古小电视
- **材质**：Skin 层左上 1px 白色高光 + 右下 1px 半透明黑色，营造 3D 立体感
- **动画特性**：`steps(1)` 机械式位移，屏幕像素流 `0101`，天线信号闪烁
- **变色**：机身整体填充 Agent 色

### 3.2 植物系 Quant-Flora（量子仙人掌）

- **造型**：分形生长结构，顶部带刺或花蕾
- **特殊机制**：Token 消耗相当于"浇水"；长期 Sleeping 会变矮并布满像素灰尘
- **变色**：刺的颜色或顶部花蕾颜色随 Agent 变化

### 3.3 动物系 Logic-Critters（算力猫）

- **造型**：毛绒感、大眼睛、拟人化表情，1px 杂色点模拟皮毛质感
- **动画**：眨眼、伸懒腰、耳朵抖动、高 TPS 时快速奔跑
- **变色**：猫的斑纹随 Agent 变化（Claude 橙斑、Gemini 彩虹尾巴）

### 3.4 史莱姆系 Slime-Blobs（幻色史莱姆）

- **造型**：半透明、Q 弹，内部流动 Token 颗粒，折射感高光
- **特殊机制**：根据 I/O 比例改变形态——Output 多则高瘦，Input 多则扁平
- **动画**：落地"压扁"与弹起、吞噬 Token 块

### 3.5 水母系 Neural-Jelly（神经元水母）

- **造型**：深海发光、半透明触须、悬浮脉冲，伞部边缘动态 Glow
- **动画**：节奏性缩放（脉冲）、触须物理摆动、思考时高频放电
- **变色**：整体发光颜色变化，触须末端带 Agent 特色粒子

---

## 四、双轨机制

### 轨道一：额度用量统计（Quota Track）

**目的**：驱动「打瞌睡」与「苏醒」状态，反映订阅额度的消耗与刷新。

**数据来源**：读取本地 CLI OAuth 凭据 → 调用各家官方 API。

| CLI | 凭据位置 | API 端点 | 返回字段 |
|-----|---------|---------|---------|
| Claude Code | macOS Keychain `"Claude Code-credentials"` 或 `~/.claude/.credentials.json` | `GET https://api.anthropic.com/api/oauth/usage`（`anthropic-beta: oauth-2025-04-20`） | `five_hour.utilization`、`five_hour.resets_at`、`seven_day.*` |
| Codex | `~/.codex/auth.json`（仅 `auth_mode=chatgpt`） | `GET https://chatgpt.com/backend-api/wham/usage` | `rate_limit.primary_window.used_percent`、`reset_at` |
| Gemini CLI | 暂无 OAuth quota API | 日志时间戳推算（`~/.gemini/tmp/*/chats/`） | 近似重置时间 |
| OpenCode Go | workspace OAuth token | OpenCode workspace API（待确认端点） | 滚动/周/月用量 % + 重置时间 |

**状态触发逻辑**：

```
utilization ≈ 100%                            →  「耗尽」状态（区别于普通睡眠）
五小时额度 resets_at 刚过 + utilization 回低   →  Bit-Bot 苏醒，伸懒腰
额度刷新后 > 30 分钟无新请求                   →  Bit-Bot「打瞌睡」
```

**轮询频率**：每 5 分钟查询一次额度 API。

---

### 轨道二：宠物成长（Growth Track）

**目的**：驱动配件解锁、等级升级，提供长期养成感。

**数据来源**：轮询本地日志文件（30 秒间隔）。

| CLI | 日志路径 | 格式 | 解析器来源 |
|-----|---------|------|----------|
| Claude Code | `~/.claude/projects/**/*.jsonl` | JSONL（含 `usage` 字段） | 参考 cc-statistics `SessionParser.swift` |
| Gemini CLI | `~/.gemini/tmp/*/chats/*.json` | JSON | 参考 cc-statistics `GeminiParser.swift` |
| Codex | `~/.codex/sessions/*.jsonl` | JSONL | 参考 cc-statistics `CodexParser.swift` |
| OpenCode | `~/Library/Application Support/opencode/opencode.db` | SQLite（`PartTable.data.tokens`） | 新写只读 SQLite reader |

**成长指标**：累计跨 CLI 总 token 消耗量（绝对值）。

---

## 五、12 种交互状态机

| # | 状态 | 表情（Face） | 动作（Motion） | 特效（FX） | Hook 触发 |
|---|------|------------|--------------|----------|---------|
| 01 | **Idle** | 眨眼 `[ . . ]` | `steps(1)` 垂直悬浮 −1px | 无 | 无任务，额度充沛 |
| 02 | **Thinking** | 代码线 `[ - - ]` | 高频微颤 0.1s | 扫描线 + 天线红绿闪烁 | `UserPromptSubmit` |
| 03 | **Typing** | 滚动字符 `[ >>> ]` | 机械敲击 0.15s | 0/1 像素块弹出 | `PreToolUse` |
| 04 | **Juggling** | 掉落方块 | 左右摇摆 0.4s | Token 方块掉落 | `SubagentStart`（1 个） |
| 05 | **Conducting** | 音符 `♪` | 缩放波动 0.6s | 代码音符 | `SubagentStart`（2+ 个） |
| 06 | **Success** | 大笑 `[ ^▽^ ]` | 360° 旋转 0.6s `steps(4)` | 像素礼花（金色下落） | `Stop`（成功） |
| 07 | **Error** | 眼睛变叉 `[ X X ]` | 剧烈抖动 0.2s | 机身变红 `#EA4335` + 黑烟 | `PostToolUseFailure` |
| 08 | **Sleeping** | 闭线 `[ _ _ ]` | 呼吸变慢 5s 周期 | Zzz 粒子上浮 | 额度刷新后 30 分钟无请求 |
| 09 | **Auth** | 锁头 `@` | 无辜歪头 2s | 透明度呼吸 0.7–1.0 | `PermissionRequest` |
| 10 | **Fast** | 拖影眼 `[ o o ]` | 快速横移 0.08s | 尾部火焰残影 | Token 输出速率极高 |
| 11 | **Searching** | 雷达眼 `[ ◉ ◉ ]` | 横向平移 1s | 扫描线 | `web_search` / `read_file` 工具 |
| 12 | **Evolving** | 进度条 `[ = = ]` | 闪烁重组 0.3s | 全屏透明度闪烁 | Token 达到里程碑 |

---

## 六、成长与配件系统

### 6.1 配件插槽（3 个槽）

| 插槽 | 挂载点 | Lv.1 | Lv.2 | Lv.3 | Lv.4 |
|------|--------|------|------|------|------|
| **头部（Top）** | 机器人头顶 | 萌芽 Sprout | 战术耳机 Headset | 天才光环 Halo | 复古天线 Antenna |
| **背部（Back）** | 机身背面 | 能量电池 Battery | 喷气背包 Jetpack | 赛博披风 Cape | — |
| **随身（Side）** | 机身侧面 | 迷你僚机（实时 TPS） | 悬浮代码云 | — | — |

**特殊解锁**：报错率极高时，有概率解锁「破旧补丁」配件。

### 6.2 成长里程碑（Token 累计）

| 里程碑 | 解锁内容 | 触发动画 |
|--------|---------|---------|
| 500,000 | 头部 Lv.1：萌芽 | Evolving（3 秒） |
| 1,000,000 | 外壳升级 Lv.2 铝合金 | Evolving |
| 2,000,000 | 背部 Lv.1：能量电池 | Evolving |
| 5,000,000 | 外壳升级 Lv.3 钛金 + 随身 Lv.1：迷你僚机 | Evolving |
| 10,000,000（Claude 专属） | 头部 Lv.3：天才光环 | Evolving（加强版） |
| 20,000,000 | 外壳升级 Lv.4 赛博（透明外壳，内部数据流可见） | Evolving |

### 6.3 外壳等级

| 等级 | 门槛 | 外壳视觉 |
|------|------|---------|
| Lv.1 废铁 | 0 | 锈迹斑斑，屏幕偶尔闪屏 |
| Lv.2 铝合金 | 1,000,000 | 干净整洁，小天线出现 |
| Lv.3 钛金 | 5,000,000 | 加喷气背包 |
| Lv.4 赛博 | 20,000,000 | 透明外壳，内部可见流动 token 数据流 |

---

## 七、技术架构

### 7.1 三层双轨架构

```
┌─────────────────────────────────────────────────────────────┐
│                      感知层 (Senses)                         │
│  实时轨：Node.js Hook 脚本 → HTTP POST → NWListener          │
│  数据轨：Swift 文件轮询 (30s) → JSONL/JSON/SQLite 解析       │
│  额度轨：URLSession → 各家 OAuth API (5 分钟间隔)            │
│                       ↓ 标准化 Event                        │
├─────────────────────────────────────────────────────────────┤
│                   核心层 (PetCore)                           │
│  PetStateMachine：维护 PetState（12 种）                     │
│  GrowthEngine：累计 tokens → Level + Accessories            │
│  QuotaMonitor：utilization + resets_at → Sleep/Wake 信号    │
│                       ↓ PetViewModel                        │
├─────────────────────────────────────────────────────────────┤
│                   渲染层 (Renderer)                          │
│  Canvas + TimelineView，nearestNeighbor 采样                │
│  Skin → Shading → Body → Face → Accessories → FX            │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 技术栈

| 组件 | 技术选型 | 参考来源 |
|------|---------|---------|
| macOS App 框架 | Swift + SwiftUI | 原生 |
| 菜单栏图标 | NSStatusItem + Canvas + TimelineView | 原生 |
| 下拉面板 | NSPopover，毛玻璃 `NSVisualEffectView` | 原生 |
| Hook 监听服务器 | Network.framework（NWListener） | 参考 cc-statistics `NotificationServer.swift` |
| Hook 注册脚本 | Node.js（复用 clawd-on-desk 脚本） | clawd-on-desk MIT |
| 日志解析（Claude） | Swift JSONL 解析器 | 参考 cc-statistics `SessionParser.swift` MIT |
| 日志解析（Gemini） | Swift JSON 解析器 | 参考 cc-statistics `GeminiParser.swift` MIT |
| 日志解析（Codex） | Swift JSONL 解析器 | 参考 cc-statistics `CodexParser.swift` MIT |
| 日志解析（OpenCode） | Swift SQLite 只读 reader | 新实现，参考 OpenCode `session.sql.ts` schema |
| 额度 API 查询 | URLSession（HTTPS） | 参考 cc-switch `subscription.rs` 逻辑 |
| 本地数据持久化 | SQLite（`~/.pixelpets/pixelpets.db`） | 存储成长进度、配件解锁状态 |
| 配置文件 | JSON（`~/.pixelpets/settings.json`） | 存储 CLI 管理偏好、皮肤设置 |

### 7.3 Hook 注册位置

| CLI | 配置文件 | Hook 类型 |
|-----|---------|---------|
| Claude Code | `~/.claude/settings.json` | command hooks + HTTP permission hooks |
| Gemini CLI | `~/.gemini/settings.json` | command hooks |
| Codex | `~/.codex/hooks.json` | command hooks |
| OpenCode | `~/.config/opencode/opencode.json` | plugin 集成 |

### 7.4 核心数据结构

```swift
enum PetState {
    case idle, thinking, typing, juggling, conducting
    case success, error, sleeping, auth, fast, searching, evolving
}

struct PetViewModel {
    var state: PetState
    var skin: AgentSkin          // claude / gemini / codex / opencode
    var level: Int               // 1–4
    var accessories: [Accessory]
    var quotaTiers: [QuotaTier]  // 各窗口额度数据
    var totalTokens: Int         // 累计跨 CLI token 数
}

struct QuotaTier {
    var name: String             // "five_hour" / "seven_day" / "rolling" 等
    var utilization: Double      // 0.0–1.0（已用 / 总量）
    var resetsAt: Date?
}
```

### 7.5 扩展协议（第二只宠物无需改动以下之外的代码）

| 协议 | 职责 |
|------|------|
| `FaceProvider` | 提供 12 种状态的表情帧（Canvas 路径 / PNG） |
| `BodyRenderer` | 提供机身渲染逻辑（含 Agent 变色） |
| `MountPointMap` | 定义配件在不同身体上的挂载点坐标 |
| `PhysicsProfile` | 定义种族的物理特性（重力、弹性、透明度） |

---

## 八、下拉面板 UI

### 8.1 整体结构（360px 宽）

```
┌──────────────────────────────────────────┐  360px
│                                          │
│         [Bit-Bot 64×64px 动画]           │  ← 110px 高，居中
│         CLAUDE / 热血程序员               │  ← 10px 灰色性格标签
│                                          │
├──────────────────────────────────────────┤
│ Claude Code                          Pro │  ← 名称 + 计划徽章
│                                          │
│  Current session  │  Weekly              │  ← 两列并排，各占 50%
│  Resets in 1h 22m │  Resets Sun 6:00 PM  │
│  ████░░░░░░  33%  │  █████░░░░░  34%     │
│                                          │
│  今日 2.3M · 本周 8.1M tokens            │  ← 灰色小字
├──────────────────────────────────────────┤
│ OpenCode Go                          Go  │
│  Rolling          │  Weekly              │
│  Resets in 2h 22m │  Resets in 5d 20h   │
│  ██░░░░░░░    7%  │  █████░░░░░  50%     │
│  今日 1.1M · 本周 4.2M tokens            │
├──────────────────────────────────────────┤  ← 底栏
│  全局 今日 3.4M · 累计 42.1M tokens      │  ← 左侧全局统计
│                                       ⚙️ │  ← 右侧齿轮
└──────────────────────────────────────────┘
```

### 8.2 设计细节

| 元素 | 规格 |
|------|------|
| 面板背景 | macOS 原生毛玻璃（`NSVisualEffectView`，`blur(20px)`） |
| 顶部展示区 | 110px 高，居中放置 64×64 宠物动画（`scale(3)`）+ 下方 Agent 性格标签 |
| Agent 性格标签 | 10px 灰色大写字母，格式 `CLAUDE / 热血程序员` |
| CLI 卡片 | 全宽，卡片间 1px 分隔线，默认只显示已检测到的 CLI |
| 进度条列布局 | 左列 Current session / Rolling，右列 Weekly，各占 50% 宽 |
| 进度条标签 | 上方类型名 + 重置倒计时，右侧百分比 |
| 累计用量行 | `今日 X.XM · 本周 X.XM tokens`，灰色小字 |
| 底栏 | 全局今日用量 + 累计 token 数（左）+ 齿轮图标（右） |
| CLI 管理 | 进设置后可手动添加/隐藏 CLI |

### 8.3 进度条颜色（以剩余量计算）

| 剩余额度 | 进度条颜色 | 语义 |
|---------|----------|------|
| **> 40%** | 绿色 `#34A853` | 充足，正常使用 |
| **10–40%** | 黄色 `#FBBC05` | 警告，注意消耗 |
| **< 10%** | 红色 `#EA4335` | 危险，即将耗尽 |
| **已耗尽** | 灰色（Bit-Bot 打瞌睡） | 等待刷新 |

> 百分比以**剩余额度 / 总额度**计算，而非已用量。

---

## 九、MVP 范围

**目标**：全部四个 CLI 接入，Bit-Bot 完整双轨闭环。

| 功能 | 优先级 | 说明 |
|------|--------|------|
| 菜单栏图标（Idle 动画） | P0 | 16×16，`steps(1)` 悬浮 + 眨眼 |
| Hook 接收服务器 | P0 | NWListener 监听本地端口 |
| 全部 4 CLI Hook 注册 | P0 | Claude / Gemini / Codex / OpenCode 全部接入 |
| Agent 变色（4 种皮肤） | P0 | 定稿颜色值，见第二章 |
| 12 种状态完整切换 | P0 | Hook 事件驱动，含精确动画 timing |
| 全部 4 CLI 额度查询 | P0 | Claude + Codex OAuth API；Gemini/OpenCode 推算 |
| Sleeping / Waking 完整逻辑 | P0 | 额度耗尽态 + 刷新后打瞌睡 + 新请求唤醒 |
| 全部 4 CLI 日志解析 | P0 | Token 跨 CLI 累计汇总 |
| 下拉面板完整 UI | P0 | 三区结构，含底栏全局统计，360px |
| Token 累计 + 头部 Slot 首件解锁 | P0 | 500k tokens → 萌芽 + Evolving 动画 |
| 配件系统完整（3 槽位） | P1 | Slot 2 / Slot 3 配件序列 |
| 外壳等级视觉（Lv.1–4） | P1 | 按里程碑自动升级 |
| 第二只宠物 | P2 | 架构验证后 |

---

## 十、扩展性设计

开发第二只宠物**无需修改**的代码：Hook 监听、Token 统计、日志解析、PetCore 状态机、配件解锁逻辑、面板 UI。

**只需实现**：`FaceProvider`（12 种表情帧）、`BodyRenderer`（机身绘制 + 变色）、`MountPointMap`（配件挂载坐标）。

---

## 十一、参考项目

| 项目 | 用途 | License |
|------|------|---------|
| [cc-switch](https://github.com/farion1231/cc-switch) | 额度 OAuth API 查询逻辑、凭据读取方式 | MIT |
| [cc-statistics](https://github.com/androidZzT/cc-statistics) | Swift 日志解析器（Claude/Gemini/Codex） | MIT |
| [clawd-on-desk](https://github.com/rullerzhou-afk/clawd-on-desk) | Hook 注册脚本、事件→状态映射表 | MIT |

---

## 十二、参考文档索引

| 文件 | 用途 |
|------|------|
| `docs/reference/BitBot-Concept-Preview-Final.html` | UI + 动画定稿原型（12 状态、4 皮肤、颜色精确值） |
| `docs/reference/cc-switch-usage-tracking-analysis.md` | 代理层技术参考（路由、Token 解析、计费、数据库 Schema） |
| `docs/reference/PixelPets-Ultimate-Spec.md` | v3.0 终极白皮书（五大种族、扩展协议、视觉标准） |
| `docs/reference/PixelPets-讨论总结.md` | 背景与决策日志（技术选型、创意聚焦） |
