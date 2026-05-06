# Privacy Note

PixelPets reads only what it needs to display quota status. Nothing is stored or transmitted beyond your machine.

## What the app reads

- **Quota APIs** — each provider's usage endpoint, using the credentials already stored by the CLI tool you installed. The app makes the same API call you would make manually.
- **Local credential files / Keychain** — read-only. The app never writes to these files.

## What the app does NOT do

- Does not read prompt text, response text, code, or file contents.
- Does not record keystrokes or screen activity.
- Does not send analytics, crash reports, or telemetry anywhere.
- Does not modify any credential file or Keychain entry.

## Where data is stored

Settings (enabled providers, refresh interval, low-quota threshold) are written to:

```
~/Library/Application Support/com.pixelpets.app/settings.json
```

No quota data is persisted to disk. Each launch starts with a fresh fetch.

## Network

The only outbound connections are the provider quota API calls listed in the README. There are no background services, no update checks, and no third-party SDKs.
