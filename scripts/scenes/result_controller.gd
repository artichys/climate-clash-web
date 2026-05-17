extends Control

const WIN_BG_PATH := "res://assets/placeholders/ui/BG_Win.png"
const WIN_POPUP_PATH := "res://assets/placeholders/ui/popUpWin.png"
const LOSE_BG_PATH := "res://assets/placeholders/ui/BG_Defeat.png"
const LOSE_POPUP_PATH := "res://assets/placeholders/ui/popUpDefeat.png"

var run_state: RunState
var audio_node

func _ready() -> void:
	run_state = get_node("/root/RunStateNode")
	audio_node = get_node_or_null("/root/AudioNode")
	UIStyle.apply_to_scene(self)
	_play_bgm_menu()
	_apply_result_visuals()

	var title: Label = get_node_or_null("PopupImage/Margin/VBox/ResultTitle")
	if title == null:
		title = get_node_or_null("PopupImage/Margin/VBox/ResultTittle")
	if title == null:
		title = get_node_or_null("Margin/VBox/ResultTitle")
	if title == null:
		title = get_node_or_null("Margin/VBox/ResultTittle")

	var detail: Label = get_node_or_null("PopupImage/Margin/VBox/ResultDetail")
	if detail == null:
		detail = get_node_or_null("Margin/VBox/ResultDetail")
	if title == null or detail == null:
		push_error("Result scene node tidak lengkap. Periksa ResultTitle/ResultDetail.")
		return

	title.text = "VICTORY - Neo-Archipelago Saved" if run_state.last_run_won else "GAME OVER"
	detail.text = run_state.last_run_message if run_state.last_run_message != "" else "Run selesai."
	_play_sfx("sfx_victory" if run_state.last_run_won else "sfx_lose")

	var restart_button := get_node_or_null("PopupImage/Margin/VBox/RestartButton") as Button
	if restart_button == null:
		restart_button = get_node_or_null("Margin/VBox/RestartButton") as Button
	var menu_button := get_node_or_null("PopupImage/Margin/VBox/MenuButton") as Button
	if menu_button == null:
		menu_button = get_node_or_null("Margin/VBox/MenuButton") as Button
	if restart_button != null:
		restart_button.pressed.connect(_on_restart)
	if menu_button != null:
		menu_button.pressed.connect(_on_menu)

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

func _apply_result_visuals() -> void:
	var bg := get_node_or_null("Background") as TextureRect
	var popup := get_node_or_null("PopupImage") as TextureRect
	if bg == null or popup == null:
		return

	var is_win := run_state.last_run_won
	var bg_path := WIN_BG_PATH if is_win else LOSE_BG_PATH
	var popup_path := WIN_POPUP_PATH if is_win else LOSE_POPUP_PATH

	if ResourceLoader.exists(bg_path):
		var bg_tex := load(bg_path)
		if bg_tex is Texture2D:
			bg.texture = bg_tex as Texture2D

	if ResourceLoader.exists(popup_path):
		var popup_tex := load(popup_path)
		if popup_tex is Texture2D:
			popup.texture = popup_tex as Texture2D
