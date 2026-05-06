# PixelPets — AI Quota Monitor

A lightweight macOS menu-bar app that shows remaining quota for your AI CLI tools at a glance.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Supported Providers

| Provider | Credential Source |
|----------|------------------|
| **Claude** (Anthropic) | macOS Keychain (`Claude Code-credentials`) or `~/.claude/.credentials.json` |
| **Codex** (OpenAI) | `~/.codex/auth.json` (requires `auth_mode: "chatgpt"`) |
| **Gemini** (Google) | `~/.gemini/oauth_creds.json` (auto token refresh supported) |

## Features

- Menu-bar status dot — color reflects overall quota health across all enabled providers
- Per-provider quota cards with up to three time windows: rolling (5h), weekly, monthly
- Configurable refresh interval and low-quota threshold
- Drag to reorder providers; enable/disable per provider
- Zero network traffic beyond quota API calls — no analytics, no telemetry

## Requirements

- macOS 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to regenerate the Xcode project)
- Xcode 16+

## Build

```bash
# Generate Xcode project
xcodegen generate

# Build
xcodebuild -project PixelPets.xcodeproj -scheme PixelPets \
  -destination "platform=macOS" build

# Run tests
xcodebuild -project PixelPets.xcodeproj -scheme PixelPetsTests \
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

Settings are persisted to `~/Library/Application Support/com.pixelpets.app/settings.json`.

## Privacy

All processing is local. See [PRIVACY_NOTE.md](PRIVACY_NOTE.md).

## License

MIT
