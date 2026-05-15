extends Control

var run_state: RunState
var audio_node
var settings_popup: PopupPanel

func _ready() -> void:
	run_state = get_node("/root/RunStateNode")
	audio_node = get_node_or_null("/root/AudioNode")
	settings_popup = get_node_or_null("SettingsPopup")
	UIStyle.apply_to_scene(self)
	_play_bgm_menu()

	get_node("Margin/VBox/StartButton").pressed.connect(_on_start_pressed)
	get_node("Margin/VBox/SettingsButton").pressed.connect(_on_settings_pressed)
	get_node("Margin/VBox/ExitButton").pressed.connect(_on_exit_pressed)

	if settings_popup != null:
		settings_popup.close_requested.connect(_on_close_settings)
		var close_btn: Button = settings_popup.get_node_or_null("MarginContainer/VBox/CloseButton")
		if close_btn != null:
			close_btn.pressed.connect(_on_close_settings)

		var bgm_slider: HSlider = settings_popup.get_node_or_null("MarginContainer/VBox/BgmSlider")
		if bgm_slider != null:
			bgm_slider.value_changed.connect(_on_bgm_volume_changed)

		var sfx_slider: HSlider = settings_popup.get_node_or_null("MarginContainer/VBox/SfxSlider")
		if sfx_slider != null:
			sfx_slider.value_changed.connect(_on_sfx_volume_changed)

func _on_start_pressed() -> void:
	_play_sfx("sfx_card_click")
	run_state.reset_for_new_run()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _on_settings_pressed() -> void:
	_play_sfx("sfx_card_click")
	if settings_popup == null:
		return
	_sync_sliders_from_audio()
	settings_popup.popup_centered(Vector2(600, 480))

func _on_close_settings() -> void:
	if settings_popup != null:
		settings_popup.hide()

func _on_bgm_volume_changed(value: float) -> void:
	if audio_node == null:
		return
	var db := _slider_to_db(value)
	audio_node.call("set_bgm_volume_db", db)

func _on_sfx_volume_changed(value: float) -> void:
	if audio_node == null:
		return
	var db := _slider_to_db(value)
	audio_node.call("set_sfx_volume_db", db)

func _sync_sliders_from_audio() -> void:
	if settings_popup == null or audio_node == null:
		return
	var bgm_slider: HSlider = settings_popup.get_node_or_null("MarginContainer/VBox/BgmSlider")
	var sfx_slider: HSlider = settings_popup.get_node_or_null("MarginContainer/VBox/SfxSlider")
	if bgm_slider != null:
		var current_db: float = audio_node.call("get_bgm_volume_db") if audio_node.has_method("get_bgm_volume_db") else -14.0
		bgm_slider.value = _db_to_slider(current_db)
	if sfx_slider != null:
		var current_db: float = audio_node.call("get_sfx_volume_db") if audio_node.has_method("get_sfx_volume_db") else -8.0
		sfx_slider.value = _db_to_slider(current_db)

static func _slider_to_db(val: float) -> float:
	return (val / 100.0) * 40.0 - 40.0

static func _db_to_slider(db: float) -> float:
	return clamp((db + 40.0) / 40.0 * 100.0, 0.0, 100.0)

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
