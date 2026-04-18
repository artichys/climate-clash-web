extends Control

var run_state: RunState

func _ready() -> void:
	run_state = get_node("/root/RunStateNode")
	UIStyle.apply_to_scene(self)

	get_node("Margin/VBox/HealButton").pressed.connect(_on_heal)
	get_node("Margin/VBox/CoolButton").pressed.connect(_on_cool)
	get_node("Margin/VBox/DrawButton").pressed.connect(_on_draw)

func _on_heal() -> void:
	run_state.heal_player(15)
	run_state.advance_node()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _on_cool() -> void:
	run_state.add_temperature(-3)
	run_state.advance_node()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _on_draw() -> void:
	run_state.add_pending_extra_draw(3)
	run_state.advance_node()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")
