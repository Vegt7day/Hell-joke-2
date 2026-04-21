@tool
extends DialogicLayoutLayer

## This layout won't do anything on its own

@export_group("Main")
@export_subgroup("Text")
@export var text_size: int = 15
@export var text_color: Color = Color.BLACK
@export_file('*.ttf') var normal_font: String = ""
@export_file('*.ttf') var bold_font: String = ""
@export_file('*.ttf') var italic_font: String = ""
@export_file('*.ttf') var bold_italic_font: String = ""
@export var text_max_width: int = 300

@export_subgroup('Box')
@export var box_modulate: Color = Color.WHITE
@export var box_modulate_by_character_color: bool = false
@export var box_padding: Vector2 = Vector2(10,10)
@export_range(1, 999) var box_corner_radius: int = 25
@export_range(0.1, 5) var box_wobble_speed: float = 1
@export_range(0, 1) var box_wobble_amount: float = 0.5
@export_range(0, 1) var box_wobble_detail: float = 0.2

@export_subgroup('Behaviour')
@export var behaviour_distance: int = 50
@export var behaviour_direction: Vector2 = Vector2(1, -1)
@export var behaviour_mouse_filter: Control.MouseFilter




@export_group('Choices')
@export_subgroup('Choices Text')
@export var choices_text_size: int = 15
@export_file('*.ttf') var choices_text_font: String = ""
@export var choices_text_color: Color = Color.DARK_SLATE_GRAY
@export var choices_text_color_hover: Color = Color.DARK_MAGENTA
@export var choices_text_color_focus: Color = Color.DARK_MAGENTA
@export var choices_text_color_disabled: Color = Color.DARK_GRAY

@export_subgroup('Choices Layout')
@export var choices_layout_alignment := FlowContainer.ALIGNMENT_END
@export var choices_layout_force_lines: bool = false
@export_file('*.tres', "*.res") var choices_base_theme: String = ""

@export_subgroup('Behavior')
@export var maximum_choices: int = 5
@export_file('*.tscn') var choices_custom_button: String = ""

const TextBubble := preload("res://addons/dialogic/Modules/DefaultLayoutParts/Layer_Textbubble/text_bubble.gd")

var bubbles: Array[TextBubble] = []
var fallback_bubble: TextBubble = null

const textbubble_scene: PackedScene = preload("res://addons/dialogic/Modules/DefaultLayoutParts/Layer_Textbubble/text_bubble.tscn")

func add_bubble() -> TextBubble:
	var new_bubble: TextBubble = textbubble_scene.instantiate()
	
	# 修复：检查气泡是否已经有父节点
	if new_bubble.get_parent():
		print("警告：气泡已有父节点，正在检查场景树...")
		print("气泡父节点:", new_bubble.get_parent().name)
		print("气泡是否在场景树中:", new_bubble.is_inside_tree())
		
		# 如果气泡已经在场景树中，先将其从父节点移除
		if new_bubble.is_inside_tree():
			print("正在从场景树移除气泡...")
			new_bubble.get_parent().remove_child(new_bubble)
	
	# 修复：确保只添加一次
	if not is_instance_valid(new_bubble) or not is_instance_valid(self):
		print("错误：气泡或布局层无效")
		return null
	
	# 再次检查气泡是否还有父节点
	if new_bubble.get_parent():
		print("严重错误：气泡仍然有父节点，尝试强制移除")
		var parent = new_bubble.get_parent()
		parent.remove_child(new_bubble)
	
	# 检查当前布局层是否有效
	if not is_inside_tree():
		print("错误：布局层不在场景树中")
		return null
	
	# 添加气泡到布局层
	add_child(new_bubble)
	bubbles.append(new_bubble)
	
	print("气泡添加成功，当前气泡数量:", bubbles.size())
	return new_bubble

## Called by dialogic whenever export overrides might change
func _apply_export_overrides() -> void:
	pass

## Called by the base layer before opening the bubble
func bubble_apply_overrides(bubble:TextBubble) -> void:
	# TEXT FONT AND COLOR
	var rtl: RichTextLabel = bubble.text
	
	# 修复：添加空值检查
	if rtl == null or not is_instance_valid(rtl):
		print("错误：气泡文本节点为 null 或无效，无法应用主题覆盖")
		# 尝试延迟应用
		call_deferred("_apply_bubble_overrides_deferred", bubble)
		return
		
	rtl.add_theme_font_size_override(&'normal_font', text_size)
	rtl.add_theme_font_size_override(&"normal_font_size", text_size)
	rtl.add_theme_font_size_override(&"bold_font_size", text_size)
	rtl.add_theme_font_size_override(&"italics_font_size", text_size)
	rtl.add_theme_font_size_override(&"bold_italics_font_size", text_size)

	rtl.add_theme_color_override(&"default_color", text_color)

	if !normal_font.is_empty():
		rtl.add_theme_font_override(&"normal_font", load(normal_font) as Font)
	if !bold_font.is_empty():
		rtl.add_theme_font_override(&"bold_font", load(bold_font) as Font)
	if !italic_font.is_empty():
		rtl.add_theme_font_override(&"italics_font", load(italic_font) as Font)
	if !bold_italic_font.is_empty():
		rtl.add_theme_font_override(&"bold_italics_font", load(bold_italic_font) as Font)
	bubble.set(&'max_width', text_max_width)

	# BOX & TAIL COLOR - 只保留Group的颜色设置
	var tail_and_bg_group := (bubble.get_node("Group") as CanvasGroup)
	if tail_and_bg_group and is_instance_valid(tail_and_bg_group):
		tail_and_bg_group.self_modulate = box_modulate
		if box_modulate_by_character_color and bubble.current_character != null:
			tail_and_bg_group.self_modulate = bubble.current_character.color

	# 注意：我们已经删除了Background节点，所以移除相关Shader设置
	bubble.padding = box_padding

	# BEHAVIOUR
	bubble.safe_zone = behaviour_distance
	bubble.base_direction = behaviour_direction
	
	# 调用change_mouse_filter，添加空值检查
	if behaviour_mouse_filter != null:
		bubble.change_mouse_filter(behaviour_mouse_filter)



	# CHOICE SETTINGS
	if choices_layout_force_lines:
		bubble.add_choice_container(VBoxContainer.new(), choices_layout_alignment, choices_custom_button, maximum_choices)
	else:
		bubble.add_choice_container(HFlowContainer.new(), choices_layout_alignment, choices_custom_button, maximum_choices)

	var choice_theme: Theme = null
	if choices_base_theme.is_empty() or not ResourceLoader.exists(choices_base_theme):
		choice_theme = Theme.new()
		var base_style := StyleBoxFlat.new()
		base_style.draw_center = false
		base_style.border_width_bottom = 2
		base_style.border_color = choices_text_color
		choice_theme.set_stylebox(&'normal', &'Button', base_style)
		var focus_style := (base_style.duplicate() as StyleBoxFlat)
		focus_style.border_color = choices_text_color_focus
		choice_theme.set_stylebox(&'focus', &'Button', focus_style)
		var hover_style := (base_style.duplicate() as StyleBoxFlat)
		hover_style.border_color = choices_text_color_hover
		choice_theme.set_stylebox(&'hover', &'Button', hover_style)
		var disabled_style := (base_style.duplicate() as StyleBoxFlat)
		disabled_style.border_color = choices_text_color_disabled
		choice_theme.set_stylebox(&'disabled', &'Button', disabled_style)
		choice_theme.set_stylebox(&'pressed', &'Button', base_style)
	else:
		choice_theme = (load(choices_base_theme) as Theme)

	if !choices_text_font.is_empty():
		choice_theme.default_font = (load(choices_text_font) as Font)

	choice_theme.set_font_size(&'font_size', &'Button', choices_text_size)
	choice_theme.set_color(&'font_color', &'Button', choices_text_color)
	choice_theme.set_color(&'font_pressed_color', &'Button', choices_text_color)
	choice_theme.set_color(&'font_hover_color', &'Button', choices_text_color_hover)
	choice_theme.set_color(&'font_focus_color', &'Button', choices_text_color_focus)
	choice_theme.set_color(&'font_disabled_color', &'Button', choices_text_color_disabled)
	
	# 确保选择容器存在
	if bubble.choice_container and is_instance_valid(bubble.choice_container):
		bubble.choice_container.theme = choice_theme

func _apply_bubble_overrides_deferred(bubble:TextBubble) -> void:
	# 延迟应用覆盖，等待一帧后重试
	if not is_instance_valid(bubble):
		return
	
	await get_tree().process_frame
	
	# 再次检查气泡文本节点
	var rtl: RichTextLabel = bubble.text
	if rtl and is_instance_valid(rtl):
		print("延迟应用气泡覆盖成功")
		bubble_apply_overrides(bubble)
	else:
		print("错误：延迟应用后气泡文本节点仍为 null")
