class_name ConfirmPopup
extends CanvasLayer

signal confirmed
signal cancelled

@onready var dim_bg: ColorRect = $Root/DimBG
@onready var title_label: Label = $Root/Panel/TitleLabel
@onready var message_label: Label = $Root/Panel/MessageLabel
@onready var btn_confirm: Button = $Root/Panel/BtnConfirm
@onready var btn_cancel: Button = $Root/Panel/BtnCancel

var _on_confirm: Callable = Callable()
var _on_cancel: Callable = Callable()
var _pending_title: String = ""
var _pending_message: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	btn_confirm.pressed.connect(_on_confirm_pressed)
	btn_cancel.pressed.connect(_on_cancel_pressed)


func show_confirm(title: String, message: String, on_confirm: Callable, on_cancel: Callable = Callable()) -> void:
	_on_confirm = on_confirm
	_on_cancel = on_cancel
	_pending_title = title
	_pending_message = message
	# 须在 @onready 与 _ready 之后才能安全访问子节点；同一帧 add_child 后 _ready 可能尚未执行
	call_deferred("_apply_confirm_ui")


func _apply_confirm_ui() -> void:
	title_label.text = _pending_title
	message_label.text = _pending_message
	visible = true
	btn_cancel.call_deferred("grab_focus")


func _on_confirm_pressed() -> void:
	if _on_confirm.is_valid():
		_on_confirm.call()
	queue_free()


func _on_cancel_pressed() -> void:
	if _on_cancel.is_valid():
		_on_cancel.call()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()