# World3 架构说明（当前代码态）

本文档描述 `system/levels/world3` 目录下的运行时架构，重点覆盖 Boss 场景、阶段控制、存读档与随机拼块。

---

## 1) 总体分层

World3 主要由一个主场景 + 多个功能脚本协作：

- 主场景：`system/levels/world3/world3_boss_arena.tscn`
- 主控脚本：`system/levels/world3/world3_boss_arena.gd`
- 阶段控制器：`system/levels/world3/scripts/boss_horse_phase_controller.gd`
- Boss 单体行为：
  - 主马：`system/levels/world3/bosses/boss_horse_main.gd`
  - 小马：`system/levels/world3/bosses/boss_horse_minor.gd`
  - 驷马：`system/levels/world3/bosses/boss_si.gd`
- 随机拼块：`system/levels/world3/scripts/world3_random_piece_builder.gd`

---

## 2) 主场景节点结构（职责视角）

`World3BossArena` 可分为 4 个域：

- `Bosses`
  - `MainHorse` / `BossSi` / `Minors`
  - `SpawnMarkers`（主马、驷马、灰白黑红出生锚点）
  - `PropsSpawn`（绳子、投射物、炸弹、随机块运行根）
- `Systems`
  - `PhaseController`（阶段机 + 演出编排）
  - `RandomPieceBuilder`（拼块生成与流式装载）
  - `UIHints`（阶段提示、技能/进场播报等）
- `player`
  - 玩家本体，含 `Camera2D` 与相机前瞻/焦点逻辑
- 音频层
  - `ArenaBgmA/B`：双播放器交叉淡入淡出
  - `BossPhaseStinger`：阶段切换提示音

---

## 3) 关键运行时数据流

### 3.1 血量与阶段

- 共享血量来源：`PhaseController` 内部 `_main_stats`
- 变化入口：`_on_main_health_changed()`
- 阶段推进：`_update_phase_by_hp_percent()` -> `request_phase(...)`
- 阶段广播：
  - `phase_changed`（Boss 行为、BGM、UI 监听）
  - `shared_health_changed` / `shared_health_depleted`

### 3.2 BGM

由 `world3_boss_arena.gd` 管理：

- 常态：`场景背景音乐.mp3`
- 战斗：`boss马伴奏音乐.mp3`
- 20%：`boss马处决音乐.mp3`

切换策略为双 `AudioStreamPlayer` 交叉淡化，避免硬切。

### 3.3 UI 播报

播报触发在主马脚本：

- 技能播报：`_show_skill_broadcast(...)`
- 进场播报：`post_minor_entry_broadcast(...)`

渲染容器是 `Systems/UIHints/SkillFeedRoot`，当前实现为“弹幕轨道”调度（从右到左）。

---

## 4) Boss 战斗与演出协同

### 4.1 主马/小马/驷马协同

- 主马负责技能主调度与广播发射。
- 小马负责各色技能执行与黑马分身机制。
- 驷马承担开场/过场存在形态，之后按阶段退出或恢复。

### 4.2 20% 致命流程

`PhaseController` 统一串联：

- 预警 UI（`boss_fatal_warning.tscn`）
- 商鞅/玩家绳索拉扯
- 对话时间线（Dialogic）
- 回场与终局状态过渡

该流程中会锁定输入、接管相机焦点、并在结束后恢复。

---

## 5) 存档/读档架构（World3 局部）

入口在 `world3_boss_arena.gd`：

- 导出：`to_dict()`
  - 玩家、主马、驷马、小马状态
  - 当前阶段、共享血量
  - 交互物状态、随机拼块状态
  - `intro_battle_triggered`、`si_split_triggered`
- 恢复：`from_dict()`
  - 先恢复节点基础状态
  - 通过 `PhaseController.ensure_saved_minors_present(...)` 补齐存档中的小马节点
  - 再依据阶段/血量/触发标记选择战斗恢复路径

设计目标是：读档后不重演开场门控，直接回到正确战斗态。

---

## 6) 随机拼块子系统

`world3_random_piece_builder.gd` 的职责：

- 按 seed 选择拼块序列（可重复或无重复）
- 基于每块 `start/over` 锚点进行连续拼接
- 仅加载邻域块，超出邻域块卸载（流式）
- 支持拼块运行态缓存恢复（含心剑交互等）

这套机制与 Boss 主战场并行，属于 World3 的“地形与交互扩展层”。

---

## 7) 关键脚本职责速查

- `world3_boss_arena.gd`
  - 关卡级 orchestrator：BGM、心剑点位、存读档桥接、坠落死亡
- `boss_horse_phase_controller.gd`
  - 阶段机 + 剧情演出编排 + 小马集合管理 + 相机接管
- `boss_horse_main.gd`
  - 主马技能调度、技能播报发射、分身技能循环
- `boss_horse_minor.gd`
  - 单色小马行为、黑马分身、离屏回场
- `boss_si.gd`
  - 驷马行为与碰撞击退接入
- `world3_random_piece_builder.gd`
  - 拼块生成、流式加载、状态恢复

---

## 8) 架构边界说明

- World3 的“战斗状态真源”在 `PhaseController`，其余模块尽量通过信号或方法调用与其对齐。
- `world3_boss_arena.gd` 是“场景桥接层”，不直接实现 Boss 技能逻辑，只做关卡级编排。
- Boss 子脚本（main/minor/si）负责“个体行为”，不负责全局存档策略与剧情总流程。

---

如需，我可以继续补一版“World3 调试入口图（调用链）”，按「读档 -> 阶段恢复 -> 小马补齐 -> 行为激活」画成流程图文档。
