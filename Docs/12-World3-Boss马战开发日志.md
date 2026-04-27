# World3 Boss 马战 — 开发过程记录

本日志用于**按时间记录** Boss 战实现中的操作、决策与待办，与设计对照文档 `Docs/11-World3-Boss马战设计.md` 配合使用。

---

## 资源与场景路径（占位已建）

| 类型 | 路径 |
|------|------|
| 关卡根场景 | `res://system/levels/world3/world3_boss_arena.tscn` |
| 主马 | `res://system/levels/world3/bosses/boss_horse_main.tscn` + `boss_horse_main.gd` |
| 驷 | `res://system/levels/world3/bosses/boss_si.tscn` + `boss_si.gd` |
| 单马（四色共用） | `res://system/levels/world3/bosses/boss_horse_minor.tscn` + `boss_horse_minor.gd` |
| 阶段控制器 | `res://system/levels/world3/scripts/boss_horse_phase_controller.gd` |
| 枚举与阶段名 | `res://system/levels/world3/scripts/boss_horse_types.gd`（`class_name BossHorseTypes`） |
| 绳子占位 | `res://system/levels/world3/props/rope_to_shangyang.tscn` |
| 白马剑占位 | `res://system/levels/world3/props/projectile_white_horse.tscn` |
| 红马炸弹占位 | `res://system/levels/world3/props/bomb_red_horse.tscn` |

---

## 记录模板（复制一行即可写）

| 日期 | 操作摘要 | 涉及文件 / 节点 | 备注 / 下一步 |
|------|----------|-----------------|---------------|
| （例） |  |  |  |

---

## 变更记录

### 2026-04-26

- **操作**：按设计文档 §9 建立 `world3` 目录；创建主马 / 驷 / 单马 / 三道具占位场景与脚本骨架；`world3_boss_arena` 内预置 `Game`、`Bosses`（含四匹 `Minor*` 与 `horse_id`）、`Systems/PhaseController`、`PropsSpawn` 下 `RopesRoot` / `ProjectilesRoot` / `BombsRoot`；摄像机与玩家出生点用 `Marker2D` 占位。
- **说明**：当前 Boss 体与道具的 `collision_layer` / `mask` 多为 `0`，待接入项目碰撞分组后再改；`PhaseController` 已连接主马 `Stats.health_changed`（回调内为占位空逻辑）。
- **补充操作**：已核对并记录动画名到设计文档：主马（`to grey`/`to white`/`to_black`/`to red`、`grey_ready`、`white_call`、`black_call`、`red_call`）、单马（`grey_run`、`white_call`、`black_create`、`red_call`）、驷（`divide`、`horses run`）、白马剑（`ready`/`over`）、红马炸弹（`ready`/`boom`）。
- **补充操作**：完成“主马受击 + 共享血条 + 阶段枚举日志”基础链路：`PhaseController` 新增 `apply_shared_damage()`、`shared_health_changed` 信号、80/60/40/20 阈值阶段切换日志；主马/驷/单马都实现 `take_damage()` 并统一扣主马 `Stats`（五匹马共用同一个 boss 血条）。
- **下一步建议**：在脚本中按文档 §8.3~§8.5 把 `AnimationPlayer.play()` 串到技能状态机，优先落地灰马奔跑链与白马召剑链，再接黑马分裂与红马召爆。

### 2026-04-26（晚）

- **操作**：去掉 World3 Boss 相关场景里 Sprite 的占位 `modulate` / `scale`（主马、单马、白马剑、红马炸弹）；红马 `WarningRing` 改为默认隐藏（无贴图占位）。
- **操作**：在 `PhaseController` 实现入场 Timeline：主马 `jump` → 驷 `divide` → `horses run` + Tween 离场 → 隐藏驷；四匹单马开局隐藏，结束后仅 `MinorGrey` 移到 `GreySpawn` 并显示、播 `grey_jump`。血量阶段阈值在入场结束后再根据 HP% 更新（`intro_timeline_finished` 信号）。
- **调试**：如需跳过入场，在场景里把 `PhaseController.skip_intro_timeline` 勾为 `true`。
- **补充操作**：完成“灰马进场 + 主马仅灰技能 + 80% 切换白马”里程碑。主马脚本接入阶段信号：`GREY_SOLO` 时技能池仅灰，进入 `WHITE_SOLO` 后技能池为灰+白；先用动画链与定时器驱动自动出招（共享 CD 读取 `PhaseController.main_skill_shared_cooldown`）。
- **补充操作**：实现马匹横向移动规则：主马/单马/驷默认持续向左移动，离开左侧视野后从右侧屏幕外重生。为避免与 Timeline/换马 Tween 冲突，阶段控制器在关键切换段临时关闭对应马的自主移动，落位后再恢复。
- **修正**：灰马技能为向左冲刺；白马技能为召唤剑（`projectile_white_horse` 挂到 `PropsSpawn/ProjectilesRoot`，剑播 `ready` 后左飞）。
- **补充操作**：小白马新增“召剑”技能循环（`white_ready -> white_call -> 召剑 -> white_jump`）；大白马技能改为一次施法内连续两次召剑（`white_call` 重复两轮）。
- **补充操作**：完成黑马技能基础：大黑马 `black_ready -> black_call` 后召唤黑分身；分身从“当前已解锁且非黑”的技能池中释放两轮弱化技能（灰冲刺速度减半、白仅一把剑），第二轮结束后淡出消失。本体召唤后仍走正常共享 CD，因此第一轮分身释放期间本体通常不出招，第二轮可能与本体出招重叠。

---

## 剩余工作（维护清单）

以下为**截至当前实现**仍建议推进、联调或回归验收的事项；与 `Docs/11-World3-Boss马战设计.md` §10 检查清单、§11 里程碑对照使用。完成某项后可将对应条目勾掉或删行。

### 技能与阶段（相对设计文档 §7～§8、§11）

- [ ] 按设计 §8.3～§8.5 把各马 `AnimationPlayer.play()` 与技能状态机完整串起来（日志中曾建议优先灰冲刺链、白召剑链，再黑分身、红炸弹）。
- [ ] 60% / 40% 阶段换马与技能池与文档一致，并与主马共享 CD、随机池、`jump` 恢复等规则联调。
- [ ] 五马同场围攻阶段（`ALL_HORSES` 等）AI、主马四技能与 10s 共享 CD 的完整验收。

### 20% 分支、商鞅与演出

- [ ] 20% 预警 UI、占位文案与正式美术/文案替换（场景内 `UIHints` 等）。
- [ ] 预警召唤商鞅：`ready_to_pull` / `be_pull`、肢体预生成与正式连绳、分尸对话（Dialogic）全流程实机回归；静态商鞅路径与召唤体切换边界再验一遍。
- [ ] `ShangYangDialogProxy` 与注册表在存档读档、重进关卡后的行为（若需要）。

### 拉玩家分支与绳子

- [ ] 拉玩家：绳在解绑后仅随马平移；若仍与玩家 `CharacterBody2D` 物理不同步，评估是否在拉扯窗口内暂停玩家 `_physics_process` 或仅用单一「锚点」驱动（与此前讨论一致时再定方案）。
- [ ] `player_fatal_rope_end_offset_0`～`_4` 在实机下微调至满意落点。

### 工程衔接（对照 `Docs/11` §10）

- [ ] 主马 HP 与 `Stats` / Boss 血条 UI 一致性与边界情况。
- [ ] 与 World2 商鞅存档键（如肢体收集）衔接核对。
- [ ] 即死与 `Game` / 玩家死亡流程统一。
- [ ] 剑：仅在消失动画结束后销毁；炸弹：伤害仅绑定爆炸时间窗。
- [ ] 音频：`Docs/10-音频总线配置建议.md` 与 Boss 战 BGM / `MechanismSfxBus`（若采用）走查。

### 测试与文档

- [ ] 关键路径录屏或 checklist：入场 → 各阈值换马 → 20% 双分支（商鞅 / 无商鞅）→ 血量归零 `重拾五肢`（若有）。
- [ ] 将本清单中已完成项同步回 `Docs/11` §10 勾选或迁移至「变更记录」日期行。

---

### 由我补充（留空）

（以下留给你自行填写，保持 Markdown 列表即可。）

- 
- 
- 
- 
- 
