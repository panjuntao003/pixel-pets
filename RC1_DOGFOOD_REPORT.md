# Pixel Pets RC1 Dogfood Report

**测试版本**: v0.9.0-rc1
**测试周期**: [填写测试日期，例如：2026-05-04 10:00 至 2026-05-05 10:00]
**总运行时长**: [例如：约 8 小时活跃使用，16 小时后台待机]

## 1. 系统事件触发统计
- **触发过的 Provider**: 
  - [ ] Claude
  - [ ] OpenCode
  - [ ] Codex
  - [ ] Gemini
- **触发过的事件类型**:
  - [ ] appIdle
  - [ ] userStartedRequest
  - [ ] aiThinking
  - [ ] aiStreaming
  - [ ] requestSucceeded
  - [ ] requestFailed
  - [ ] quotaLow
  - [ ] quotaResetting

## 2. 状态准确性观察
- **状态切换准确率**: [例如：高/中/低，描述 `thinking` / `streaming` 是否准确触发]
- **优先级测试**: [例如：`error` 和 `quotaLow` 是否正确覆盖了普通请求状态]
- **自然恢复**: [例如：`requestSucceeded` 后是否在 debounce 时间后自然回到 `idle`]
- **卡死现象**: [记录是否出现状态卡死在 `thinking` 或 `alert` 无法恢复的情况]

## 3. 视觉与打扰程度评估
- **常规模式 (Normal)**: [评价特效是否过于密集]
- **低打扰模式 (Low Distraction)**: [评价 `alert` 是否足够柔和，火花特效隐藏是否符合预期]
- **减弱动态 (Reduce Motion)**: [评价是否完全关闭了弹性和脉冲动画]
- **长期挂机感受**: [例如：一整天挂在屏幕边缘是否会分散注意力]

## 4. 性能与能耗监控 (Performance Guard)
- **Idle CPU 占用**: [记录平时待机时的平均 CPU %]
- **后台降频测试**: [验证窗口不可见时，是否确实降至 1fps 并暂停了复杂重绘]
- **内存表现**: [记录长时间运行后的内存占用情况，排查是否存在图片泄漏]

## 5. 诊断工具 (Debug HUD) 效用
- **事件追溯**: [记录 HUD 的 Timeline 是否能准确解释宠物刚才为什么变红或充电]
- **优先级标识**: [确认 `[OVERRIDE]` 标签是否能在关键时刻帮助排查状态覆盖逻辑]

## 6. 资产稳定性与兼容性 (Content Pack 01)
- **Underwater Aquarium (Pet: Jellyfish)**: [运行状况，锚点是否偏离]
- **Rooftop Server Garden (Pet: Terminal Bot)**: [运行状况，云朵配件动画是否正常]
- **Production Filtering**: [验证在设置页面是否**无法**选到 Quantum Cactus 或 Repair Workshop]
- **Incompatibility Enforcement**: [验证 Repair Patch 是否在 Neural Jellyfish 身上显示为“不兼容”且无法装备]
- **Debug Gallery Visibility**: [确认在调试模式下是否依然能预览所有 01 资产，包括 Debug Only 资产]
- **Fallback 机制**: [在人为删除某张 state png 后，系统是否优雅回退]

---

## 结论与下一步行动
- **发现的主要问题 (Bugs & Glitches)**:
  1. 
  2. 
- **是否有误报 (False Positives)**: [有/无]
- **需要进入 RC1.1 修复的清单 (Must-Fix)**:
  - 
  - 
- **里程碑判定**: 
  - [ ] 可以直接进入 Beta (可作为稳定模块日常使用)
  - [ ] 需要 RC1.1 修复核心问题后再测
