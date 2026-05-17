extends Control

const NODE_MAP_IMAGE_BASE_PATH := "res://assets/placeholders/ui/nodeMap"

var run_state: RunState
var info_label: Label
var node_list_label: Label
var node_map_texture: TextureRect
var audio_node

func _ready() -> void:
	run_state = get_node("/root/RunStateNode")
	audio_node = get_node_or_null("/root/AudioNode")
	UIStyle.apply_to_scene(self)
	_play_bgm_menu()
	info_label = get_node("Margin/VBox/InfoLabel")
	node_list_label = get_node("Margin/VBox/NodeListLabel")
	node_map_texture = get_node_or_null("Margin/VBox/NodeMapTexture")
	if node_map_texture == null:
		node_map_texture = TextureRect.new()
		node_map_texture.name = "NodeMapTexture"
		node_map_texture.custom_minimum_size = Vector2(0, 300)
		node_map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node_map_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		node_map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vbox := get_node("Margin/VBox") as VBoxContainer
		vbox.add_child(node_map_texture)
		var node_list_index := vbox.get_children().find(node_list_label)
		if node_list_index >= 0:
			vbox.move_child(node_map_texture, node_list_index)

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
	_update_node_map_stage_image()

func _update_node_map_stage_image() -> void:
	if node_map_texture == null:
		return

	var total_nodes := GameDatabase.get_run_nodes().size()
	if total_nodes <= 0:
		node_map_texture.texture = null
		node_map_texture.visible = false
		return

	var stage_number := clampi(run_state.current_node_index + 1, 1, total_nodes)
	var stage_image_path := "%s/%d.png" % [NODE_MAP_IMAGE_BASE_PATH, stage_number]
	if ResourceLoader.exists(stage_image_path):
		var tex := load(stage_image_path)
		if tex is Texture2D:
			node_map_texture.texture = tex as Texture2D
			node_map_texture.visible = true
			return

	node_map_texture.texture = null
	node_map_texture.visible = false

func _on_continue_pressed() -> void:
	_play_sfx("sfx_card_click")
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
