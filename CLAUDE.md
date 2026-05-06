# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 重要约束

**不要自行修改代码，除非用户明确要求你来改。** 分析、建议、解释均可，但写文件/编辑文件需要用户明确授权。

## 项目简介

Quota 是一个 macOS 菜单栏应用，显示 Claude / Codex / Gemini 三个 AI CLI 工具的剩余配额。

## 常用命令

```bash
# 重新生成 Xcode 项目（修改 project.yml 后必须执行）
xcodegen generate

# 构建
xcodebuild -project Quota.xcodeproj -scheme Quota -destination "platform=macOS" build

# 运行全部测试
xcodebuild -project Quota.xcodeproj -scheme QuotaTests -destination "platform=macOS" test

# 运行单个测试类
xcodebuild -project Quota.xcodeproj -scheme QuotaTests \
  -destination "platform=macOS" \
  -only-testing "QuotaTests/QuotaCoordinatorTests" test
```

**注意：** 直接编辑 `.xcodeproj` 是错误的，源码文件增删后必须通过 `xcodegen generate` 重新生成项目文件。

## 架构

### 数据流

```
AppDelegate
  └── QuotaCoordinator          # 定时刷新，管理 QuotaClient 集合
        ├── ClaudeQuotaAdapter  ─┐
        ├── CodexQuotaAdapter   ─┼─ 各自调用 API，返回 ProviderQuotaSnapshot
        └── GeminiQuotaAdapter  ─┘
              └── → QuotaStateStore   # @Published，驱动 UI 更新
                    └── PopoverView / MenuBarDotView
```

### 关键类型

- **`QuotaClient`** (`Senses/QuotaClient.swift`) — protocol，所有 quota 客户端遵守。同文件内包含三个 Adapter 和 `mapQuotaResultToSnapshot()` 工具函数。
- **`ClaudeQuotaClient / CodexQuotaClient / GeminiQuotaClient`** (`Senses/ClaudeQuotaClient.swift`) — 各自读取本地凭据文件，调用对应 API，返回 `QuotaFetchResult`。
- **`ProviderQuotaSnapshot`** (`Models/ProviderQuotaSnapshot.swift`) — 单个 provider 的快照，含 `tiers: [QuotaTier]`、`status`、`remainingPercent`。
- **`QuotaStateStore`** (`Models/QuotaStateStore.swift`) — `@MainActor ObservableObject`，存储所有 provider 的最新快照，计算 `overallStatus`。
- **`SettingsStore`** (`Persistence/SettingsStore.swift`) — 持久化 `AppSettings`（启用的 providers、刷新间隔、低配额阈值），写入 `~/Library/Application Support/com.quota.app/settings.json`。

### 凭据读取路径

| Provider | 凭据位置 |
|----------|---------|
| Claude | Keychain (`Claude Code-credentials`) 或 `~/.claude/.credentials.json` |
| Codex | `~/.codex/auth.json`（需 `auth_mode: "chatgpt"`） |
| Gemini | `~/.gemini/oauth_creds.json`（支持自动 token 刷新） |

### UI 层

- `MenuBarDotView` — 菜单栏圆点，颜色反映 `overallStatus`
- `PopoverView` — 点击菜单栏后弹出，按 `providerOrder` 渲染 `QuotaCardView` 列表
- `QuotaCardView` + `QuotaBarView` — 单个 provider 的配额卡片，优先展示 `five_hour/rolling`、`seven_day/weekly`、`monthly` 三级进度条
- `GameSettingsView` / `QuotaSettingsView` — 设置窗口，通过 `SettingsLink` 打开

## 测试

测试覆盖 `QuotaCoordinator`、`QuotaStateStore`、`SettingsStore`、`ClaudeQuotaClient` 的解析逻辑。网络调用均通过 `MockQuotaClient` 替代，无真实 API 请求。

---

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
