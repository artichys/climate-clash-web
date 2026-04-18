extends Control

var run_state: RunState
var info_label: Label
var node_list_label: Label

func _ready() -> void:
	run_state = get_node("/root/RunStateNode")
	UIStyle.apply_to_scene(self)
	info_label = get_node("Margin/VBox/InfoLabel")
	node_list_label = get_node("Margin/VBox/NodeListLabel")

	get_node("Margin/VBox/ContinueButton").pressed.connect(_on_continue_pressed)
	get_node("Margin/VBox/BackButton").pressed.connect(_on_back_pressed)

	_refresh_view()

func _refresh_view() -> void:
	info_label.text = "HP: %d/%d | Temp: %d/%d | Deck: %d" % [
		run_state.current_hp,
		run_state.max_hp,
		run_state.temperature,
		run_state.temperature_max,
		run_state.deck_card_ids.size()
	]

	var text := "Node Progress:\n"
	for node in GameDatabase.get_run_nodes():
		var marker := ">>" if node.index - 1 == run_state.current_node_index else "  "
		var label := "Unknown"
		if node.node_type == GameEnums.NodeType.BATTLE:
			label = "Battle - %s" % str(node.enemy_kind)
		elif node.node_type == GameEnums.NodeType.EVENT:
			label = "Mini Event - Sanctuary of the Green"
		elif node.node_type == GameEnums.NodeType.BOSS:
			label = "Final Boss - Climate Collapse"

		text += "%s Node %d: %s\n" % [marker, node.index, label]

	node_list_label.text = text

func _on_continue_pressed() -> void:
	var node := run_state.get_current_node()
	if node == null:
		if run_state.last_run_message == "":
			run_state.mark_run_win("Semua node selesai.")
		get_tree().change_scene_to_file("res://scenes/Result.tscn")
		return

	if node.node_type == GameEnums.NodeType.EVENT:
		get_tree().change_scene_to_file("res://scenes/Event.tscn")
		return

	get_tree().change_scene_to_file(_get_battle_scene_for_node(node))

func _get_battle_scene_for_node(node: RunNodeData) -> String:
	if node.enemy_kind == GameEnums.EnemyType.FLOOD:
		return "res://scenes/BattleFlood.tscn"
	if node.enemy_kind == GameEnums.EnemyType.HEATWAVE:
		return "res://scenes/BattleHeatwave.tscn"
	return "res://scenes/BattleBoss.tscn"

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
