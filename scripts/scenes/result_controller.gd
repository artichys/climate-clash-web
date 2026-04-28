extends Control

var run_state: RunState
var audio_node

func _ready() -> void:
	run_state = get_node("/root/RunStateNode")
	audio_node = get_node_or_null("/root/AudioNode")
	UIStyle.apply_to_scene(self)
	_play_bgm_menu()

	var title: Label = get_node_or_null("Margin/VBox/ResultTitle")
	if title == null:
		title = get_node_or_null("Margin/VBox/ResultTittle")

	var detail: Label = get_node_or_null("Margin/VBox/ResultDetail")
	if title == null or detail == null:
		push_error("Result scene node tidak lengkap. Periksa ResultTitle/ResultDetail.")
		return

	title.text = "VICTORY - Neo-Archipelago Saved" if run_state.last_run_won else "GAME OVER"
	detail.text = run_state.last_run_message if run_state.last_run_message != "" else "Run selesai."
	_play_sfx("sfx_victory" if run_state.last_run_won else "sfx_lose")

	get_node("Margin/VBox/RestartButton").pressed.connect(_on_restart)
	get_node("Margin/VBox/MenuButton").pressed.connect(_on_menu)

func _on_restart() -> void:
	_play_sfx("sfx_card_click")
	run_state.reset_for_new_run()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _on_menu() -> void:
	_play_sfx("sfx_card_click")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _play_bgm_menu() -> void:
	if audio_node == null:
		return
	audio_node.call("play_bgm", "bgm_menu")

func _play_sfx(sfx_id: String) -> void:
	if audio_node == null:
		return
	audio_node.call("play_sfx", sfx_id)
