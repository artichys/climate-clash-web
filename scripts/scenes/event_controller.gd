extends Control

var run_state: RunState
var audio_node

func _ready() -> void:
	run_state = get_node("/root/RunStateNode")
	audio_node = get_node_or_null("/root/AudioNode")
	UIStyle.apply_to_scene(self)
	_play_bgm_menu()

	get_node("Margin/VBox/HealButton").pressed.connect(_on_heal)
	get_node("Margin/VBox/CoolButton").pressed.connect(_on_cool)
	get_node("Margin/VBox/DrawButton").pressed.connect(_on_draw)

func _on_heal() -> void:
	_play_sfx("sfx_heal")
	run_state.heal_player(15)
	run_state.advance_node()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _on_cool() -> void:
	_play_sfx("sfx_card_click")
	run_state.add_temperature(-3)
	run_state.advance_node()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _on_draw() -> void:
	_play_sfx("sfx_card_click")
	run_state.add_pending_extra_draw(3)
	run_state.advance_node()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _play_bgm_menu() -> void:
	if audio_node == null:
		return
	audio_node.call("play_bgm", "bgm_menu")

func _play_sfx(sfx_id: String) -> void:
	if audio_node == null:
		return
	audio_node.call("play_sfx", sfx_id)
