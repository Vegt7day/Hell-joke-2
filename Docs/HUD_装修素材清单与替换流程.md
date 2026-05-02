# HUD 装修素材清单与替换流程

> 项目：文字地狱重制版
> 分辨率：640×360（`canvas_items` 拉伸模式）
> 引擎：Godot 4.6
> 最后更新：2026-05-02

---

## 一、当前 HUD 导航按钮现状分析

### 1.1 所在位置

**场景文件:** `entities/player/real player/student.tscn`
**CanvasLayer:** `ViewportHotbarHud` (layer=110)
**根节点:** `HotbarRoot` (Control, 脚本 = `viewport_nav_hud.gd`)

### 1.2 当前节点结构

```
ViewportHotbarHud (CanvasLayer, layer=110)
 └── HotbarRoot (Control, full-screen anchors, mouse_filter=IGNORE)
      ├── BtnMenuNav (Button)     ← 图标 + 文字 "菜单 [Esc]" 在一体内
      ├── BtnPackNav (Button)     ← 图标 + 文字 "背包 [B]"  在一体内
      ├── BtnMapNav (Button)      ← 图标 + 文字 "地图 [M]"  在一体内
      └── HotbarRow (HBoxContainer) ← 8 个快捷栏格子
```

### 1.3 当前按钮属性

| 按钮 | 图标 region (取自 `背包菜单地图.png`) | 文字 | 字号 | flat |
|------|---------------------------------------|------|------|------|
| BtnMenuNav | `Rect2(82, 18, 28, 28)` (28×28) | "菜单 [Esc]" | 16px | true |
| BtnPackNav | `Rect2(18, 16, 28, 32)` (28×32) | "背包 [B]" | 16px | 默认 |
| BtnMapNav | `Rect2(147, 19, 26, 26)` (26×26) | "地图 [M]" | 16px | 默认 |

**当前问题:** Button 的点击区域是整个按钮范围（含文字），无法做到"只有图标区域可点击、文字在图标下方"的布局。

---

## 二、改装目标结构

### 导航按钮结构方案（纯图标 + 下方文字）

导航按钮自身不需要九宫格背景，只需要可点击的图标区域和下方的像素文字。

```
HotbarRoot (Control, nav_hud.gd)
 ├── MenuBarBG (PanelContainer)       ← 新添，九宫格背景装饰（放置三个按钮的区域背景）
 │    theme_override_styles/panel = StyleBoxTexture(菜单栏背景.png)
 │    mouse_filter = 2  (IGNORE)
 │
 ├── MenuBtnGroup (HBoxContainer)    ← 新添，容纳三个按钮组
 │    ├── BtnGroup_Menu (VBoxContainer)
 │    │    ├── BtnMenu (TextureButton)
 │    │    │    texture_normal = AtlasTexture(菜单图标 region)
 │    │    │    expand = true
 │    │    │    stretch_mode = keep_centered
 │    │    │    custom_minimum_size = (28, 28)    ← 匹配图标尺寸
 │    │    └── LblMenu (Label)
 │    │         text = "菜单"
 │    │         horizontal_alignment = CENTER
 │    │         theme_override_fonts/font = FONT_12
 │    │         theme_override_font_sizes/font_size = 12
 │    │
 │    ├── BtnGroup_Pack (VBoxContainer)
 │    │    ├── BtnPack (TextureButton)
 │    │    │    texture_normal = AtlasTexture(背包图标 region)
 │    │    │    custom_minimum_size = (28, 32)
 │    │    └── LblPack (Label, text="背包", font=FONT_12)
 │    │
 │    └── BtnGroup_Map (VBoxContainer)
 │         ├── BtnMap (TextureButton)
 │         │    texture_normal = AtlasTexture(地图图标 region)
 │         │    custom_minimum_size = (26, 26)
 │         └── LblMap (Label, text="地图", font=FONT_12)
 │
 └── HotbarRow (HBoxContainer)        ← 不变
```

---

## 三、需准备的素材清单

### 3.1 导航按钮图标（已有）

| 素材 | 来源 | 尺寸 | 说明 |
|------|------|------|------|
| 菜单图标 | `背包菜单地图.png` region (82,18,28,28) | 28×28 | 已有，无需重做 |
| 背包图标 | `背包菜单地图.png` region (18,16,28,32) | 28×32 | 已有，无需重做 |
| 地图图标 | `背包菜单地图.png` region (147,19,26,26) | 26×26 | 已有，无需重做 |

### 3.2 菜单栏区域背景九宫格（用户已准备）

| 素材 | 用途 | 规格要求 |
|------|------|---------|
| 菜单栏背景九宫格图 | 3 个导航按钮的背景板 | 制作成 9-patch 图，预留 patch margin |

**九宫格图片制作要求：** 中间区域可拉伸，四角固定不拉伸，边缘宽度 >= 4px。

### 3.3 按钮九宫格背景图（三种状态）— 用于菜单按钮 / 背包操作按钮

导航按钮不需要，以下位置的按钮需要九宫格背景：

| 应用位置 | 场景文件 | 目标按钮 |
|---------|---------|---------|
| 暂停菜单按钮 | `system/ui/pause_menu.tscn` | BtnResume, BtnSettings, BtnLoad, BtnTitle, BtnQuit |
| 背包操作按钮 | `system/ui/inventory/inventory_ui.tscn` | BtnUse, BtnDrop, BtnUnequipSummon |
| 存档点按钮 | `system/ui/save_point_panel.tscn` | BtnSave, BtnTeleport, BtnCancel |
| 存档槽按钮 | `system/ui/save_slots_sheet.tscn` | BtnSlot1~3, BtnCancel |
| 确认弹窗按钮 | `system/ui/confirm_popup.tscn` | BtnConfirm, BtnCancel |
| 死亡重试按钮 | `system/ui/world3_death_retry_ui.tscn` | BtnHeart, BtnSavePoint |

每个按钮需要三种状态的九宫格背景图：

| 素材 | 用途 | 说明 |
|------|------|------|
| `按钮背景_正常.png` | `theme_override_styles/normal` | 默认态 |
| `按钮背景_悬停.png` | `theme_override_styles/hover` | 鼠标悬停态（可选，不设则自动变暗） |
| `按钮背景_按下.png` | `theme_override_styles/pressed` | 鼠标按下态（可选，不设则自动再变暗） |

三张图用相同的 patch_margin，仅颜色/亮度不同即可。

### 3.4 格子九宫格背景图

以下格子区域需要九宫格背景：

| 素材 | 用途 | 应用位置 |
|------|------|---------|
| `背包栏位格子.png` | 背包内 48 格每个格子的背景 | `inventory_ui.gd` 的 `_make_slot_panel()` 动态创建 |
| `背包栏位选中.png` | 背包格子选中状态高亮 | 同上 |
| `快捷栏格子.png` | 快捷栏 8 格格子背景 | `status_panel.gd` 的 `_build_hotbar_slots()` 动态创建 |
| `快捷栏选中.png` | 快捷栏格子选中状态高亮 | 同上 |

格子建议尺寸：快捷栏格子约 30x30，背包格子约 28x28，像素风四角对称。

### 3.5 字体（已有）

| 字体 | 路径 | 说明 |
|------|------|------|
| VonwaonBitmap-12px | `assets/资源总库/11_字体/VonwaonBitmap-12px.ttf` | 图标下方标注文字 |
| VonwaonBitmap-16px | `assets/资源总库/11_字体/VonwaonBitmap-16px.ttf` | 其他 UI 标题（已有） |

---

## 四、九宫格在 Godot 中的使用方式

### 方式 A：StyleBoxTexture（推荐，可控件皮肤）

1. 将九宫格图片导入到项目中
2. 选择目标节点（如 `PanelContainer`, `Button` 等）
3. 在 Inspector 中新建 `StyleBoxTexture`，设置 `texture`、`patch_margin`
4. 对按钮：设置 `theme_override_styles/normal` / `hover` / `pressed`
5. 对格子面板：设置 `theme_override_styles/panel`

### 方式 B：NinePatchRect（纯显示节点，不可复用）

直接添加 `NinePatchRect` 节点，设置 `texture` 和 `patch_margin`。

---

## 五、具体替换流程

### Step 1：准备素材文件

将以下素材放入 `assets/资源总库/03_图像_UI/` 下：
- `菜单栏背景.png`（导航按钮区域背景）
- `按钮背景_正常.png` / `_悬停.png` / `_按下.png`（按钮九宫格）
- `背包栏位格子.png` / `_选中.png`（背包格子）
- `快捷栏格子.png` / `_选中.png`（快捷栏格子）

### Step 2：修改 student.tscn — 重构导航按钮

**操作文件：** `entities/player/real player/student.tscn`

在 `HotbarRoot` 下：
- **2a.** 删除 `BtnMenuNav`, `BtnPackNav`, `BtnMapNav`
- **2b.** 添加 `MenuBarBG`（PanelContainer），应用九宫格样式
- **2c.** 添加 `MenuBtnGroup`（HBoxContainer），内含三个 `BtnGroup_xxx`（VBoxContainer），每个由 `TextureButton` + `Label` 组成

### Step 3：修改 viewport_nav_hud.gd

将 @onready 路径改为指向新的 `TextureButton` 节点。

### Step 4：给按钮添加九宫格背景（菜单/弹窗按钮）

逐个打开暂停菜单、背包、存档点等弹窗场景，为其中的 `Button` 节点添加 `theme_override_styles/normal/hover/pressed`，使用 `按钮背景_*.png`。

### Step 5：给格子添加九宫格背景

- 快捷栏：修改 `status_panel.gd` 中 `_build_hotbar_slots()`，用 `StyleBoxTexture` 替换 `StyleBoxFlat`
- 背包格子：修改 `inventory_ui.gd` 中 `_make_slot_panel()`，用 `StyleBoxTexture` 替换 `StyleBoxFlat`

### Step 6：运行测试 + 微调

调整位置、间距、格子尺寸。

---

## 六、涉及的所有文件清单

| 文件 | 功能 | 需要修改？ |
|------|------|-----------|
| `entities/player/real player/student.tscn` | 导航按钮结构 | **是** — 重构按钮、添加背景 |
| `entities/player/real player/viewport_nav_hud.gd` | 导航按钮点击响应 | **是** — 改节点路径 |
| `system/ui/inventory/inventory_ui.gd` | 背包格子动态创建 | **可选** — 格子换九宫格背景 |
| `system/ui/status_panel.gd` | 快捷栏格子动态创建 | **可选** — 格子换九宫格背景 |
| `system/ui/pause_menu.tscn` | 暂停菜单按钮 | **可选** — 加九宫格按钮背景 |
| `system/ui/inventory/inventory_ui.tscn` | 背包操作按钮 | **可选** — 加九宫格按钮背景 |
| `system/ui/save_point_panel.tscn` | 存档点按钮 | **可选** — 加九宫格按钮背景 |
| `system/ui/save_slots_sheet.tscn` | 存档槽按钮 | **可选** — 加九宫格按钮背景 |
| `system/ui/confirm_popup.tscn` | 确认弹窗按钮 | **可选** — 加九宫格按钮背景 |
| `system/ui/world3_death_retry_ui.tscn` | 死亡重试按钮 | **可选** — 加九宫格按钮背景 |
| `assets/资源总库/03_图像_UI/` | 新素材 | **新增** |
| `Docs/UI设计方案.md` | UI 设计方案总文档 | 可同步更新 |