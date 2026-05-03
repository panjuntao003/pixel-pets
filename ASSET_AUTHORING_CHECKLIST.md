# PixelPets 资产创作清单 (Asset Authoring Checklist)

为了确保 AI 生成的资产能稳定接入 PixelPets 系统，请遵循以下规范。

## 1. 基础规范 (General)
- **风格**：硬边像素艺术 (Hard-edged pixel art)，无抗锯齿 (No anti-aliasing)。
- **轮廓**：1px 黑色轮廓 (1px black outline)。
- **背景**：透明 (Transparent)（仅限宠物和配件）。
- **格式**：PNG。

## 2. 场景资产 (Scenes)
- **逻辑尺寸**：360 × 140 px。
- **目录结构**：`Assets/PixelPets/Scenes/[scene_id]/`
- **分层建议**：
  - `bg.png`: 背景层（天空、远景）。
  - `mid.png`: 中景层（建筑、大道具）。
  - `floor.png`: 地面层（宠物站立平面）。
  - `fxBack.png`: 宠物后方的特效层。
  - `fxFront.png`: 宠物前方的特效层。
- **状态变体 (States)**：
  - `normal`: 默认状态。
  - `dim`: 休眠/夜间模式（降低亮度）。
  - `alert`: 错误/警示状态（红色调或闪烁）。
  - `active`: AI 活跃状态（屏幕亮起、粒子增多）。

## 3. 宠物资产 (Pets)
- **尺寸档位**：
  - `compact`: 24 × 28 px。
  - `standard`: 32 × 32 px。
- **目录结构**：`Assets/PixelPets/Pets/[pet_id]/`
- **核心状态 (States)**：
  - `idle.png`: 待机。
  - `thinking.png`: 思考中（眼睛变化、表情）。
  - `charging.png`: 充电/恢复中。
  - `error.png`: 错误状态（X眼、损坏感）。
- **锚点定义 (Anchors)**：需在 `manifest.json` 中定义相对于左上角的像素坐标。

## 4. 配件资产 (Accessories)
- **尺寸**：通常为 16×16, 24×16 或 24×24 px。
- **目录结构**：`Assets/PixelPets/Accessories/[acc_id]/`
- **挂载点 (Mount Points)**：需匹配宠物的 `anchors`。
- **状态变体**：
  - `normal.png`: 默认。
  - `active.png`: 活跃（发光、动效）。

## 5. Manifest 示例 (manifest.json)
每个资产包必须包含 `manifest.json`。

```json
{
  "id": "nebula_bot",
  "name": "Nebula Bot",
  "baseSize": { "width": 24, "height": 28 },
  "states": {
    "idle": "idle.png",
    "thinking": "thinking.png",
    "charging": "charging.png",
    "error": "error.png"
  },
  "anchors": {
    "headTop": { "x": 12, "y": 2 },
    "aboveHead": { "x": 12, "y": -4 }
  }
}
```
