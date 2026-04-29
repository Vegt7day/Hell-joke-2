class_name BossDamageInteractable
extends Interactable

@export var phase_controller_path: NodePath = NodePath("../../../Systems/PhaseController")
@export var damage_percent: float = 0.2
@export var idle_anim_name: StringName = &"idle"
@export var hurt_anim_name: StringName = &"hurt"
@export var post_hurt_idle_anim_name: StringName = &"after hurt idle"

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _used: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = true
	_play_if_exists(idle_anim_name)


func interact() -> void:
	if _used:
		return
	# 须在关闭 monitoring 之前取重叠体，否则 get_overlapping_bodies() 为空
	var player := _overlapping_player()
	_used = true
	monitoring = false
	monitorable = false
	if player != null:
		if player.has_method("trigger_hit_shake_only"):
			player.trigger_hit_shake_only()
		player.unregister_interactable(self)
	super.interact()
	var phase := _resolve_phase_controller()
	if phase != null and phase.has_method("trigger_external_percent_damage"):
		var scene := get_tree().current_scene
		var intro_already_triggered_for_save := false
		if phase.has_method("is_intro_battle_triggered_for_save"):
			intro_already_triggered_for_save = bool(phase.call("is_intro_battle_triggered_for_save"))
		var skip_damage_this_use := false
		# 需求：只有在“尚未触发入场剧情并且首次心/剑交互”时才走无伤次数逻辑。
		# 如果读档/回到已进入战斗态，就不再阻止伤害。
		if not intro_already_triggered_for_save and scene != null and scene.has_method("consume_no_damage_heart_interaction_token"):
			skip_damage_this_use = bool(scene.call("consume_no_damage_heart_interaction_token"))
		# 第一次心/剑交互就先记录「主马/驷马已进入表演状态」，确保本次存档可恢复参战状态
		if phase.has_method("mark_intro_battle_triggered_for_save"):
			phase.call("mark_intro_battle_triggered_for_save")
		# 无伤次数内：本次仅记为使用，不扣血；否则正常扣血
		if not skip_damage_this_use:
			phase.call("trigger_external_percent_damage", damage_percent, String(name))
		if is_instance_valid(Game) and Game.has_method("save_game") and phase.has_method("get_shared_stats"):
			# 心/剑交互时把主角回满血，并把满血状态写入 heart 存档
			if player != null:
				var heal_id := "boss_damage_interact:%s" % str(get_instance_id())
				if player.has_method("recover_full_health_once"):
					player.call("recover_full_health_once", heal_id)
				elif player.has_method("recover_full_health"):
					player.call("recover_full_health")
			var st := phase.call("get_shared_stats") as Stats
			if st != null and st.max_health > 0:
				var predicted_drop: int = 0
				if not skip_damage_this_use:
					predicted_drop = max(1, int(round(float(st.max_health) * clampf(damage_percent, 0.01, 1.0))))
				var predicted_hp: int = max(st.health - predicted_drop, 0)
				var cur_percent := float(st.health) / float(st.max_health)
				var predicted_percent := float(predicted_hp) / float(st.max_health)
				var crosses_into_final_20 := cur_percent > 0.2 and predicted_percent <= 0.2
				if not crosses_into_final_20:
					var scn := get_tree().current_scene
					var target_minor := _resolve_newly_unlocked_minor_name(cur_percent, predicted_percent)
					_mark_piece_heart_used_state_before_save()
					if scn != null and scn.has_method("request_delayed_heart_save"):
						scn.call("request_delayed_heart_save", predicted_hp, target_minor)
					else:
						if scn != null and scn.has_method("set_pending_shared_hp_override_for_save"):
							scn.call("set_pending_shared_hp_override_for_save", predicted_hp)
						Game.save_game("heart")
	if animation_player != null and animation_player.has_animation(hurt_anim_name):
		animation_player.play(hurt_anim_name)
		await animation_player.animation_finished
	_play_if_exists(post_hurt_idle_anim_name)


func _resolve_phase_controller() -> Node:
	var by_path := get_node_or_null(phase_controller_path)
	if by_path != null:
		return by_path
	return get_tree().get_first_node_in_group("boss_phase_controller")


func _overlapping_player() -> Player:
	for body in get_overlapping_bodies():
		if body is Player:
			return body as Player
	return null


func _play_if_exists(anim_name: StringName) -> void:
	if animation_player != null and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)


func _mark_piece_heart_used_state_before_save() -> void:
	var piece := get_parent() as Node
	if piece == null or not piece.has_meta("piece_index"):
		return
	var idx := int(piece.get_meta("piece_index"))
	var builder := get_tree().get_first_node_in_group("world3_random_piece_builder")
	if builder == null:
		var scn := get_tree().current_scene
		if scn != null:
			builder = scn.get_node_or_null("Systems/RandomPieceBuilder")
	if builder != null and builder.has_method("mark_heart_used_on_piece_index"):
		builder.call("mark_heart_used_on_piece_index", idx)


func _resolve_newly_unlocked_minor_name(cur_percent: float, predicted_percent: float) -> StringName:
	if cur_percent > 0.8 and predicted_percent <= 0.8:
		return &"MinorWhite"
	if cur_percent > 0.6 and predicted_percent <= 0.6:
		return &"MinorBlack"
	if cur_percent > 0.4 and predicted_percent <= 0.4:
		return &"MinorRed"
	return StringName()


func export_save_state() -> Dictionary:
	return {
		"used": _used,
	}


func apply_save_state(state: Dictionary) -> void:
	_used = bool(state.get("used", false))
	var active := not _used
	# 在 body_entered / 物理 flush 期间不能同步改 monitoring，否则引擎报错
	set_deferred("monitoring", active)
	set_deferred("monitorable", active)
	if _used:
		call_deferred("_play_if_exists", post_hurt_idle_anim_name)
	else:
		call_deferred("_play_if_exists", idle_anim_name)
