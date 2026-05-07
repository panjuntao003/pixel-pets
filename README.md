# Quota — AI Quota Monitor

A lightweight macOS menu-bar app that shows remaining quota for Claude, Codex, and Gemini at a glance.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
[![Release](https://img.shields.io/github/v/release/panjuntao003/quota)](https://github.com/panjuntao003/quota/releases/latest)

## Install

Download the latest `Quota-x.x.x.dmg` from [Releases](https://github.com/panjuntao003/quota/releases/latest), open it, and drag Quota to Applications.

On first launch macOS may block it — open **System Settings → Privacy & Security** and click **Open Anyway**, or run:

```bash
xattr -cr /Applications/Quota.app
```

On first run, macOS will ask once whether to allow Quota to access your Claude credentials in Keychain. Click **Always Allow** and you won't be asked again.

## Supported Providers

| Provider | Credential source |
|----------|-------------------|
| **Claude** (Anthropic) | Keychain (`Claude Code-credentials`) or `~/.claude/.credentials.json` |
| **Codex** (OpenAI) | `~/.codex/auth.json` (requires `auth_mode: "chatgpt"`) |
| **Gemini** (Google) | `~/.gemini/oauth_creds.json` (auto token-refresh supported) |

Quota reads credentials that your CLI tools have already stored — no separate sign-in needed.

## Features

- Menu-bar status dot — color reflects overall quota health (green / yellow / red)
- Per-provider quota cards with up to three time windows: rolling 5h, weekly, monthly
- Configurable auto-refresh interval (1 min – 30 min) and low-quota alert threshold
- Drag to reorder providers; enable/disable per provider
- Automatic update checks via Sparkle
- No analytics, no telemetry — all processing is local

## Requirements

- macOS 26 or later
- Claude Code, Codex, and/or Gemini CLI already installed and authenticated

## Build from Source

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate Xcode project and build
xcodegen generate
xcodebuild -project Quota.xcodeproj -scheme Quota \
  -destination "platform=macOS" build

# Run tests
xcodebuild -project Quota.xcodeproj -scheme QuotaTests \
  -destination "platform=macOS" test
```

## Architecture

```
AppDelegate
  └── QuotaCoordinator          # periodic refresh, owns QuotaClient collection
        ├── ClaudeQuotaAdapter  ─┐
        ├── CodexQuotaAdapter   ─┼─ each calls its provider API → ProviderQuotaSnapshot
        └── GeminiQuotaAdapter  ─┘
              └── QuotaStateStore   # @Published, drives UI
                    └── PopoverView / MenuBarDotView
```

Settings are persisted to `~/Library/Application Support/com.quota.app/settings.json`.

## License

MIT
