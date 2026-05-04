# Production Asset Pack Template

Follow this template to create and import new asset packs into PixelPets.

## 1. Directory Structure
```text
Assets/PixelPets/
├── Scenes/[scene_id]/
│   ├── manifest.json
│   ├── bg.png (360x140)
│   ├── floor.png (optional)
│   └── [state_variants].png
├── Pets/[pet_id]/
│   ├── manifest.json
│   ├── idle.png (24x28 or 32x32)
│   └── [state_frames].png
└── Accessories/[acc_id]/
    ├── manifest.json
    ├── normal.png
    └── active.png
```

## 2. AI Prompt Templates

### Scene (Banner)
> pixel art [theme], 360x140 wide banner, flat perspective, continuous walkable floor at bottom, key details at edges, crisp hard-edged pixel art, no anti-aliasing, limited palette.

### Pet (Sprite)
> tiny pixel art [type] companion, 32x32 sprite, transparent background, 1px black outline, large readable eyes, crisp hard-edged pixel art, no motion blur.

## 3. Manifest Specification (JSON)

### Scene
```json
{
  "id": "my_scene",
  "name": "My Scene Name",
  "logicalSize": { "width": 360, "height": 140 },
  "defaultPetPosition": { "x": 180, "y": 80 },
  "safeArea": { "top": 10, "bottom": 10, "left": 10, "right": 10 },
  "states": {
    "normal": { "bg": "bg.png", "floor": "floor.png" },
    "dim": { "bg": "bg_dim.png", "floor": "floor.png" },
    "alert": { "bg": "bg_alert.png", "floor": "floor.png" }
  }
}
```

### Pet
```json
{
  "id": "my_pet",
  "name": "Pet Name",
  "baseSize": { "width": 32, "height": 32 },
  "states": {
    "idle": "idle.png",
    "thinking": "thinking.png",
    "charging": "charging.png",
    "error": "error.png"
  },
  "anchors": {
    "headTop": { "x": 16, "y": 4 },
    "aboveHead": { "x": 16, "y": -4 },
    "faceCenter": { "x": 16, "y": 14 }
  }
}
```

## 4. Quality Assurance Checklist
1. [ ] **Pixel Alignment**: Images are not blurry (Interpolation: None).
2. [ ] **Transparent Background**: Pets and Accessories have clean transparent edges.
3. [ ] **Anchor Accuracy**: Accessories mount correctly on the pet's head/face/back.
4. [ ] **State Coverage**: Manifest defines at least `normal` (scene) and `idle` (pet).
5. [ ] **File Presence**: All files referenced in manifest exist on disk.
