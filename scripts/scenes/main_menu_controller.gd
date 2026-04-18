extends Control

var run_state: RunState

func _ready() -> void:
	run_state = get_node("/root/RunStateNode")

	get_node("Margin/VBox/StartButton").pressed.connect(_on_start_pressed)
	get_node("Margin/VBox/ExitButton").pressed.connect(_on_exit_pressed)

func _on_start_pressed() -> void:
	run_state.reset_for_new_run()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
