# PixelPets 合并版 Prompt 与绘画规范

> 来源：融合 `PixelPets-Final-Prompt-Library.md`、`PIXEL_PETS_PROMPT_LIBRARY.md`、`PIXEL_ART_DRAWING_CHECKLIST.md` 及其副本。副本内容与原文件一致，已去重。  
> 用途：直接复制到 AI 绘图工具生成 PixelPets 的宠物形象、Agent 皮肤、动作帧、表情、配饰、场景和宣传组合图。  
> 核心目标：保证 Agent 形象、动作、颜色（#HEX）和像素艺术风格稳定一致，可用于 macOS 菜单栏宠物和 Popover 场景。

---

## 0. 全局硬性规范

### 0.1 像素艺术硬性要求

所有角色、动作、配饰和场景都必须满足：

- 使用硬边像素艺术，禁止抗锯齿、柔边、写实渲染和矢量平滑边缘。
- 使用清晰低分辨率网格、严格方形像素和有限色盘。
- 角色与配饰必须使用透明背景，角色轮廓必须清晰。
- 角色主轮廓使用 1px 纯黑或黑色轮廓。
- 所有小尺寸资产必须在 16x16 可读，避免不可读细节。
- 动作帧必须只使用整数像素位移，禁止平滑旋转、运动模糊和非整数缩放。
- Prompt 中出现 `must be`、`exactly`、`strict`、`no` 等硬性要求时，生成时必须保留原语义。

### 0.2 通用正向后缀

追加到角色、配饰和动作 Prompt 末尾：

```text
pixel art sprite, crisp hard edges, no anti-aliasing, strict square pixels, 1px pure black outline, limited color palette, high readability at 16x16 size, transparent background, orthographic front view, clean silhouette, cute but technical, retro sci-fi software companion, not blurry
```

场景类可追加：

```text
pixel art isometric wide banner, 360x140 composition, crisp hard edges, no anti-aliasing, limited palette, no readable text, no watermark
```

### 0.3 通用负向词

```text
photorealistic, 3D render, smooth vector, soft gradients, anti-aliased edges, painterly brush, realistic fur, overly detailed texture, noisy background, tiny unreadable details, text, watermark, logo, signature, low contrast, muddy colors, realistic robot, human face, round glossy 3D icon, motion blur
```

### 0.4 输出尺寸建议

| 资产类型 | 建议画布 | 说明 |
| --- | --- | --- |
| 菜单栏小图标 | 16x16 px | 极简剪影，保留脸部和 1 个识别点 |
| 基础宠物 | 24x28 px 或 32x32 px | 主体比例保持 24:28，可放大展示 |
| 动作帧 | 32x32 px sprite sheet | 每个动作 4-8 帧，整数像素位移 |
| 配饰 | 16x16 px 或 24x24 px | 透明背景，方便挂载 |
| 场景 | 360x140 px 或 720x280 px | Popover 横幅，等距透视 |
| 宣传图 | 1024x1024 px | 可更精细，但仍保持像素块边界 |

---

## 1. Agent 基础形象

### 1.1 Claude Code：规划 / 架构 / 思考

**定位**：稳重的架构师，暖橙色机身，专注的金黄色眼睛。

```text
Claude Code themed pixel art architect robot companion, 24x28 sprite proportions, body color must be #d97757 as the dominant fill, #e89a78 top-left pixel highlights, #a94f36 bottom-right pixel shadows, slightly larger rounded square head than body, large dark screen face #1a1110, focused warm golden eyes #ffd166, tiny side antennas, small blueprint panel or architecture grid on chest, one short arm pointing at a tiny floating plan card, calm planning and system-architecture personality, thoughtful posture, transparent background
```

**强化区分词**

```text
planner, architect, systems thinker, blueprint grid, tiny flowchart card, calm deliberate pose, explaining a plan, warm but serious
```

**避免**

```text
typing robot, hacker robot, wizard, colorful magic, wrench arm, chaotic motion
```

### 1.2 Gemini CLI：设计 / 发散 / 想象

**定位**：轻盈灵动的赛博法师，四色星芒渐变。

```text
Gemini CLI themed pixel art imagination sprite robot, 24x28 sprite proportions, light agile silhouette like a tiny cyber wizard, body based on #338afb blue, pixelated four-point star core on forehead or chest, Gemini gradient colors #fa4345 at top, #f5c117 at left, #27b86f at bottom, #338afb at right, colors blended as stepped 1px pixel blocks not smooth airbrush, large dark screen face with bright curious eyes, 3 to 5 tiny floating idea bubbles or sketch cards around the head, playful design and brainstorming personality, transparent background
```

**强化区分词**

```text
imagination sprite, design brainstormer, four-point star core, floating idea bubbles, tiny sketch cards, color swatches, playful curious eyes
```

**避免**

```text
serious architect, terminal builder, wrench arm, dark hacker, realistic smooth logo, plain blue robot
```

### 1.3 Codex：构建 / 审查 / 修复

**定位**：精准高效的代码工匠，蓝紫云团外壳，终端提示符 `>_`。

```text
Codex themed pixel art builder and code-review robot companion, 24x28 sprite proportions, compact tool-like silhouette, rounded blue violet cloud-like shell around a terminal face, use exact palette #2a1eff deep lower-left shadow, #6879ff main mid blue, #9d89ff top highlight, #627aff and #6e8eff edge glow pixels, large dark screen face with white terminal prompt symbols > and _ made from square pixels, small wrench arm on one side, tiny checkmark or diff-line patch module on the body, precise build review repair personality, transparent background
```

**强化区分词**

```text
builder, code reviewer, repair unit, terminal craftsman, wrench arm, checkmark patch, diff-line module, precise efficient motion
```

**避免**

```text
silver robot, orange planner, colorful wizard, idea bubbles, blueprint card, big happy mascot
```

### 1.4 OpenCode：专注 / 暗色终端 / 黑客感

**定位**：夜间终端守护程序，黑绿高对比，极简专注。

```text
OpenCode themed pixel art robot companion, 24x28 sprite proportions, near-black body #050807 with dark green panels #12382f, neon terminal highlights #27b86f, large dark screen face with #00ff88 square eyes and scrolling terminal bars, high contrast silhouette, tiny antenna, angular hacker terminal style, minimal focused posture, transparent background
```

**强化区分词**

```text
dark terminal guardian, open-source hacker mood, near-black shell, neon green terminal eyes, minimal efficient pose, high contrast
```

**避免**

```text
rainbow, orange planner, blue-violet cloud, cute wizard, soft pastel, realistic laptop
```

---

## 2. 基础宠物与备选物种

### 2.1 BitBot v2 基础机器人

```text
a cute tiny pixel art robot companion named BitBot, 24x28 sprite proportions, rounded square head, big dark screen face taking most of the head, small rectangular body, short arms and legs, side antennas, silver white metal body with subtle blue highlights, 1px black outline, top-left pixel highlight, bottom-right pixel shadow, transparent background, readable at 16x16 menu bar size
```

### 2.2 Quant-Flora 量子仙人掌

```text
a cute pixel art quantum cactus pet, 32x32 sprite, small round cactus body with branching arms, tiny pixel thorns, glowing flower bud on top, black 1px outline, matte green body, agent color glow in the flower bud, sleepy cute face, transparent background, crisp hard-edged pixel art
```

### 2.3 Logic-Critter 算力猫

```text
a tiny pixel art coding cat pet, 32x32 sprite, square cute head, oversized pixel eyes, small triangular ears, fluffy tail made from blocky pixels, colored circuit stripe markings, black 1px outline, sitting pose, readable silhouette, transparent background, no realistic fur
```

### 2.4 Slime-Blob 幻色史莱姆

```text
a cute translucent pixel art slime pet, 32x32 sprite, rounded blob body, chunky pixel highlight, tiny bubbles and token cubes inside, simple happy face, black 1px outline with colored inner glow, squishy silhouette, transparent background, crisp pixel edges
```

### 2.5 Neural-Jelly 神经元水母

```text
a tiny pixel art neural jellyfish pet, 32x32 sprite, glowing umbrella head, short dangling tentacles like data cables, cyan bioluminescent pixels, simple cute face, black 1px outline, floating pose, transparent background, deep sea sci-fi companion style
```

### 2.6 Micro-Drone 迷你僚机宠物

```text
a tiny pixel art assistant drone, 16x16 sprite, round central eye screen, two small propeller pods, black 1px outline, cyan status light, cute helper personality, transparent background, clean readable silhouette at menu bar size
```

---

## 3. 角色变量库

把下面的 `{agent_description}` 放入通用动作帧 Prompt。

### Claude 变量

```text
Claude Code architect planner robot, body #d97757, large dark screen face #1a1110, golden eyes #ffd166, tiny blueprint card, architecture grid on chest, calm deliberate planning posture
```

### Gemini 变量

```text
Gemini CLI imagination wizard robot, body #338afb, pixelated four-point star core, stepped gradient accents #fa4345 #f5c117 #27b86f #338afb, floating idea bubbles, bright curious eyes
```

### Codex 变量

```text
Codex blue-violet builder and code-review robot, rounded cloud terminal shell using #2a1eff #6879ff #9d89ff #627aff #6e8eff, white >_ face symbol, small wrench arm, checkmark patch, precise repair posture
```

### OpenCode 变量

```text
OpenCode dark terminal robot, near-black body #050807, dark green panels #12382f, neon #00ff88 terminal eyes, tiny green circuit pixels, high contrast focused hacker mood
```

---

## 4. 角色状态 Prompt

### 4.1 Claude 状态组

**Claude Thinking / 架构思考**

```text
Claude Code themed pixel art architect robot companion thinking, 32x32 sprite, body #d97757, warm highlights #e89a78, dark screen face #1a1110, focused golden eyes #ffd166, three small planning dots on screen, one arm pointing at a tiny floating blueprint card, chest architecture grid glowing softly, calm deliberate pose, transparent background
```

**Claude Planning / 拆解方案**

```text
Claude Code themed pixel art architect robot companion, 32x32 sprite, body #d97757, standing beside three tiny floating flowchart blocks, one short arm pointing to the first block, focused golden eyes, small blueprint grid on chest, thoughtful system-design mood, transparent background
```

**Claude Success / 方案完成**

```text
Claude Code themed pixel art architect robot companion success pose, 32x32 sprite, body #d97757, warm golden eyes, tiny checkmark on floating plan card, subtle star pixels around blueprint grid, calm satisfied smile, not jumping wildly, transparent background
```

### 4.2 Gemini 状态组

**Gemini Ideation / 灵感发散**

```text
Gemini CLI themed pixel art imagination sprite robot brainstorming, 32x32 sprite, body #338afb, four-point star core with #fa4345 top #f5c117 left #27b86f bottom #338afb right, 5 tiny floating idea bubbles and sketch cards around the head, bright curious eyes, playful tilted pose, transparent background
```

**Gemini Design / 设计探索**

```text
Gemini CLI themed pixel art design wizard robot, 32x32 sprite, light agile silhouette, four-point star core glowing, small floating color swatches using #338afb #f5c117 #27b86f #fa4345, tiny sketch-card pixels, curious screen eyes, imaginative playful mood, transparent background
```

**Gemini Success / 灵感爆发**

```text
Gemini CLI themed pixel art imagination sprite robot celebrating, 32x32 sprite, pixelated four-point star particles bursting outward, stepped gradient colors #fa4345 #f5c117 #27b86f #338afb, bright joyful eyes, floating idea bubbles, playful but readable silhouette, transparent background
```

### 4.3 Codex 状态组

**Codex Working / 构建中**

```text
Codex themed pixel art builder robot working, 32x32 sprite, compact blue-violet cloud shell, palette #2a1eff #6879ff #9d89ff #627aff #6e8eff, dark terminal face with white >_ prompt, small wrench arm adjusting a glowing build block, tiny diff-line module on body, precise efficient posture, transparent background
```

**Codex Review / 审查中**

```text
Codex themed pixel art code-review robot, 32x32 sprite, blue-violet cloud terminal shell, dark screen face with narrow focused eyes and white checkmark pixel, small magnifier or checkmark patch beside terminal face, two tiny diff-line pixels red and green, precise reviewer mood, transparent background
```

**Codex Repair / 修复中**

```text
Codex themed pixel art repair robot, 32x32 sprite, rounded blue-violet cloud shell using #2a1eff #6879ff #9d89ff #627aff #6e8eff, white terminal prompt face, small wrench arm placing a square patch module onto body, tiny spark pixels, calm focused repair mood, transparent background
```

### 4.4 OpenCode 状态组

**OpenCode Terminal / 专注执行**

```text
OpenCode themed pixel art terminal robot working, 32x32 sprite, near-black body #050807, dark green panels #12382f, neon #00ff88 terminal eyes, scrolling terminal bars on dark screen, tiny green circuit pixels, minimal efficient motion, transparent background
```

**OpenCode Searching / 检索扫描**

```text
OpenCode themed pixel art terminal robot searching, 32x32 sprite, near-black and dark green shell, #00ff88 radar eyes made of square pixels, one horizontal green scan line across screen, tiny circuit particles near antenna, high contrast hacker mood, transparent background
```

---

## 5. 通用动作帧 Prompt

### Idle 待机眨眼

```text
4-frame pixel art sprite sheet of {agent_description} idling, 32x32 per frame, frame 1 neutral standing, frame 2 body moves up exactly 1 pixel, frame 3 returns down exactly 1 pixel, frame 4 eyes become two horizontal blink lines, no limb deformation except integer pixel shifts, transparent background, crisp hard-edged pixel art
```

### Thinking 思考

```text
6-frame pixel art sprite sheet of {agent_description} thinking, 32x32 per frame, head tilted left by 1 pixel and 1 pixel down on alternating frames, three small dots on the face screen light up from left to right, antenna tip blinks every other frame, no smooth rotation, integer pixel movement only, transparent background
```

### Typing / Working 工作

```text
6-frame pixel art sprite sheet of {agent_description} working rapidly, 32x32 per frame, left and right arms alternate up and down by 1 pixel, code or tool pixels animate on the face screen, 2 or 3 tiny square token pixels pop from the screen edge, no readable letters or numbers, transparent background, crisp pixel art
```

### Searching 搜索

```text
6-frame pixel art sprite sheet of {agent_description} searching, 32x32 per frame, both eyes become radar circles made of square pixels, one horizontal scan line moves from top of face screen to bottom, body shifts left then right by exactly 1 pixel, 1px scanning particles appear near antenna, transparent background
```

### Fast 高速处理

```text
6-frame pixel art sprite sheet of {agent_description} moving very fast, 32x32 per frame, stretched motion trail made of blue and violet pixels, small flame pixels behind feet, focused eyes, transparent background, crisp pixel art, no motion blur
```

### Success 成功

```text
8-frame pixel art sprite sheet of {agent_description} celebrating success, 32x32 per frame, frames 1-2 crouch down 1 pixel, frames 3-5 jump or lift upward by 4 pixels, frames 6-8 land and bounce, face has bright success eyes and U-shaped pixel smile, four small confetti pixels burst from head, transparent background
```

### Error 错误

```text
4-frame pixel art sprite sheet of {agent_description} error state, 32x32 per frame, red X eyes on dark screen, body alternates x offset -1 and +1 pixel, screen flashes red on frames 2 and 4, two black smoke pixels rise from antenna, expression is cute stressed not scary, transparent background
```

### Sleeping 睡眠

```text
6-frame pixel art sprite sheet of {agent_description} sleeping, 32x32 per frame, dim gray closed line eyes, body compresses down by 1 pixel then returns, head slightly slumped forward, one tiny z pixel bubble moves upward by 1 pixel per frame, screen brightness stays low, transparent background
```

### Auth 权限请求

```text
6-frame pixel art sprite sheet of {agent_description} asking permission, 32x32 per frame, innocent tilted head, small lock icon shape on face screen, amber warning glow breathing, transparent background, cute trustworthy expression
```

### Evolving 进化

```text
8-frame pixel art sprite sheet of {agent_description} evolving, 32x32 per frame, frames 1-2 normal body, frames 3-5 body separates into 6 glowing square blocks by 1-2 pixels, frames 6-7 white flash pixels around silhouette, frame 8 reassembled body with one new accessory attached, face shows equal-sign progress eyes, transparent background
```

---

## 6. 表情 Prompt

### Idle

```text
dark rectangular screen face, two 2x2 yellow square eyes, 6px shallow U-shaped smile, optional blink variant with two 3px horizontal lines
```

### Thinking

```text
dark screen, two 2x2 blue square eyes, three 1px blue dots centered under eyes, dots arranged horizontally and intended to pulse left to right
```

### Typing / Working

```text
dark screen, two green 2x2 square eyes, three 1px horizontal green code bars under the eyes, bars have different lengths and no readable text
```

### Searching

```text
dark screen, two cyan radar eyes made from square ring pixels, one 1px cyan horizontal scan line crossing the screen
```

### Success

```text
dark screen, two golden 5-pixel star eyes, wide U-shaped pixel smile, optional two cheek pixels
```

### Error

```text
dark screen with red flash tint, two red X eyes made from 5 pixels each, no mouth or tiny flat mouth
```

### Sleeping

```text
dim dark screen, two gray 3px horizontal closed-eye lines, one tiny z pixel cluster near upper right of screen
```

### Auth

```text
dark screen, two soft amber square eyes, tiny lock symbol below eyes made from square pixels, innocent expression
```

### Fast

```text
bright green focused eyes with blue afterimage pixels
```

### Evolving

```text
two equal-sign eyes, small progress bar line below
```

---

## 7. Habitat 场景 Prompt

### 7.1 Habitat 硬性约束

所有 Habitat 场景都必须满足：

- 整个 360x140 画面都应像一个可活动的小栖息地，而不是只在中间留一个小站位。
- 宠物应能在左侧、中间、右侧、前景和后景都有合理移动空间。
- 地面、平台、水体或云岛必须连续覆盖主要可视区域，形成完整活动面。
- 大型装饰物、墙面设备、树、机柜、舷窗、建筑和障碍物必须贴边或靠后，不要堵住活动区域。
- 不要生成狭窄小平台、单点站台、只容纳一个宠物的圆盘或孤立中央格子。
- 不要使用早期 Prompt 中的 `small empty center floor space`、`empty pet placement area`、`small central platform` 作为最终约束；这些都应被替换为全场景可活动空间。
- Prompt 中优先使用：`full-scene walkable habitat`、`continuous traversable floor`、`open movement space across the whole banner`、`obstacles pushed to edges and background`。

### 太空站工作台

```text
pixel art isometric space station habitat, 360x140 wide banner, full-scene walkable habitat, continuous traversable diamond-tile floor across the whole banner, open movement space from left to right for a pet sprite, dark navy starfield background, glowing blue terminal pushed to the left wall, round porthole showing a blue planet on the back wall, obstacles pushed to edges and background, no narrow central platform, no text
```

### 赛博朋克实验室

```text
pixel art isometric cyberpunk laboratory, 360x140 wide banner, full-scene walkable habitat, continuous reflective diamond floor covering the whole room, open movement space across the whole banner for a pet sprite, dark purple black room, magenta neon frame on back wall, cyan server lights pushed to side walls, glowing hologram disk kept small and non-blocking, obstacles pushed to edges and background, no isolated pet platform
```

### 星际生活舱

```text
pixel art isometric sci-fi living quarters, 360x140 wide banner, full-scene walkable cozy spacecraft cabin, continuous pale blue floor panels across the whole banner, open movement space across left center and right for a small pet sprite, large panoramic window with orange red nebula pushed to back wall, charging station pushed to the right edge, tiny floating plant pot near background, calm ambient lighting, no isolated pet placement spot
```

### 像素水族箱

```text
pixel art underwater aquarium habitat, 360x140 wide banner, full-scene swimmable habitat, continuous open water volume across the whole banner for a floating pet sprite, teal blue water gradient, sandy bottom runs across the full width, colorful blocky coral pushed to far left and far right edges, rising pixel bubbles and light streaks in background, open movement space in center and sides, no tiny isolated swimming pocket, crisp edges
```

### 星云温室

```text
pixel art isometric nebula greenhouse, 360x140 wide banner, full-scene walkable greenhouse habitat, continuous diamond metal floor mixed with green moss tiles across the whole banner, open movement space across left center and right for a cactus pet, glass dome inside a spaceship, dark space outside with purple nebula, hydroponic planters and glowing nutrient tubes pushed to back and side edges, no small central platform, crisp hard-edged pixel art
```

### 额度补给站

```text
pixel art sci-fi quota recharge station, 360x140 wide banner, full-scene walkable maintenance bay, continuous dark metal floor across the whole banner, open movement space from left to right for a pet sprite, glowing battery capsule and token containers pushed to back wall and corners, blue and green indicators along edges, no narrow docking pad, no single pet spot
```

### 错误维修间

```text
pixel art robot repair corner, 360x140 wide banner, full-scene walkable dim sci-fi workshop, continuous dark gray isometric floor across the whole banner, open movement space for a pet sprite across foreground and center, red warning lights, small tool rack, cracked screen parts and emergency charging mat pushed to edges and background, smoke pixel particles, dramatic but cute mood, no isolated repair pad, no text
```

### 代码雨天台

```text
pixel art rooftop server garden at night, 360x140 wide banner, full-scene walkable hacker rooftop habitat, continuous dark isometric floor across the whole banner, open movement space left to right for a pet sprite, black green terminal mood, distant city skyline made of pixels, vertical falling code-like light bars without readable characters in background, small satellite dish pushed to one side, crisp high contrast pixel art
```

### 禅意竹林机房 Zen Tech Garden

```text
pixel art isometric zen bamboo garden, 360x140 wide banner, full-scene walkable tech garden, continuous raked sand and dark wooden deck paths across the whole banner, open movement space for a pet sprite on left center and right, glowing cyber-bamboo stalks pushed to back and side edges, small stone lantern with a cyan data core near one corner, circular circuit lines embedded in the ground but not blocking movement, soft ambient green and teal lighting, serene tech-nature fusion, crisp pixel art
```

### 黄金沙漠驿站 Desert Outpost

```text
pixel art isometric desert outpost, 360x140 wide banner, full-scene walkable desert habitat, continuous sandy ground and metal walkway across the whole banner, open movement space from left to right for a pet sprite, golden sand dunes under a giant setting sun in background, rugged metal shelter with solar panels pushed to one side, floating red dust particles, warm orange and yellow palette, rusted tech debris half-buried near edges, no tiny central platform, high warmth and contrast, crisp pixel art
```

### 霓虹游戏厅 Retro Arcade

```text
pixel art isometric neon arcade room, 360x140 wide banner, full-scene walkable arcade habitat, continuous checkered floor tiles across the whole banner, open movement space for a pet sprite from left to right and foreground to background, glowing arcade cabinets pushed against back and side walls, vibrant magenta and blue atmosphere, neon zig-zag wall decorations, floating pixel star particles in background, no single empty floor spot, energetic retro vibe, crisp pixel art
```

### 浮空云之岛 Sky Island

```text
pixel art floating sky island habitat, 360x140 wide banner, full-scene traversable sky habitat, broad continuous grassy cloud-island platform spanning most of the banner width, open movement space for a pet sprite across left center and right, soft white clouds in a bright blue sky, tiny white stone pillar and floating data crystals pushed to edges and background, distant flying airships, airy and bright palette, no tiny isolated island platform, peaceful high-altitude mood, crisp pixel art
```

---

## 8. 配饰 Prompt

### Sprout 萌芽

```text
tiny pixel art sprout accessory, 16x16 sprite, two green leaves and short stem, black 1px outline, cute growth symbol, transparent background, designed to sit on top of a robot head
```

### Headset 战术耳机

```text
tiny pixel art headset accessory, 24x16 sprite, black headband, two square ear pads, small cyan microphone pixel, 1px black outline, transparent background, designed for a cute robot pet
```

### Halo 天才光环

```text
tiny pixel art floating halo accessory, 24x16 sprite, golden oval ring made of blocky pixels, subtle glow pixels, black outline only on lower edge, transparent background, designed to float above a pet head
```

### Antenna 复古天线

```text
tiny pixel art retro antenna accessory, 16x24 sprite, thin black pixel stem, round red blinking tip, small metal base, 1px black outline, transparent background, designed for top mount on robot head
```

### Battery 能量电池

```text
tiny pixel art backpack battery accessory, 20x20 sprite, rectangular battery pack, green charge bars, metal casing, black 1px outline, transparent background, designed to mount on pet back
```

### Jetpack 喷气背包

```text
tiny pixel art jetpack accessory, 24x24 sprite, twin metal cylinders, blue flame pixels, orange exhaust tip, black 1px outline, transparent background, designed to mount behind a small pet
```

### Cape 赛博披风

```text
tiny pixel art cyber cape accessory, 24x24 sprite, short angular cape, deep blue fabric with violet edge pixels, black 1px outline, transparent background, designed to trail behind a robot pet
```

### Mini Drone 迷你僚机

```text
tiny pixel art sidekick drone accessory, 16x16 sprite, single glowing eye, two small wings, cyan status light, black 1px outline, transparent background, floating beside main pet
```

### Code Cloud 代码云

```text
tiny pixel art code cloud accessory, 24x16 sprite, small dark cloud made of square pixels, raining tiny green code blocks without readable text, black 1px outline, transparent background, designed to float above or beside a pet
```

### Error Patch 破旧补丁

```text
tiny pixel art repair patch accessory, 16x16 sprite, square fabric patch with two stitch pixels, red warning corner, black 1px outline, transparent background, designed to stick onto robot body after many errors
```

### Bubble Helmet 潜水氧气罩

```text
tiny pixel art transparent bubble helmet accessory, 24x24 sprite, circular glass dome, cyan rim, small shine pixels, black 1px outline, transparent center, designed for robot pet underwater scene
```

### Token Cube 小方块

```text
tiny pixel art token cube pickup, 12x12 sprite, glowing square cube, cyan blue front face, purple shadow side, white top-left highlight, black 1px outline, transparent background
```

---

## 9. 组合图与海报 Prompt

### 四 Agent 阵列

```text
four cute pixel art software companion characters standing side by side, same 24x28 sprite proportions but clearly different roles: Claude is a #d97757 architect planner robot with a tiny blueprint grid and one pointing arm; Gemini is a light agile #338afb imagination wizard robot with pixelated four-point star gradient accents #fa4345 #f5c117 #27b86f #338afb and floating idea bubbles; Codex is a compact blue-violet builder and code-review cloud-terminal robot using #2a1eff #6879ff #9d89ff #627aff #6e8eff with white >_ face symbol, small wrench arm and checkmark patch; OpenCode is a dark near-black green terminal hacker robot with #00ff88 eyes; each has a large dark screen face, crisp 1px pure black outlines, limited palette, transparent background, no text
```

### 五种族宠物选择界面概念图

```text
pixel art lineup of five tiny digital pets, robot, quantum cactus, coding cat, translucent slime, neural jellyfish, all in matching 32x32 sprite style, 1px black outline, dark sci-fi UI background, each pet clearly separated, cute technical companion mood, no text
```

### 工作流海报

```text
pixel art poster of PixelPets software companions working together inside an isometric space station, Claude planner robot pointing at a blueprint card, Gemini imagination robot creating four-color idea bubbles, Codex builder robot repairing a glowing code block with a wrench arm, OpenCode dark terminal robot monitoring green scan lines, token cubes floating, dark sci-fi background, crisp hard-edged pixel art, limited palette, no text
```

### 额度耗尽休眠海报

```text
pixel art poster of a small robot pet sleeping in a sci-fi charging station, dim blue cabin, large window with orange nebula, gray closed screen eyes, z bubbles, empty battery pack beside it, cozy melancholic mood, crisp pixel art, no text
```

### 进化解锁海报

```text
pixel art poster of a cute software companion pet evolving, glowing token cubes orbiting, new halo and jetpack accessories appearing, dark cyberpunk lab with magenta and cyan lights, star pixels and white flash blocks, crisp hard-edged pixel art, no text
```

### 水族箱放松海报

```text
pixel art poster of a robot pet with bubble helmet floating in a pixel aquarium, coral reef, tiny fish, rising bubbles, teal water light streaks, calm cute mood, neural jellyfish companion nearby, crisp 1px outlines, no text
```

---

## 10. 快速组合模板

### 单角色

```text
{agent_base_prompt}, {state_or_expression}, pixel art sprite, crisp hard edges, no anti-aliasing, strict square pixels, 1px pure black outline, limited color palette, high readability at 16x16 size, transparent background, orthographic front view
```

### 动作帧

```text
{action_prompt}, {agent_style_modifier}, sprite sheet, 32x32 per frame, integer pixel movement only, transparent background, crisp hard-edged pixel art, no anti-aliasing, no motion blur
```

### 场景

```text
{scene_prompt}, pixel art isometric wide banner, 360x140 composition, full-scene walkable or swimmable habitat, continuous traversable floor or volume, open movement space across the whole banner, obstacles pushed to edges and background, crisp hard edges, no anti-aliasing, limited palette, no readable text, no watermark
```

### 示例：Claude 打字

```text
Claude Code architect planner robot, body #d97757, typing rapidly with green code lines on screen, pixel art sprite, crisp hard edges, 1px pure black outline, transparent background
```

---

## 11. 资产优先级建议

### 第一批：最适合立刻落地

- BitBot v2 基础机器人
- Claude、Gemini、Codex、OpenCode 四套 Agent 皮肤
- 太空站工作台、赛博朋克实验室、星际生活舱、像素水族箱
- Sprout、Headset、Battery、Mini Drone
- Idle、Typing / Working、Success、Error、Sleeping

### 第二批：增强养成感

- Quant-Flora、Logic-Critter、Slime-Blob、Neural-Jelly
- Halo、Antenna、Jetpack、Cape、Code Cloud
- Thinking、Searching、Fast、Auth、Evolving
- 星云温室、额度补给站、错误维修间、代码雨天台

### 第三批：品牌和宣传

- 四 Agent 阵列
- 五种族宠物选择界面概念图
- 工作流海报、额度耗尽休眠海报、进化解锁海报、水族箱放松海报
- 禅意竹林机房、黄金沙漠驿站、霓虹游戏厅、浮空云之岛
