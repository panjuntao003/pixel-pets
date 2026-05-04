# Pixel Pets Privacy Note

PixelPets is designed as a low-impact, secure companion. Your data and privacy are paramount.

## 1. Minimal Data Access (Metadata Only)
- The system only reads **activity metadata** from AI tool logs (e.g., "Claude started a request", "OpenCode received a response").
- We **NEVER** read or save:
    - User Prompt content.
    - AI Response text.
    - Code fragments or file contents.
    - File paths or project names.
    - API Keys, credentials, or session tokens.

## 2. No Active Monitoring
- PixelPets does **NOT** listen to keyboard inputs.
- PixelPets does **NOT** record screen activity.
- Events are derived from existing tool logs or local TCP hooks provided by the AI tools themselves.

## 3. Local-Only Processing
- All event aggregation and visual rendering happen **locally on your machine**.
- No diagnostics or usage statistics are sent to any remote server.
- Debug information is used exclusively for local development and is only visible when the Debug HUD is manually enabled.

## 4. Open Architecture
- The system uses standard JSON manifests for assets, allowing users to inspect and verify exactly what resources the app is loading.

---
*Pixel Pets: A companion that cares about your flow, not your data.*
