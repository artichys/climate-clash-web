extends Control

var run_state: RunState

func _ready() -> void:
	run_state = get_node("/root/RunStateNode")

	var title: Label = get_node("Margin/VBox/ResultTitle")
	var detail: Label = get_node("Margin/VBox/ResultDetail")

	title.text = "VICTORY - Neo-Archipelago Saved" if run_state.last_run_won else "GAME OVER"
	detail.text = run_state.last_run_message if run_state.last_run_message != "" else "Run selesai."

	get_node("Margin/VBox/RestartButton").pressed.connect(_on_restart)
	get_node("Margin/VBox/MenuButton").pressed.connect(_on_menu)

func _on_restart() -> void:
	run_state.reset_for_new_run()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
