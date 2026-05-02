# HUD UI 参考文档

> 项目：文字地狱重制版
> 分辨率：640×360（`canvas_items` 拉伸模式）
> 引擎：Godot 4.6
> 最后更新：2026-05-02

---

## 一、总叠层表

所有 UI 通过 CanvasLayer 的 `layer` 属性控制渲染顺序。值越大越靠上。

| Layer | UI 元素 | 脚本/场景 |
|-------|---------|-----------|
| 1 (默认) | 状态面板（血量/墨水） | `system/ui/status_panel.tscn` |
| 1 (默认) | Boss 血条 | `system/ui/boss_health_bar.tscn` |
| 1 (默认) | Dialogic 对话框 | `addons/dialogic/` |
| 64 | 苏醒覆盖层 | `system/levels/world.tscn` |
| 99 | Game 单例根节点 | `system/globals/game/game.tscn` |
| 100 | Boss 竞技场提示标签 | `world3_boss_arena.tscn` |
| 110 | ViewportHotbarHud（导航按钮 + 快捷栏） | `entities/player/real player/student.tscn` |
| 110 | Boss 致命攻击警告 | `system/levels/world3/ui/boss_fatal_warning.tscn` |
| 115 | 设置面板 | `system/ui/settings_panel.tscn` |
| 115 | 存档点面板 | `system/ui/save_point_panel.tscn` |
| 115 | 背包界面 | `system/ui/inventory/inventory_ui.tscn` |
| 115 | 抽象地图 | `system/ui/abstract_map/abstract_map_ui.tscn` |
| 120 | 暂停菜单 | `system/ui/pause_menu.tscn` |
| 125 | 存档槽表格 | `system/ui/save_slots_sheet.tscn` |
| 128 | 死亡重试 UI（World3） | `system/ui/world3_death_retry_ui.tscn` |
| 130 | 确认弹窗 | `system/ui/confirm_popup.tscn` |
| 200 | 全屏白色闪光 | `system/globals/game/game.gd`（动态创建） |

---

## 二、字体常量

所有 UI 使用的两个字体文件：

| 常量 | 文件 | 路径 |
|------|------|------|
| `FONT_12` | VonwaonBitmap-12px.ttf | `res://assets/资源总库/11_字体/VonwaonBitmap-12px.ttf` |
| `FONT_16` | VonwaonBitmap-16px.ttf | `res://assets/资源总库/11_字体/VonwaonBitmap-16px.ttf` |

加载方式（所有 UI 脚本通用模式）：
```gdscript
const FONT_12: FontFile = preload("res://assets/资源总库/11_字体/VonwaonBitmap-12px.ttf")
const FONT_16: FontFile = preload("res://assets/资源总库/11_字体/VonwaonBitmap-16px.ttf")
```

设置到 Label：
```gdscript
label.add_theme_font_override(&"font", FONT_12)
label.add_theme_font_size_override(&"font_size", 12)
```

---

## 三、常驻 HUD（游戏进行中始终显示）

### 3.1 状态面板 (StatusPanel)

**CanvasLayer 层:** 1（通过父节点 `student.tscn > CanvasLayer`，该层未显式设置 layer，默认为 1）
**脚本:** `system/ui/status_panel.gd`（extends Node2D）
**场景:** `system/ui/status_panel.tscn`

#### 节点树

```
CanvasLayer (student.tscn 内联, layer=1)
 │
 └── status panel (Node2D, uid=43131948, script=status_panel.gd)
      ├── child 0 ── HBoxContainer "Hearts"
      │                offset(32,32)~(352,64), separation=4
      │                └── [动态] HeartCell 实例 × N
      ├── child 1 ── HBoxContainer "Inks"
      │                offset(32,64)~(352,96), separation=4
      │                └── [动态] InkSlot 实例 × N
      ├── child 2 ── AudioStreamPlayer "HeartInkStinger" [bus="UI"]
      └── child 3 ── AudioStreamPlayer "InkRecoverSfx" [bus="UI", vol=-15.7dB]
```

#### 导出变量

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `stats` | `Stats` | null | 血量/墨水数据源 |
| `heart_cell_scene` | `PackedScene` | `heart_cell.tscn` | 每颗心的场景模板 |
| `max_hearts_cap` | `int` | 20 | 心形格上限（2 HP/格） |
| `ink_slot_scene` | `PackedScene` | `ink_slot.tscn` | 墨水格场景模板 |
| `ink_per_attack` | `int` | 1 | 每次攻击消耗的墨水格数 |
| `max_ink_slots_cap` | `int` | -1 | 墨水格上限（<=0 表示按 max_ink 生成） |
| `hotbar_row_path` | `NodePath` | `""` | 覆盖快捷栏 HBoxContainer 路径 |

#### @onready 变量

```gdscript
@onready var hearts_box: HBoxContainer = $Hearts
@onready var inks_box: HBoxContainer = $Inks
@onready var heart_ink_stinger: AudioStreamPlayer = get_node_or_null("HeartInkStinger")
@onready var ink_recover_sfx: AudioStreamPlayer = get_node_or_null("InkRecoverSfx")
```

#### 关键函数

**`func _ready() -> void`**
- 解析 `hotbar_row`（通过 `_resolve_hotbar_row()`）
- 创建 `_hotbar_style_normal` / `_hotbar_style_selected` 两个 StyleBoxFlat
- 调用 `_build_hotbar_slots()` 构建快捷栏格子
- 调用 `_bind_player_stats()` 绑定玩家数据
- deferred 调用 `_rebind_stats_next_frame()` 二次绑定
- 初始化心形格和墨水格显示

**`func _resolve_hotbar_row() -> HBoxContainer`** — 解析快捷栏容器路径
1. 如果 `hotbar_row_path` 非空，直接按路径查找
2. 否则：`get_parent()`（=`CanvasLayer`） → `.get_parent()`（=player） → `get_node("ViewportHotbarHud/HotbarRoot/HotbarRow")`

**`func _bind_player_stats() -> void`** — 绑定血量/墨水数据
- 优先级：玩家节点上的 `stats` 属性 → `Game.player_stats`
- 连接 `stats.health_changed` → `_on_health_changed`
- 连接 `stats.ink_changed` → `_on_ink_changed`

**`func _bind_inventory_ref() -> void`** — 绑定背包引用
- 获取玩家的 `PlayerInventory` 节点
- 连接 `inventory_changed` → `_refresh_hotbar_ui`
- 连接 `hotbar_selection_changed` → `_on_hotbar_selection_changed_inv`

**`func _build_hotbar_slots() -> void`** — 构建 8 个快捷栏格子
- 清空 `hotbar_row`
- 每个格子创建：`PanelContainer > Control > [TextureRect, Label(字符), Label(数量), ColorRect(静态遮罩), ColorRect(CD条)]`
- 详见 3.2 节

**`func _paint_hotbar_cell(idx: int, slot: Variant) -> void`** — 渲染单个快捷栏格子
- 设置图标/字符
- 设置数量文字

**`func _refresh_hotbar_ui() -> void`** — 刷新所有 8 个快捷栏格子
- 循环调用 `_paint_hotbar_cell`
- 根据 `_inv_ref.hotbar_selection` 应用选中/非选中样式

**`func _slot_char(item: InventoryItem) -> String`** — 获取物品显示字符
```gdscript
match item.id:
    &"summon_shangyang": return "商"
    &"summon_zhong":     return "重"
    &"summon_hui":       return "恢"
    _:                   return item.name[-1]
```

**`func consume_ink_once() -> bool`** — 公开 API，供玩家调用消耗一格墨水
- 返回 false 表示墨水不足
- 扣除 `stats.ink`，UI 通过信号响应

**`func _on_health_changed() -> void`** — 血量变动响应
- 设置 `_target_health`
- 启动心形格动画队列

**`func _run_health_animation_queue() -> void`** — 血量变动动画队列（逐格动画）

**`func _on_ink_changed() -> void`** — 墨水变动响应
- 减少时启动 `_run_pending_ink_uses()`（消耗动画串行队列）
- 增加时即时同步显示

**`func _update_hotbar_cd_bars(_delta: float) -> void`**（每帧 _process 调用）
- 获取玩家 `get_consumable_cooldown_ratio()`
- 在选中格的 CD 条 `ColorRect` 上显示从底部上升的冷却效果

#### 内部状态数组

| 数组 | 类型 | 说明 |
|------|------|------|
| `_cells` | `Array[HeartCell]` | 所有心形格实例 |
| `_ink_slots` | `Array[Node]` | 所有墨水格实例 |
| `_hotbar_frames` | `Array[PanelContainer]` | 8 个快捷栏面板 |
| `_hotbar_icons` | `Array[TextureRect]` | 8 个快捷栏图标 |
| `_hotbar_qtys` | `Array[Label]` | 8 个快捷栏字符文字 |
| `_hotbar_qty_overlays` | `Array[Label]` | 8 个快捷栏数量标签 |
| `_hotbar_static_masks` | `Array[ColorRect]` | 8 个静态灰色遮罩 |
| `_hotbar_cd_bars` | `Array[ColorRect]` | 8 个动态 CD 冷却条 |

---

### 3.2 快捷栏单格结构（hotbar slot）

**动态创建位置:** `status_panel.gd` 的 `_build_hotbar_slots()`

#### 节点树（每个格子独立）

```
PanelContainer (custom_min_size=30x30, mouse_filter=IGNORE)
 │ 样式: _hotbar_style_normal / _hotbar_style_selected
 │
 └── Control (size_flags=EXPAND_FILL, mouse_filter=IGNORE)
      ├── child 0 ── TextureRect
      │                custom_min_size=22x22, position=(4,4)
      │                expand_mode=IGNORE_SIZE, stretch_mode=KEEP_ASPECT_CENTERED
      │                ← 道具图标
      │
      ├── child 1 ── Label (字符)(_hotbar_qtys[i])
      │                anchor LTRB = (0,0,1,1)
      │                horizontal_alignment=CENTER
      │                vertical_alignment=CENTER
      │                font=FONT_16, font_size=22
      │                ← 无图标时显示物品首字，居中
      │
      ├── child 2 ── Label (数量)(_hotbar_qty_overlays[i])
      │                anchor LTRB = (0,0,1,1)
      │                horizontal_alignment=RIGHT
      │                vertical_alignment=BOTTOM
      │                margin_right=2, margin_bottom=1
      │                font=FONT_HOTBAR(=FONT_12), font_size=10
      │                ← 数量数字，固定在右下角
      │
      ├── child 3 ── ColorRect (静态遮罩)(_hotbar_static_masks[i])
      │                anchor LTRB = (0,0,1,1)
      │                color = (0.15, 0.15, 0.15, 0.35)
      │                ← 始终显示的灰色半透明盖层
      │
      └── child 4 ── ColorRect (CD条)(_hotbar_cd_bars[i])
                     anchor LB=(0,1,1,1), anchor_top=1.0
                     color = (0.3, 0.3, 0.3, 0.65)
                     visible=false
                     ← CD冷却时从底部上升填充
```

#### 内部渲染顺序

| 层级 | 节点 | 内容 |
|------|------|------|
| 1 (底层) | TextureRect | 道具图标 |
| 2 | Label (字符) | 物品首字（居中） |
| 3 | Label (数量) | 数量数字（右下角） |
| 4 | ColorRect 静态遮罩 | 灰色半透明盖层 |
| 5 (顶层) | ColorRect CD 条 | 冷却条（从底上升） |

#### 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 格子尺寸 | 30×30 | `PanelContainer.custom_minimum_size` |
| 图标尺寸 | 22×22 | 图标居中偏移 (4,4) |
| 字符字号 | 22px | FONT_16 |
| 数量字号 | 10px | FONT_12 |
| 静态遮罩颜色 | (0.15, 0.15, 0.15, 0.35) | 始终保持的盖层 |
| CD 条颜色 | (0.3, 0.3, 0.3, 0.65) | 冷却时显示 |

---

### 3.3 快捷栏导航按钮 (ViewportNavHud)

**CanvasLayer 层:** 110（通过父节点 `ViewportHotbarHud`，layer=110）
**脚本:** `entities/player/real player/viewport_nav_hud.gd`（extends Control）
**所属场景:** `entities/player/real player/student.tscn`

#### 节点树

```
CanvasLayer "ViewportHotbarHud" (student.tscn 内联, layer=110)
 │
 └── Control "HotbarRoot" (full-screen anchors, mouse_filter=IGNORE)
      │  script = viewport_nav_hud.gd
      │
      ├── child 1 ── Button "BtnMenuNav"
      │                offset=(-273.07,-244)~(-185.07,-208)
      │                text="菜单 [Esc]", font=FONT_16, font_size=16
      │                icon=AtlasTexture, flat=true, icon_alignment=1
      │                ← 左上角菜单按钮
      │
      ├── child 2 ── Button "BtnPackNav"
      │                anchors: top=0.5, bottom=0.5
      │                offset=(-272,-269)~(-152,-221)
      │                text="背包 [B]", font=FONT_16, font_size=16
      │                icon=AtlasTexture
      │                ← 左上角中间背包按钮
      │
      ├── child 3 ── Button "BtnMapNav"
      │                anchors: right=1, bottom=1
      │                offset=(-425,-320)~(-311,-278)
      │                text="地图 [M]", font=FONT_16, font_size=16
      │                icon=AtlasTexture
      │                ← 左下角地图按钮
      │
      └── child 4 ── HBoxContainer "HotbarRow"
                      anchors: center-center
                      ← 由 status_panel.gd 动态填充 8 个快捷栏格子
```

#### 关键函数

**`func _ready() -> void`** — 连接三个按钮的 pressed 信号

**`func _on_menu_pressed() -> void`** — 调用 `Game.open_pause_menu()`

**`func _on_pack_pressed() -> void`** — 调用 `Game.open_inventory_ui()`

**`func _on_map_pressed() -> void`** — 调用 `Game.open_abstract_map_ui()`

---

### 3.4 心形格 (HeartCell)

**CanvasLayer 层:** 1（父级状态面板）
**脚本:** `system/ui/heart_cell.gd`（class_name HeartCell, extends Control）
**场景:** `system/ui/heart_cell.tscn`

#### 节点树

```
HeartCell (Control, custom_min_size=32×32, cell_size=20×20)
 └── AnimatedSprite2D "Sprite"
      pos=(16,16)
      sprite_frames = "生命值ui.png" (32×32 区域)
```

#### 状态

| State | 值 | 含义 | 对应动画 |
|-------|-----|------|---------|
| empty | 0 | 该格无血量 | `empty` (1帧) |
| half | 1 | 该格 1 HP | `half` (1帧) |
| full | 2 | 该格 2 HP | `full` (1帧) |

规则：**2 HP = 1 颗心形格**，状态面板中血量除以 2 得到心形格数。

#### 动画表

| 动画名 | 帧数 | 速度 | 说明 |
|--------|------|------|------|
| `full` | 1 | 5 fps | 静态满血 |
| `half` | 1 | 5 fps | 静态半血 |
| `empty` | 1 | 5 fps | 静态空血 |
| `damage_1` | 7 | 20 fps | Full → Half 过渡 |
| `damage_2` | 7 | 20 fps | Half → Empty 过渡 |
| `heal_1` | 6 | 15 fps | Empty → Half 过渡 |
| `heal_2` | 6 | 15 fps | Half → Full 过渡 |

#### 关键函数

**`func set_state_instant(next_state: int) -> void`** — 直接跳到指定状态的静态帧
- 参数范围 0~2

**`func play_damage_step() -> Signal (await)`** — 播放一次受伤动画
- state=2 → 播 `damage_1` → state=1
- state=1 → 播 `damage_2` → state=0

**`func play_heal_step() -> Signal (await)`** — 播放一次恢复动画
- state=0 → 播 `heal_1` → state=1
- state=1 → 播 `heal_2` → state=2

---

### 3.5 墨水格 (InkSlot)

**CanvasLayer 层:** 1（父级状态面板）
**脚本:** `system/ui/ink_slot.gd`（class_name InkSlot, extends Control）
**场景:** `system/ui/ink_slot.tscn`

#### 节点树

```
InkSlot (Control, custom_min_size=32×32, slot_size=20×20)
 └── AnimatedSprite2D "Sprite"
      pos=(16,16)
      sprite_frames = "墨水ui.png" (32×32 区域)
```

#### 信号

**`recover_finished(slot: Node)`** — 墨水恢复动画完成时发出

#### 状态

| State | 值 | 含义 |
|-------|-----|------|
| empty | 0 | 墨水已消耗 |
| full | 1 | 墨水可用 |

#### 动画表

| 动画名 | 帧数 | 速度 | 说明 |
|--------|------|------|------|
| `full` | 1 | 5 fps | 静态满 |
| `empty` | 1 | 5 fps | 静态空 |
| `use` | 6 | 10 fps | 消耗动画（当前跳过，直接切 empty） |
| `recover` | 9 | 6 fps | 恢复动画（~1.5s） |

#### 关键函数

**`func set_state_instant(next_state: int) -> void`** — 直接跳到指定状态

**`func play_use_step() -> Signal (await)`** — 消耗墨水（跳过动画，直接设 empty）

**`func start_recover(snapshot: Dictionary = {}) -> void`** — 播放恢复动画
- 完成后设 state=1 并发出 `recover_finished(self)`
- `snapshot` 参数用于格子位置交换时继承动画进度

**`func abort_to_empty_instant() -> void`** — 中断恢复，直接设 empty

**`func snapshot_recover_progress() -> Dictionary`** — 快照当前恢复动画进度（用于格子交换）

---

### 3.6 Boss 血条 (BossHealthBar)

**CanvasLayer 层:** 1（通过父节点的 CanvasLayer）
**脚本:** `system/ui/boss_health_bar.gd`（extends Node2D）
**场景:** `system/ui/boss_health_bar.tscn`

#### 节点树

```
boss_health_bar (Node2D, pos=(320,-32))
 ├── child 0 ── TextureProgressBar "healthbar"
 │                anchors: center-center
 │                offset=(-192,91)~(192,155)
 │                max_value=1.0, step=0.0
 │                texture_over = "boss_health.png" (边框)
 │                texture_progress = "boss_health.png" (进度)
 │                texture_progress_offset = (11,4)
 │
 ├── child 1 ── Sprite2D (静态名称)
 │                pos=(0,73), texture="老师的怒火.png"
 │
 └── child 2 ── AnimatedSprite2D "NameAnimatedSprite2D"
                 pos=(1,69), visible=false
                 ← 可用作动态名称卡片（未配置）
```

#### 导出变量

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `stats` | `Stats` | null | Boss 血量数据 |
| `auto_initialize` | `bool` | true | 自动重试初始化 |
| `max_retry_count` | `int` | 10 | 最多重试次数 |
| `retry_delay` | `float` | 0.1 | 重试间隔秒数 |
| `boss_name_texture` | `Texture2D` | null | 静态 Boss 名称贴图 |
| `use_animated_name_card` | `bool` | false | 使用动画名称 |
| `boss_name_sprite_frames` | `SpriteFrames` | null | 名称动画帧 |
| `phase_health_thresholds` | `Array[float]` | [0.8, 0.6, 0.4, 0.2] | 阶段血量阈值 |
| `phase_animation_names` | `Array[StringName]` | 4 个阶段 | 各阶段触发动画 |
| `drop_tween_duration` | `float` | 0.45 | 扣血动画时长 |
| `heal_tween_duration` | `float` | 0.2 | 回血动画时长 |

#### 关键函数

**`func _ready() -> void`** — 设置名称贴图；`auto_initialize` 时延迟调用 `initialize_with_retry()`

**`func initialize_with_retry() -> void`** — 重试循环查找 `_find_stats_node()`，成功后调用 `_initialize_stats_success()`

**`func _initialize_stats_success() -> void`** — 连接 `stats.health_changed` → `update_health`，设置 `is_initialized=true`

**`func update_health() -> void`** — 计算 `stats.health / stats.max_health` → 用 Tween 动画更新 `health_bar.value`
- 扣血方向用 `drop_tween_duration` (0.45s)
- 回血方向用 `heal_tween_duration` (0.2s)
- Easing: `TRANS_SINE, EASE_OUT`

**`func _try_play_phase_name_animation(health_percentage: float) -> void`** — 到达阶段阈值时触发名称卡片动画

**公开 API:** `set_stats()`, `get_current_health()`, `get_max_health()`, `get_health_percentage()`, `show_health_bar()`, `hide_health_bar()`, `toggle_health_bar()`, `reset_health_bar()`, `get_stats_node()`, `is_initialized_successfully()`

---

## 四、弹窗类 UI（打开背包/设置/地图时显示）

### 4.1 背包界面 (InventoryUi)

**CanvasLayer 层:** 115
**脚本:** `system/ui/inventory/inventory_ui.gd`（extends CanvasLayer）
**场景:** `system/ui/inventory/inventory_ui.tscn`

#### 常量

| 常量 | 值 | 说明 |
|------|-----|------|
| `INV_GRID_COLS` | 8 | 网格列数 |
| `INV_GRID_ROWS` | 6 | 网格行数 |
| `SLOTS_PER_PAGE` | 48 | 每页格子数 |
| `INV_PAGES` | 3 | 总页数 |
| `INV_SLOT_COUNT` | 144 | 总格数 |
| `SLOT_PANEL_SZ` | Vector2(28,28) | 每格面板尺寸 |
| `SLOT_ICON_SZ` | Vector2(22,22) | 图标尺寸 |

#### 节点树

```
CanvasLayer "InventoryUi" (layer=115, script=inventory_ui.gd)
 │
 └── child 0 ── Control "Root" (full-screen anchors)
      │
      ├── child 0 ── ColorRect "DimBG"
      │                full-screen anchors, mouse_filter=STOP
      │                color = (0.06, 0.06, 0.08, 0.82)
      │                ← 全屏背景暗化层
      │
      └── child 1 ── CenterContainer "Center"
           │
           └── child 0 ── PanelContainer "MainPanel"
                          custom_min_size=(608, 328)  ← 固定面板尺寸
                          layout_mode=2 (ContainerSized)
                │
                └── child 0 ── VBoxContainer "MainVBox"
                               theme_override/separation=8
                     │
                     ├── child 0 ── Label "TitleLabel"
                     │                text="背包"
                     │                font=FONT_16, font_size=24
                     │                color=white, horizontal_alignment=CENTER
                     │                ← 标题文字
                     │
                     ├── child 1 ── HBoxContainer "BodyHBox"
                     │                size_flags_vertical=3, separation=10
                     │    │
                     │    ├── child 0 ── Control "LeftGrow"
                     │    │                size_flags_horizontal=3
                     │    │    └── CenterContainer "PageCenter"
                     │    │         └── VBoxContainer "LeftColumn"
                     │    │              separation=6
                     │    │    │
                     │    │    ├── child 0 ── Label "HotbarHint"
                     │    │    │                text="快捷栏：1–8 切换选中格"
                     │    │    │                font=FONT_12, font_size=11
                     │    │    │                horizontal_alignment=CENTER
                     │    │    │
                     │    │    ├── child 1 ── HBoxContainer "HotbarRow"
                     │    │    │                separation=3, alignment=CENTER
                     │    │    │                └── [8× PanelContainer slots]
                     │    │    │                    由 _build_hotbar_cells() 动态创建
                     │    │    │
                     │    │    ├── child 2 ── GridContainer "SlotGrid"
                     │    │    │                columns=8, h_sep=3, v_sep=3
                     │    │    │                └── [48× PanelContainer slots]
                     │    │    │                    由 _build_grid_cells() 动态创建
                     │    │    │
                     │    │    └── child 3 ── HBoxContainer "PageNavRow"
                     │    │                   separation=10, alignment=CENTER
                     │    │         ├── Button "BtnPagePrev" (36×26, "<")
                     │    │         ├── Label "PageLabel" (96×?, "第 1 / 3 页")
                     │    │         └── Button "BtnPageNext" (36×26, ">")
                     │    │
                     │    └── child 1 ── VBoxContainer "RightVBox"
                     │                   custom_min_size=(218, 0)
                     │                   size_flags_vertical=3
                     │         └── PanelContainer "DetailPanel"
                     │              size_flags_vertical=3
                     │              └── VBoxContainer "DetailVBox"
                     │                   separation=6
                     │                ├── child 0 ── TextureRect "ItemIconLarge"
                     │                │                custom_min_size=(96,96)
                     │                │                expand_mode=1, stretch_mode=5
                     │                │                ← 物品大图标
                     │                │
                     │                ├── child 1 ── Label "ItemNameLabel"
                     │                │                font=FONT_16, font_size=15
                     │                │                color=white, horizontal_alignment=CENTER
                     │                │                autowrap_mode=ARBOREAL
                     │                │                ← 物品名称
                     │                │
                     │                └── child 2 ── Label "ItemDescLabel"
                     │                                custom_min_size=(190,108)
                     │                                font=FONT_12, font_size=11
                     │                                color=(0.9,0.9,0.9), autowrap_mode=ARBOREAL
                     │                                ← 物品描述
                     │
                     └── child 2 ── HBoxContainer "BtnRow"
                                     alignment=CENTER, separation=10
                          ├── Button "BtnUse" (78×28, "使用")
                          ├── Button "BtnDrop" (78×28, "丢弃")
                          └── Button "BtnUnequipSummon" (92×28, "卸下召唤")
```

#### 背包单格面板（由 `_make_slot_panel()` 动态创建）

```
PanelContainer (custom_min_size=28×28, mouse_filter=STOP)
 │
 └── Control (size_flags=EXPAND_FILL, mouse_filter=IGNORE)
      │
      ├── child 0 ── TextureRect
      │                custom_min_size=22×22
      │                pos=(3,3) [居中偏移]
      │                expand_mode=IGNORE_SIZE, stretch_mode=KEEP_ASPECT_CENTERED
      │                ← 道具图标
      │
      ├── child 1 ── Label "char_lb" (字符)
      │                anchor LTRB=(0,0,1,1)
      │                horizontal_alignment=CENTER, vertical_alignment=CENTER
      │                ← 无图标时显示物品首字，居中（第二层）
      │
      └── child 2 ── Label "count_lb" (数量)
                     anchor LTRB=(0,0,1,1)
                     horizontal_alignment=RIGHT, vertical_alignment=BOTTOM
                     font=FONT_12, font_size=9
                     ← 堆叠数量 >1 时显示，右下角（顶层）
```

#### 关键函数

**`func _ready() -> void`**
- `process_mode = PROCESS_MODE_ALWAYS`
- `layer = 115`
- 创建正常/选中样式 `StyleBoxFlat`
- 绑定 `PlayerInventory` 信号
- 调用 `_build_hotbar_cells()`、`_build_grid_cells()`、`_apply_fonts()`
- 连接按钮信号

**`func _build_hotbar_cells() -> void`** — 动态创建 8 个快捷栏 PanelContainer（背包内的快捷栏行）

**`func _build_grid_cells() -> void`** — 动态创建 48 个网格 PanelContainer（6 行 × 8 列）

**`func _make_slot_panel() -> PanelContainer`** — 创建单格面板（详见上面的节点树）

**`func _panel_parts(panel: PanelContainer) -> Array`** — 从 PanelContainer 提取 [tr, char_lb, count_lb]

**`func _paint_slot(tr: TextureRect, char_lb: Label, count_lb: Label, slot: InventorySlot, is_drag_source: bool = false) -> void`** — 渲染单个格子的内容
- 有图标 → 显示图标，隐藏字符
- 无图标 → 显示物品首字（居中，FONT_16 size=19）
- 可堆叠且数量 >1 → 显示数量（右下角，FONT_12 size=9）

**`func _slot_char(item: InventoryItem) -> String`** — 同 3.1 的 `_slot_char`

**`func _refresh_all() -> void`** — 全量刷新（选择同步 + 快捷键 + 网格 + 详情）

**`func _refresh_hotbar_cells_only() -> void`** — 刷新快捷栏行

**`func _refresh_grid_cells_only() -> void`** — 刷新当前页网格

**`func _refresh_selection_and_detail() -> void`** — 刷新选中态和右侧详情面板

**`func _hotbar_detail(slot: InventorySlot) -> void`** — 更新右侧详情面板内容

**`func _create_drag_preview(slot: InventorySlot) -> void`** — 创建拖拽预览面板

**`func _finish_grid_drag() -> void`** — 完成拖拽（检测目标位置并执行交换）

**`func _on_grid_panel_gui(local_on_page: int, ev: InputEvent) -> void`** — 网格格子的鼠标输入

**`func _on_item_slot_gui(hotbar_idx: int, ev: InputEvent) -> void`** — 快捷栏格子的鼠标输入

**`func _handle_grid_navigation(event: InputEvent) -> bool`** — 键盘导航（方向键/WASD）

**`func _apply_use() -> void`** — 使用当前选中物品

**`func _input(event: InputEvent) -> void`** — 全局输入处理
- `ui_inventory` / `ui_cancel` → 关闭
- 数字键 1-8 → 切换快捷栏选中格
- Q → 将背包选中格分配到当前快捷栏位
- 滚轮 → 切换快捷栏选中格
- `ui_accept` / Space → 使用物品

---

### 4.2 设置面板 (SettingsPanel)

**CanvasLayer 层:** 115
**脚本:** `system/ui/settings_panel.gd`（extends CanvasLayer）+ `system/ui/settings_body.gd`（extends Control）
**场景:** `system/ui/settings_panel.tscn`

#### 节点树

```
CanvasLayer "SettingsPanel" (layer=115, script=settings_panel.gd)
 │
 ├── child 0 ── Control "Root" (full-screen anchors)
 │    │
 │    ├── child 0 ── ColorRect "DimBG"
 │    │                full-screen, color=(0.102,0.102,0.102,0.85)
 │    │
 │    └── child 1 ── CenterContainer "Center"
 │         │
 │         └── child 0 ── SettingsBody (instance: settings_body.tscn)
 │                         script=settings_body.gd
 │              │
 │              └── CenterContainer "Center"
 │                   └── VBoxContainer "VBox"
 │                        ├── Label "TitleLabel" ("设置", font_size=32)
 │                        │
 │                        ├── VBoxContainer "AudioSection"
 │                        │    ├── Label "AudioHint" ("音量", font_size=12)
 │                        │    ├── HBox "MasterRow" → Label "LblMaster" + HSlider
 │                        │    ├── HBox "BgmRow"    → Label "LblBgm"    + HSlider
 │                        │    ├── HBox "SfxRow"    → Label "LblSfx"    + HSlider
 │                        │    └── HBox "UiRow"     → Label "LblUi"     + HSlider
 │                        │
 │                        ├── VBoxContainer "DisplaySection"
 │                        │    ├── Label "DisplayHint" ("显示", font_size=12)
 │                        │    ├── CheckBox "CheckFullscreen" ("全屏")
 │                        │    └── HBox "ResolutionRow" → Label "LblRes" + OptionButton
 │                        │
 │                        └── Button "BtnBack" (240×40, "返回")
```

#### 关键变量（settings_body.gd）

```gdscript
signal close_requested

const SETTINGS_UI_GROUP := &"settings_ui"
const WINDOW_PRESETS: Array[Vector2i] = [640×360, 960×540, ...]  # 13种预设
const WINDOW_PRESET_LABELS: PackedStringArray

@onready var slider_master, slider_bgm, slider_sfx, slider_ui: HSlider
@onready var check_fullscreen: CheckBox
@onready var option_resolution: OptionButton
@onready var btn_back: Button
```

#### 关键函数

**`settings_body.gd`:**
- `_ready()` → 连接信号，调用 `refresh_from_game()`
- `refresh_from_game()` → 从 Game 读取当前音量/全屏/分辨率设置，更新 UI 控件
- `_on_bus_slider_changed(bus_name, normalized)` → 设置音频总线音量并持久化
- `_on_fullscreen_toggled(pressed)` → 切换全屏
- `_on_resolution_selected(index)` → 切换分辨率
- `_request_close()` → 持续化设置后发出 `close_requested`

**`settings_panel.gd`:**
- `_ready()` → `layer=115`，连接 `close_requested`
- `_on_body_close_request()` → 移除 group，`queue_free()`

---

### 4.3 存档点面板 (SavePointPanel)

**CanvasLayer 层:** 115
**脚本:** `system/ui/save_point_panel.gd`（extends CanvasLayer）
**场景:** `system/ui/save_point_panel.tscn`

#### 节点树

```
CanvasLayer "SavePointPanel" (layer=115)
 │
 └── Control "Root" (full-screen)
      ├── child 0 ── ColorRect "DimBG"
      │                color=(0.08, 0.08, 0.1, 0.82)
      │
      └── child 1 ── Panel "Panel" (centered, 280×200)
           ├── Label "TitleLabel" (top-center, "存档点", font_size=18)
           └── VBoxContainer "VBox" (margins 16,48,16,12)
                ├── Button "BtnSave" → _on_save_pressed("存档")
                ├── Button "BtnTeleport" → _on_teleport_pressed("传送")
                └── Button "BtnCancel" → _on_cancel_pressed("取消")
```

#### 关键变量

```gdscript
const SAVE_POINT_PANEL_GROUP := &"save_point_choice_ui"
var _save_point: SavePointInteractable
var _opening_map_teleport := false
var _opening_save_slots_sheet := false
```

#### 关键函数

- `setup(save_point: SavePointInteractable)` → 传入存档点引用
- `_ready()` → `layer=115`，`process_mode=ALWAYS`
- `_on_save_pressed()` → 打开存档槽界面（SAVE 模式）
- `_on_teleport_pressed()` → 打开抽象地图（传送模式）
- `_on_cancel_pressed()` → `queue_free()`

---

### 4.4 抽象地图 (AbstractMapUI)

**CanvasLayer 层:** 115
**脚本:** `system/ui/abstract_map/abstract_map_ui.gd`（extends CanvasLayer）+ `system/ui/abstract_map/abstract_map_draw.gd`（class_name AbstractMapDraw, extends Control）
**场景:** `system/ui/abstract_map/abstract_map_ui.tscn`

#### 节点树

```
CanvasLayer "AbstractMapUI" (layer=115, script=abstract_map_ui.gd)
 │
 └── Control "Root" (full-screen)
      │
      ├── child 0 ── ColorRect "DimBG"
      │                color=(0.05, 0.05, 0.06, 0.88)
      │
      ├── child 1 ── MarginContainer (margins 20,16,20,16)
      │    └── HBoxContainer "MainHBox"
      │         ├── VBoxContainer "LeftVBox"
      │         │    ├── Label "TitleLabel" ("地图", font_size=22)
      │         │    └── Control "MapDraw" (min 480×280)
      │         │         script=abstract_map_draw.gd
      │         │         ← 自定义绘图区域，通过 _draw() 渲染
      │         │
      │         └── VSlider "ZoomSlider" (44×120, range 0.0~1.0, step 0.02)
      │
      └── child 2 ── Button "CloseButton" (top-right, "×", font_size=28)
```

#### 关键变量（abstract_map_ui.gd）

```gdscript
const CONFIRM_POPUP_SCENE := preload("res://system/ui/confirm_popup.tscn")
@onready var _draw_area: AbstractMapDraw
@onready var _zoom_slider: VSlider
@onready var _close_button: Button
```

#### 关键函数（abstract_map_ui.gd）

- `_ready()` → `layer=115`, `process_mode=ALWAYS`; 使用 `LevelMapScanner.scan_scene()` 扫描场景; 连接缩放/关闭信号
- `_close_map()` → `queue_free()`
- `_on_teleport_save_pick_requested(save_point_id, world_pos)` → 弹出确认弹窗后传送
- `_input(event)` → ESC/M 关闭

#### 关键变量（abstract_map_draw.gd）

```gdscript
signal zoom_normalized_changed(t: float)
signal teleport_save_pick_requested(save_point_id: String, world_pos: Vector2)

const _ZOOM_MUL_MIN := 0.2, _ZOOM_MUL_MAX := 10.0
const _CELL_PX_HARD_MIN := 2.0, _CELL_PX_HARD_MAX := 128.0

var _scan: Dictionary          # LevelMapScanner 输出
var _player_world: Vector2
var _min_g, _max_g: Vector2i   # 网格边界
var _fit_px: float             # 基础单元格像素
var _zoom_mul: float           # 缩放倍数
var _cell_px: float            # 有效单元格像素
var _teleport_pick_mode: bool
```

#### 关键函数（abstract_map_draw.gd）

- `set_scan(scan, player_global, scene_name)` → 加载扫描数据，初始缩放，重绘
- `set_teleport_pick_mode(on: bool)` → 启用/禁用传送点击
- `get_zoom_normalized() -> float` → 将 `_zoom_mul` 映射到 [0,1]
- `apply_zoom_normalized(t: float)` → 从滑块值恢复缩放
- `_draw()` → 渲染背景、地板(绿)、墙壁(灰)、机关(按类型着色)、玩家(红圈)
- `_gui_input(event)` → 拖拽平移、滚轮缩放、点击传送

---

## 五、菜单类 UI（暂停/存档/死亡）

### 5.1 暂停菜单 (PauseMenu)

**CanvasLayer 层:** 120
**脚本:** `system/ui/pause_menu.gd`（class_name PauseMenu, extends CanvasLayer）
**场景:** `system/ui/pause_menu.tscn`

#### 节点树

```
CanvasLayer "PauseMenu" (layer=120, script=pause_menu.gd)
 │
 └── Control "Root" (full-screen)
      │
      ├── child 0 ── ColorRect "DimBG"
      │                color=(0.102, 0.102, 0.102, 0.8)
      │
      └── child 1 ── CenterContainer "Center"
           │
           ├── VBoxContainer "PageMain" (visible=true)
           │    ├── Label "TitleLabel" ("暂停", font_size=32)
           │    ├── Button "BtnResume" (240×40, "继续游戏")
           │    ├── Button "BtnSettings" (240×40, "设置")
           │    ├── Button "BtnLoad" (240×40, "读取存档")
           │    ├── Button "BtnTitle" (240×40, "返回标题画面")
           │    └── Button "BtnQuit" (240×40, "离开游戏")
           │
           └── PageSettings (instance: settings_body.tscn, visible=false)
```

#### 关键变量

```gdscript
@onready var page_main, page_settings, btn_resume, btn_settings, btn_load, btn_title, btn_quit
var _in_settings: bool = false
```

#### 关键函数

- `_ready()` → `layer=120`, `process_mode=ALWAYS`; 连接按钮信号; focus btn_resume
- `_close_pause()` → `queue_free()`, 设 `tree.paused = false`
- `close_pause_external()` → 公开封装，供存档槽加载后调用
- `_input(event)` → ESC 关闭; 在设置子页时 ESC 返回主菜单
- `_on_settings()` → 切换 PageMain / PageSettings
- `_on_load()` → 打开存档槽选择
- `_on_title()` → 确认弹窗 → `Game.return_to_title_screen()`
- `_on_quit()` → 确认弹窗 → `get_tree().quit()`

---

### 5.2 存档槽表格 (SaveSlotsSheet)

**CanvasLayer 层:** 125
**脚本:** `system/ui/save_slots_sheet.gd`（extends CanvasLayer）
**场景:** `system/ui/save_slots_sheet.tscn`

#### 节点树

```
CanvasLayer "SaveSlotsSheet" (layer=125, script=save_slots_sheet.gd)
 │
 └── Control "Root" (full-screen)
      ├── child 0 ── ColorRect "DimBG"
      │                color=(0.102, 0.102, 0.102, 0.75)
      │
      └── child 1 ── CenterContainer "Center"
           └── PanelContainer "Panel" (min_width=400)
                └── VBoxContainer "VBox"
                     ├── Label "TitleLabel"
                     │    text="选择存档槽位", font_size=16, centered
                     ├── Button "BtnSlot1" (372×52)
                     ├── Button "BtnSlot2" (372×52)
                     ├── Button "BtnSlot3" (372×52)
                     └── Button "BtnCancel" (372×36, "取消")
```

#### 关键变量

```gdscript
const SHEET_GROUP := &"save_slots_sheet"
var _mode: Game.SaveSlotsSheetMode     # SAVE 或 LOAD
var _pause_menu: Node = null
var _save_point_after_save: SavePointInteractable = null
```

#### 关键函数

- `setup(mode, pause_menu=null, save_point_after_save=null)` → 初始化模式和回调
- `_ready()` → `layer=125`, `process_mode=ALWAYS`; 连接按钮
- `_refresh_slot_buttons()` → 从 `Game.read_manual_save_slot_summary()` 读取 3 个槽位信息并更新按钮文字
- `_on_slot_pressed(index)` → SAVE 模式：确认覆盖 → `_perform_save()`；LOAD 模式：`_perform_load()`
- `_perform_save(slot_id)` → `Game.save_game()`
- `_perform_load(slot_id)` → `Game.load_game(true, slot_id)`

---

### 5.3 死亡重试 UI (World3DeathRetryUI)

**CanvasLayer 层:** 128
**脚本:** `system/ui/world3_death_retry_ui.gd`（extends CanvasLayer）
**场景:** `system/ui/world3_death_retry_ui.tscn`

#### 节点树

```
CanvasLayer "World3DeathRetryUI" (layer=128, script=xxx.gd)
 │
 ├── child 0 ── AudioStreamPlayer "UiSfx"
 │                stream="咔擦门窗.mp3", bus=UI, vol=-6dB
 │
 └── child 1 ── Control "Root" (full-screen)
      ├── child 0 ── ColorRect "DimBG"
      │                color=(0,0,0,1)   ← 全黑
      │
      └── child 1 ── CenterContainer "Center"
           └── VBoxContainer "VBox"
                ├── TextureRect "DeadTexture" (min 180×120, stretch=keep_centered)
                ├── Label "DeadLabel" ("死", font_size=56, white)
                └── VBoxContainer "Buttons"
                     ├── Button "BtnHeart" (320×48, "回到上一个心")
                     └── Button "BtnSavePoint" (320×48, "读取上一个存档点")
```

#### 关键变量

```gdscript
var _game: Node = null
@onready var dim_bg, dead_texture, dead_label, btn_heart, btn_savepoint, ui_sfx
```

#### 关键函数

- `_ready()` → `process_mode=ALWAYS`; 连接按钮; 刷新按钮状态
- `bind_game(game_node: Node)` → 存储 game 引用，刷新按钮
- `_refresh_heart_button_state()` → 有"心"存档时启用 BtnHeart
- `_refresh_savepoint_button_state()` → 有手动存档时启用 BtnSavePoint
- `_on_press_heart()` → 调用 `game.on_world3_death_choice_load_heart()`
- `_on_press_savepoint()` → 调用 `game.on_world3_death_choice_load_savepoint()`

---

## 六、叠加弹窗

### 6.1 确认弹窗 (ConfirmPopup)

**CanvasLayer 层:** 130
**脚本:** `system/ui/confirm_popup.gd`（class_name ConfirmPopup, extends CanvasLayer）
**场景:** `system/ui/confirm_popup.tscn`

#### 节点树

```
CanvasLayer "ConfirmPopup" (layer=130, script=confirm_popup.gd)
 │
 └── Control "Root" (full-screen)
      ├── child 0 ── ColorRect "DimBG"
      │                color=(0.102, 0.102, 0.102, 0.8)
      │
      └── child 1 ── Panel "Panel" (centered, 320×160)
           ├── Label "TitleLabel" (top-center, "确认", font_size=16)
           ├── Label "MessageLabel" (center, "消息内容", font_size=12, color=0.7)
           │   ← children index: 0=title, 1=message (正确索引取决于场景文件)
           ├── Button "BtnConfirm" (left, "确定", font_size=16)
           └── Button "BtnCancel" (right, "取消", font_size=16)
```

#### 信号

```gdscript
signal confirmed
signal cancelled
```

#### 关键变量

```gdscript
@onready var dim_bg, title_label, message_label, btn_confirm, btn_cancel
var _on_confirm: Callable
var _on_cancel: Callable
```

#### 公开 API

**`func show_confirm(title: String, message: String, on_confirm: Callable, on_cancel: Callable = Callable()) -> void`**
- 设置标题、消息和回调函数
- 调用后显示弹窗

**`func _on_confirm_pressed() -> void`** — 执行 `_on_confirm.call()`, `queue_free()`

**`func _on_cancel_pressed() -> void`** — 执行 `_on_cancel.call()`, `queue_free()`

---

### 6.2 Boss 致命攻击警告 (BossFatalWarning)

**CanvasLayer 层:** 110
**脚本:** `system/levels/world3/ui/boss_fatal_warning.gd`（extends CanvasLayer）
**场景:** `system/levels/world3/ui/boss_fatal_warning.tscn`

#### 节点树

```
CanvasLayer "BossFatalWarning" (layer=110, process_mode=PAUSABLE)
 │
 ├── child 0 ── ColorRect "Dim"
 │                full-screen, color animated: black→white→dark_red
 │
 ├── child 1 ── AnimatedSprite2D "PlaceholderSprite"
 │                pos=(576,200), scale=2x
 │
 ├── child 2 ── AnimationPlayer
 │                libraries: RESET + "warning" (5s duration)
 │
 └── child 3 ── RichTextLabel "WarningLabel"
                  centered 384×42
                  text: "注意：boss即将发动一次[color=#ff2a2a]致命攻击[/color]"
```

#### 信号

**`warning_finished`** — 警告动画播放完毕时发出

#### 关键变量

```gdscript
signal warning_finished
const _CANVAS_LAYER := 110
const _FATAL_WARNING_DURATION := 5.0
@onready var _anim: AnimationPlayer
```

#### 关键函数

- `_ready()` → `layer=110`, `process_mode=PAUSABLE`; 设置所有子控件的 `mouse_filter=IGNORE`; 播放 `"warning"` 动画
- `_on_animation_finished(anim_name)` → 如果是 `"warning"` 则发出 `warning_finished` 并 `queue_free()`
- `_emit_done()` → 发出 `warning_finished`, `queue_free()`

#### 动画 "warning"（5 秒）
- Track 0 — `WarningLabel:modulate:a` → 文字闪烁（alpha 0↔1, 周期 0.5s）
- Track 1 — `Dim:color` → 透明 → 白(0.92@0.2s) → 灰(0.36@0.5s) → 暗红(0.796@4s)

---

## 附录

### A. 常用 UI 模式

| 模式 | 说明 | 示例 |
|------|------|------|
| 标准弹窗 | CanvasLayer + Control(Root, fullscreen) + ColorRect(DimBG) + CenterContainer + MainPanel | 背包、设置、地图 |
| 叠加弹窗 | 在上层独立 CanvasLayer，不阻碍下层 paused 状态 | ConfirmPopup |
| HUD | 直接置于玩家 CanvasLayer 下，跟随视口 | StatusPanel, BossHP |
| 自定义绘制 | 通过 `_draw()` 手动渲染，控件负责输入处理 | AbstractMapDraw |

### B. StyleBoxFlat 配置模式

所有格子面板（背包格/快捷栏格）共用一种样式模式：

```gdscript
# 正常态
var normal := StyleBoxFlat.new()
normal.bg_color = Color(0.12, 0.12, 0.14, 0.92)
normal.set_border_width_all(1)
normal.border_color = Color(0.35, 0.35, 0.38, 1.0)

# 选中态
var selected := StyleBoxFlat.new()
selected.bg_color = Color(0.18, 0.22, 0.28, 0.95)
selected.set_border_width_all(2)
selected.border_color = Color(0.85, 0.78, 0.35, 1.0)
```

### C. 拖拽预览模式

背包内拖拽物品时创建临时预览面板：

```gdscript
# inventory_ui.gd _create_drag_preview()
var panel := PanelContainer.new()
panel.custom_minimum_size = SLOT_PANEL_SZ  # 28×28
panel.add_theme_stylebox_override("panel", _style_selected)
var lb := Label.new()
lb.custom_minimum_size = SLOT_PANEL_SZ
lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
if slot.item.icon != null:
    lb.text = ""
else:
    lb.text = _slot_char(slot.item)
panel.add_child(lb)
panel.global_position = get_viewport().get_mouse_position() + Vector2(8, 8)
add_child(panel)
```

### D. 快捷键绑定参考

| 按键 | 背包打开时 | 游戏世界中 |
|------|-----------|-----------|
| I / B | — | 打开/关闭背包 |
| ESC | 关闭当前 UI（按叠层顺序） | 打开暂停菜单 |
| M | 关闭地图 | 打开/关闭地图 |
| 1-8 | — | 选中快捷栏格子 |
| Q | 选中格→快捷栏 | — |
| E / Space | 使用选中物品 | 交互 |
| 方向键/ WASD | 导航网格 | — |
| 滚轮 | — | 切换快捷栏 |


> 本文档记录了所有 CanvasLayer 层 HUD UI 的节点结构、关键函数和参数。
> 修改对应 UI 前先查看此处确定需要改哪些文件。