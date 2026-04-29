# PixelPets AI 绘画清单

> 用途：为 PixelPets 生成宠物形象、场景、配饰、动作帧和宣传组合图。  
> 风格核心：硬边像素艺术、低分辨率网格、黑色 1px 轮廓、清晰色块、无抗锯齿、可用于 macOS 菜单栏宠物和 Popover 场景。

## 统一绘画规范

### 通用正向提示词

所有条目都建议在提示词末尾追加：

```text
pixel art sprite, crisp hard edges, no anti-aliasing, 1px black outline, limited color palette, high readability at small size, transparent background for character and accessory assets, orthographic view, clean silhouette, cute but technical, retro sci-fi UI companion, not blurry
```

### 通用反向提示词

```text
photorealistic, 3D render, smooth vector, soft gradients, anti-aliased edges, painterly brush, realistic fur, overly detailed texture, noisy background, tiny unreadable details, text, watermark, logo, signature, low contrast, muddy colors
```

### 输出尺寸建议

| 资产类型 | 建议画布 | 说明 |
| --- | --- | --- |
| 菜单栏小图标 | 16x16 px | 极简剪影，保留脸部和 1 个识别点 |
| 宠物主体 | 24x28 px 或 32x32 px | 与 BitBot v2 接近，可放大 3 倍展示 |
| 动作帧 | 32x32 px sprite sheet | 每个动作 4-8 帧，像素位移使用整数 |
| 配饰 | 16x16 px 或 24x24 px | 透明背景，单独绘制，方便挂载 |
| 场景 | 360x140 px 或 720x280 px | Popover 顶部横幅，等距透视 |
| 宣传图 | 1024x1024 px | 可更精细，但仍保持像素块边界 |

## A. 宠物形象清单

### A01 BitBot v2 基础机器人

- 目标：当前项目核心宠物母机。
- 提示词：

```text
a cute tiny pixel art robot companion named BitBot, 24x28 sprite proportions, rounded square head, big dark screen face taking most of the head, small rectangular body, short arms and legs, side antennas, silver white metal body with subtle blue highlights, 1px black outline, top-left pixel highlight, bottom-right pixel shadow, transparent background, readable at 16x16 menu bar size
```

### A02 Claude Code 皮肤机器人

- 目标：热血程序员性格，橙棕机身。
- 提示词：

```text
pixel art robot companion, terracotta orange and warm brown metal body, big black screen face with golden smiling eyes, tiny side antennas, energetic programmer personality, 24x28 sprite, 1px black outline, crisp pixel edges, small code sparks around the screen, transparent background
```

### A03 Gemini CLI 皮肤机器人

- 目标：赛博法师，多色星芒感但不要糊。
- 提示词：

```text
pixel art robot companion, blue body with small red yellow green blue accent pixels, magical cyber wizard personality, big black screen face with bright cyan eyes and three glowing thinking dots, tiny star pixels near antennas, 24x28 sprite, strict limited palette, 1px black outline, transparent background
```

### A04 Codex 皮肤机器人

- 目标：冷酷分析师，银白机身，蓝紫数据感。
- 提示词：

```text
pixel art robot companion, silver white metal body, blue violet screen glow, calm analytical personality, large dark face screen with focused pixel eyes, minimal clean silhouette, small antenna lights, 24x28 sprite, 1px black outline, sharp pixel art, transparent background
```

### A05 OpenCode 皮肤机器人

- 目标：暗网黑客，深绿黑高对比。
- 提示词：

```text
pixel art robot companion, dark green black metal body, hacker terminal style, big black screen face with neon green eyes and scrolling code lines, high contrast silhouette, tiny antenna, 24x28 sprite, 1px black outline, transparent background, retro terminal mood
```

### A06 Quant-Flora 量子仙人掌

- 目标：植物系备选宠物，可随 Token 浇水成长。
- 提示词：

```text
a cute pixel art quantum cactus pet, 32x32 sprite, small round cactus body with branching arms, tiny pixel thorns, glowing flower bud on top, black 1px outline, matte green body, agent color glow in the flower bud, sleepy cute face, transparent background, crisp hard-edged pixel art
```

### A07 Logic-Critter 算力猫

- 目标：动物系备选宠物，毛绒但仍是像素色块。
- 提示词：

```text
a tiny pixel art coding cat pet, 32x32 sprite, square cute head, oversized pixel eyes, small triangular ears, fluffy tail made from blocky pixels, colored circuit stripe markings, black 1px outline, sitting pose, readable silhouette, transparent background, no realistic fur
```

### A08 Slime-Blob 幻色史莱姆

- 目标：Q 弹形变宠物，内部有 Token 颗粒。
- 提示词：

```text
a cute translucent pixel art slime pet, 32x32 sprite, rounded blob body, chunky pixel highlight, tiny bubbles and token cubes inside, simple happy face, black 1px outline with colored inner glow, squishy silhouette, transparent background, crisp pixel edges
```

### A09 Neural-Jelly 神经元水母

- 目标：深海发光宠物，适合水族箱场景。
- 提示词：

```text
a tiny pixel art neural jellyfish pet, 32x32 sprite, glowing umbrella head, short dangling tentacles like data cables, cyan bioluminescent pixels, simple cute face, black 1px outline, floating pose, transparent background, deep sea sci-fi companion style
```

### A10 Micro-Drone 迷你僚机宠物

- 目标：随身小跟班，可作为 side accessory 或独立宠物。
- 提示词：

```text
a tiny pixel art assistant drone, 16x16 sprite, round central eye screen, two small propeller pods, black 1px outline, cyan status light, cute helper personality, transparent background, clean readable silhouette at menu bar size
```

## B. 场景清单

### B01 太空站工作台

- 目标：默认科技感场景，适合 working / typing。
- 提示词：

```text
pixel art isometric space station habitat, 360x140 wide banner, dark navy starfield background, diamond tiled floor, glowing blue terminal on the left with tiny code lines, round porthole on the right showing a blue planet, small empty center floor space for a robot pet, crisp hard edges, limited palette, no text, no blur
```

### B02 赛博朋克实验室

- 目标：高能工作、搜索、多 Agent 并行。
- 提示词：

```text
pixel art isometric cyberpunk laboratory, 360x140 wide banner, dark purple black room, magenta neon sign frame, cyan server rack lights, reflective diamond floor tiles, glowing hologram disk in the center, empty pet placement area, crisp pixel art, no readable text
```

### B03 星际生活舱

- 目标：idle / sleep 的温和场景。
- 提示词：

```text
pixel art isometric sci-fi living quarters, 360x140 wide banner, dark blue cozy spacecraft cabin, large panoramic window with orange red nebula outside, pale blue floor panels, charging station on the right, tiny floating plant pot, calm ambient lighting, empty space for a small robot pet
```

### B04 像素水族箱

- 目标：水母、潜水机器人、放松状态。
- 提示词：

```text
pixel art underwater aquarium habitat, 360x140 wide banner, teal blue water gradient, sandy bottom, colorful blocky coral, rising pixel bubbles, tiny orange fish swimming, soft water light streaks, empty middle area for pet sprite, crisp pixel art, no blur
```

### B05 星云温室

- 目标：植物系宠物专属，科技与自然混合。
- 提示词：

```text
pixel art isometric nebula greenhouse, 360x140 wide banner, glass dome inside a spaceship, dark space outside with purple nebula, hydroponic planters, glowing nutrient tubes, diamond metal floor mixed with green moss tiles, small central platform for a cactus pet, crisp hard-edged pixel art
```

### B06 额度补给站

- 目标：Quota refresh / 资源恢复。
- 提示词：

```text
pixel art sci-fi quota recharge station, 360x140 wide banner, compact maintenance bay, glowing battery capsule, token cubes stored in transparent containers, small charging dock, blue and green indicator lights, dark metal isometric floor, empty pet placement area, no text
```

### B07 错误维修间

- 目标：error / exhausted 状态。
- 提示词：

```text
pixel art robot repair corner, 360x140 wide banner, dim sci-fi workshop, red warning lights, small tool rack, cracked screen parts, smoke pixel particles, emergency charging mat, dark gray isometric floor, dramatic but cute mood, empty space for pet sprite, no text
```

### B08 代码雨天台

- 目标：OpenCode 黑客风、searching / fast。
- 提示词：

```text
pixel art rooftop server garden at night, 360x140 wide banner, black green terminal mood, distant city skyline made of pixels, vertical falling code-like light bars without readable characters, small satellite dish, dark isometric floor, empty pet placement area, crisp high contrast pixel art
```

## C. 配饰清单

### C01 萌芽 Sprout

```text
tiny pixel art sprout accessory, 16x16 sprite, two green leaves and short stem, black 1px outline, cute growth symbol, transparent background, designed to sit on top of a robot head
```

### C02 战术耳机 Headset

```text
tiny pixel art headset accessory, 24x16 sprite, black headband, two square ear pads, small cyan microphone pixel, 1px black outline, transparent background, designed for a cute robot or cat pet
```

### C03 天才光环 Halo

```text
tiny pixel art floating halo accessory, 24x16 sprite, golden oval ring made of blocky pixels, subtle glow pixels, black outline only on lower edge, transparent background, designed to float above a pet head
```

### C04 复古天线 Antenna

```text
tiny pixel art retro antenna accessory, 16x24 sprite, thin black pixel stem, round red blinking tip, small metal base, 1px black outline, transparent background, designed for top mount on robot head
```

### C05 能量电池 Battery

```text
tiny pixel art backpack battery accessory, 20x20 sprite, rectangular battery pack, green charge bars, metal casing, black 1px outline, transparent background, designed to mount on pet back
```

### C06 喷气背包 Jetpack

```text
tiny pixel art jetpack accessory, 24x24 sprite, twin metal cylinders, blue flame pixels, orange exhaust tip, black 1px outline, transparent background, designed to mount behind a small pet
```

### C07 赛博披风 Cape

```text
tiny pixel art cyber cape accessory, 24x24 sprite, short angular cape, deep blue fabric with violet edge pixels, black 1px outline, transparent background, designed to trail behind a robot pet
```

### C08 迷你僚机 Mini Drone

```text
tiny pixel art sidekick drone accessory, 16x16 sprite, single glowing eye, two small wings, cyan status light, black 1px outline, transparent background, floating beside main pet
```

### C09 代码云 Code Cloud

```text
tiny pixel art code cloud accessory, 24x16 sprite, small dark cloud made of square pixels, raining tiny green code blocks without readable text, black 1px outline, transparent background, designed to float above or beside a pet
```

### C10 破旧补丁 Error Patch

```text
tiny pixel art repair patch accessory, 16x16 sprite, square fabric patch with two stitch pixels, red warning corner, black 1px outline, transparent background, designed to stick onto robot body after many errors
```

### C11 潜水氧气罩 Bubble Helmet

```text
tiny pixel art transparent bubble helmet accessory, 24x24 sprite, circular glass dome, cyan rim, small shine pixels, black 1px outline, transparent center, designed for robot pet underwater scene
```

### C12 Token 小方块

```text
tiny pixel art token cube pickup, 12x12 sprite, glowing square cube, cyan blue front face, purple shadow side, white top-left highlight, black 1px outline, transparent background
```

## D. 动作与状态帧清单

### D01 Idle 待机眨眼

```text
4-frame pixel art sprite sheet of a cute robot pet idling, 32x32 per frame, slight vertical bob by exactly 1 pixel, blinking yellow eyes on the last frame, transparent background, crisp hard-edged pixel art
```

### D02 Thinking 思考

```text
6-frame pixel art sprite sheet of a robot pet thinking, 32x32 per frame, head tilted left, blue eyes, three pulsing blue dots on screen, tiny antenna blinking, transparent background, integer pixel movement only
```

### D03 Typing 打字

```text
6-frame pixel art sprite sheet of a robot pet typing rapidly, 32x32 per frame, small arms tapping, green code lines scrolling on face screen, tiny 0 and 1 pixel blocks popping out, transparent background, no readable text
```

### D04 Searching 搜索扫描

```text
6-frame pixel art sprite sheet of a robot pet searching, 32x32 per frame, radar eye on screen, horizontal scan line moving across face, body shifting left and right by 1 pixel, cyan scanning particles, transparent background
```

### D05 Fast 高速处理

```text
6-frame pixel art sprite sheet of a robot pet moving very fast, 32x32 per frame, stretched motion trail made of blue and violet pixels, small flame pixels behind feet, focused eyes, transparent background, crisp pixel art
```

### D06 Success 成功庆祝

```text
8-frame pixel art sprite sheet of a robot pet celebrating success, 32x32 per frame, star eyes, jumping up by 4 pixels, golden pixel confetti, happy screen mouth, transparent background, cute retro game animation
```

### D07 Error 错误抖动

```text
4-frame pixel art sprite sheet of a robot pet error state, 32x32 per frame, red X eyes, body shaking left and right by 1 pixel, small black smoke pixels, red screen flash, transparent background, cute not scary
```

### D08 Sleeping 睡眠

```text
6-frame pixel art sprite sheet of a robot pet sleeping, 32x32 per frame, dim gray closed eyes, slow breathing motion, tiny z bubbles floating up, body slightly slumped, transparent background, calm cozy pixel art
```

### D09 Auth 权限请求

```text
6-frame pixel art sprite sheet of a robot pet asking permission, 32x32 per frame, innocent tilted head, small lock icon shape on face screen, amber warning glow breathing, transparent background, cute trustworthy expression
```

### D10 Evolving 进化重组

```text
8-frame pixel art sprite sheet of a robot pet evolving, 32x32 per frame, body segments briefly separated into glowing pixel blocks, progress bar eyes, white flash pixels, new accessory appearing on final frame, transparent background
```

## E. 表情清单

| 编号 | 状态 | AI 绘图描述 |
| --- | --- | --- |
| E01 | idle | big dark screen face, two yellow square eyes, small curved pixel smile |
| E02 | thinking | blue square eyes, three pulsing blue dots centered below the eyes |
| E03 | typing | green square eyes, three horizontal green code lines scrolling under eyes |
| E04 | searching | cyan radar circle eyes, one horizontal scan line across the screen |
| E05 | success | golden star eyes, wide U-shaped pixel smile |
| E06 | error | red X eyes, dark screen, tiny red warning corner pixels |
| E07 | sleeping | gray closed line eyes, dim screen, small z pixel near upper right |
| E08 | auth | soft amber eyes, tiny lock symbol made of square pixels |
| E09 | fast | bright green focused eyes with blue afterimage pixels |
| E10 | evolving | two equal-sign eyes, small progress bar line below |

## F. 组合图与宣传图清单

### F01 四皮肤机器人阵列

```text
four cute pixel art robot companions standing side by side on a dark transparent-like checker-free background, Claude terracotta orange, Gemini blue with small multicolor accents, Codex silver white with blue violet glow, OpenCode dark green black terminal style, each has big screen face and tiny antenna, crisp 1px black outlines, limited palette, no text
```

### F02 五种族宠物选择界面概念图

```text
pixel art lineup of five tiny digital pets, robot, quantum cactus, coding cat, translucent slime, neural jellyfish, all in matching 32x32 sprite style, 1px black outline, dark sci-fi UI background, each pet clearly separated, cute technical companion mood, no text
```

### F03 工作流场景海报

```text
pixel art poster of a tiny robot pet working inside an isometric space station, glowing code terminal, token cubes floating, blue starfield through porthole, robot has green code eyes and tapping arms, crisp hard-edged pixel art, limited palette, readable silhouettes, no text
```

### F04 额度耗尽休眠海报

```text
pixel art poster of a small robot pet sleeping in a sci-fi charging station, dim blue cabin, large window with orange nebula, gray closed screen eyes, z bubbles, empty battery pack beside it, cozy melancholic mood, crisp pixel art, no text
```

### F05 进化解锁海报

```text
pixel art poster of a cute robot pet evolving, glowing token cubes orbiting, new halo and jetpack accessories appearing, dark cyberpunk lab with magenta and cyan lights, star pixels and white flash blocks, crisp hard-edged pixel art, no text
```

### F06 水族箱放松海报

```text
pixel art poster of a robot pet with bubble helmet floating in a pixel aquarium, coral reef, tiny fish, rising bubbles, teal water light streaks, calm cute mood, neural jellyfish companion nearby, crisp 1px outlines, no text
```

## G. 资产优先级建议

### 第一批：最适合立刻落地

- A01 BitBot v2 基础机器人
- A02-A05 四套 Agent 皮肤
- B01-B04 当前四个项目场景
- C01 Sprout、C02 Headset、C05 Battery、C08 Mini Drone
- D01 Idle、D03 Typing、D06 Success、D07 Error、D08 Sleeping

### 第二批：增强养成感

- A06 Quant-Flora、A07 Logic-Critter、A08 Slime-Blob、A09 Neural-Jelly
- C03 Halo、C04 Antenna、C06 Jetpack、C07 Cape、C09 Code Cloud
- D02 Thinking、D04 Searching、D05 Fast、D09 Auth、D10 Evolving

### 第三批：品牌和宣传

- F01 四皮肤机器人阵列
- F02 五种族宠物选择界面概念图
- F03-F06 场景海报
- B05 星云温室、B06 额度补给站、B07 错误维修间、B08 代码雨天台

## H. 给 AI 绘图的组合模板

把具体条目填入 `{asset_description}`：

```text
{asset_description}, pixel art sprite, crisp hard edges, no anti-aliasing, 1px black outline, limited color palette, strong silhouette, readable at small size, cute retro sci-fi software companion, transparent background, orthographic view
```

场景类改用：

```text
{scene_description}, pixel art isometric wide banner, 360x140 composition, dark sci-fi environment, empty center area for a small pet sprite, crisp hard edges, no anti-aliasing, limited palette, no readable text, no watermark
```

动作帧类改用：

```text
{animation_description}, sprite sheet, 32x32 per frame, 4 to 8 frames, integer pixel movement only, transparent background, crisp hard-edged pixel art, no anti-aliasing, no motion blur
```
