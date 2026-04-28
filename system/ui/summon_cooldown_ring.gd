extends Control

@export_range(0.0, 1.0) var cooldown_ratio: float = 0.0:
	set(v):
		cooldown_ratio = clampf(v, 0.0, 1.0)
		queue_redraw()

@export var radius: float = 20.0:
	set(v):
		radius = maxf(2.0, v)
		queue_redraw()

@export var thickness: float = 4.0:
	set(v):
		thickness = maxf(1.0, v)
		queue_redraw()

@export var ring_bg_color: Color = Color(0.15, 0.15, 0.15, 0.75):
	set(v):
		ring_bg_color = v
		queue_redraw()

@export var ring_fg_color: Color = Color(0.95, 0.9, 0.25, 1.0):
	set(v):
		ring_fg_color = v
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0 + thickness * 2.0, radius * 2.0 + thickness * 2.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var segments := 64
	draw_arc(center, radius, 0.0, TAU, segments, ring_bg_color, thickness, true)
	if cooldown_ratio <= 0.0:
		return
	# 从顶部开始顺时针填充：冷却比值越高，弧越长
	var from := -PI * 0.5
	var to := from + TAU * cooldown_ratio
	draw_arc(center, radius, from, to, segments, ring_fg_color, thickness, true)
