extends Control

var run_state: RunState
var audio_node
var settings_popup: PopupPanel

var _button_tweens: Dictionary = {}

func _ready() -> void:
	run_state = get_node("/root/RunStateNode")
	audio_node = get_node_or_null("/root/AudioNode")
	settings_popup = get_node_or_null("SettingsPopup")
	UIStyle.apply_to_scene(self)
	_play_bgm_menu()

	var start_btn := get_node("Margin/VBox/StartButton") as Button
	var settings_btn := get_node("Margin/VBox/SettingsButton") as Button
	var exit_btn := get_node("Margin/VBox/ExitButton") as Button

	start_btn.pressed.connect(_on_start_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

	_setup_button_animation(start_btn)
	_setup_button_animation(settings_btn)
	_setup_button_animation(exit_btn)

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

func _setup_button_animation(btn: Button) -> void:
	var half_w := btn.custom_minimum_size.x * 0.5
	var half_h := btn.custom_minimum_size.y * 0.5
	if half_w <= 0:
		half_w = 128
	if half_h <= 0:
		half_h = 48
	btn.pivot_offset = Vector2(half_w, half_h)

	btn.mouse_entered.connect(_on_button_mouse_entered.bind(btn))
	btn.mouse_exited.connect(_on_button_mouse_exited.bind(btn))
	btn.button_down.connect(_on_button_down.bind(btn))
	btn.button_up.connect(_on_button_up.bind(btn))

	var delay := 0.0
	if btn.name == "SettingsButton":
		delay = 0.08
	elif btn.name == "ExitButton":
		delay = 0.16
	btn.scale = Vector2(0.85, 0.85)
	btn.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.35).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "modulate:a", 1.0, 0.25).set_delay(delay)

func _on_button_mouse_entered(btn: Button) -> void:
	_kill_button_tween(btn)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.12)
	_button_tweens[btn.get_instance_id()] = tween

func _on_button_mouse_exited(btn: Button) -> void:
	_kill_button_tween(btn)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10)
	_button_tweens[btn.get_instance_id()] = tween

func _on_button_down(btn: Button) -> void:
	_kill_button_tween(btn)
	var tween: Tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.06)
	_button_tweens[btn.get_instance_id()] = tween

func _on_button_up(btn: Button) -> void:
	_kill_button_tween(btn)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
	_button_tweens[btn.get_instance_id()] = tween

func _kill_button_tween(btn: Button) -> void:
	var key := btn.get_instance_id()
	if _button_tweens.has(key):
		var old := _button_tweens[key] as Tween
		if old != null and old.is_valid():
			old.kill()
		_button_tweens.erase(key)

func _on_start_pressed() -> void:
	_play_sfx("sfx_card_click")
	run_state.reset_for_new_run()
	run_state.set_pending_cutscene("intro", "res://scenes/Map.tscn")
	get_tree().change_scene_to_file("res://scenes/Cutscene.tscn")

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
