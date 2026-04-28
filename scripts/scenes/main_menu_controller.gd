extends Control

var run_state: RunState
var audio_node

func _ready() -> void:
	run_state = get_node("/root/RunStateNode")
	audio_node = get_node_or_null("/root/AudioNode")
	UIStyle.apply_to_scene(self)
	_play_bgm_menu()

	get_node("Margin/VBox/StartButton").pressed.connect(_on_start_pressed)
	get_node("Margin/VBox/ExitButton").pressed.connect(_on_exit_pressed)

func _on_start_pressed() -> void:
	_play_sfx("sfx_card_click")
	run_state.reset_for_new_run()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _on_exit_pressed() -> void:
	_play_sfx("sfx_card_click")
	get_tree().quit()

func _play_bgm_menu() -> void:
	if audio_node == null:
		return
	audio_node.call("play_bgm", "bgm_menu")

func _play_sfx(sfx_id: String) -> void:
	if audio_node == null:
		return
	audio_node.call("play_sfx", sfx_id)
