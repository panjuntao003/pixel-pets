# Pixel Pets Release Checklist

Use this checklist to verify that a new version or asset pack is ready for production.

## 1. Core Functionality (Happy Path)
- [ ] App launches with default `galaxy_observatory` and `nebula_bot`.
- [ ] Submitting a prompt in Claude triggers `thinking` (visual sparks).
- [ ] AI output triggers `streaming` (eyes active, accessory high-light).
- [ ] Request completion returns pet to `idle` naturally after debounce.
- [ ] Error in terminal triggers `error` (X eyes, red alert background).

## 2. Asset Integrity (Manifest & Resources)
- [ ] `ManifestValidator` shows green [PASS] for all registered assets.
- [ ] No missing PNG errors in console.
- [ ] All Pet anchors (`headTop`, `aboveHead`) are defined and accurate.
- [ ] State fallbacks work (e.g., if `dim` is missing, `normal` is used).
- [ ] Image interpolation is set to `.none` (crisp pixels).

## 3. Productization & UX
- [ ] **Low Distraction Mode**: High-frequency FX (like sparks) are hidden or slowed.
- [ ] **Reduce Motion**: No alert pulsing, no spring animations, static backgrounds.
- [ ] **Quota Alerts**: Visual red pulse triggers when quota is low.
- [ ] **Crossfade**: Transitions between pet/scene states are smooth, not instant pops.

## 4. Performance & Guardrails
- [ ] **Idle State**: FPS drops or heavy FX pause to save CPU.
- [ ] **Window Hidden**: All rendering/FX paused when the popover is closed.
- [ ] **Memory**: No runaway image caching (check AssetRegistry URL usage).
- [ ] **CPU Usage**: System-wide idle impact < 1% on modern M-series Macs.

## 5. Diagnostics (Debug Mode)
- [ ] Debug HUD shows accurate Provider and Event history.
- [ ] Priority Override logic correctly shows why a state is active (e.g., Error > Thinking).
- [ ] Diagnostics summary can be copied to clipboard.

## 6. Multi-Asset Test (Phase 6 Packs)
- [ ] `underwater_aquarium` displays correctly with `bubble_helmet`.
- [ ] `rooftop_server_garden` displays correctly with `code_cloud`.
- [ ] `repair_workshop` handles the `damaged` variant / `repair_patch` correctly.
