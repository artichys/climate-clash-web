extends Control

const CARD_ART_BASE_PATH := "res://assets/placeholders/cards"
const PLAYER_ART_CANDIDATES: Array[String] = [
	"res://assets/placeholders/characters/mc.png",
	"res://assets/placeholders/characters/player.png",
	"res://icon.svg"
]
const HAND_CARD_SIZE := Vector2(240.0, 360.0)
const HAND_CARD_GAP := 16
const CARD_OVERLAY_TOP_HEIGHT := 46.0
const CARD_OVERLAY_BOTTOM_HEIGHT := 118.0
const CARD_HOVER_SCALE := Vector2(1.08, 1.08)
const CARD_PREVIEW_SIZE := Vector2(360.0, 540.0)
const CARD_PREVIEW_OFFSET := Vector2(28.0, -180.0)
const HAND_SHADOW_OFFSET := Vector2(6.0, 8.0)
const HAND_SHADOW_HOVER_OFFSET := Vector2(8.0, 11.0)
const HAND_SHADOW_ALPHA_NORMAL := 0.88
const HAND_SHADOW_ALPHA_HOVER := 1.0
const CARD_PREVIEW_SHADOW_OFFSET := Vector2(10.0, 12.0)
const SFX_HIT_PATH := "res://assets/placeholders/audio/sfx_hit.wav"
const CHAR_ATTACK_PATH := "res://assets/placeholders/characters/charMCAttack"
const CHAR_ATTACK_FRAME_COUNT := 17
const PLAYER_ATTACK_TOTAL_DURATION := 2.0
const PLAYER_ATTACK_HIT_TIME := 0.8
const PLAYER_ATTACK_DASH_DISTANCE := 600.0
const FLOOD_ATTACK_PATH := "res://assets/placeholders/characters/charFloodAttack"
const FLOOD_ATTACK_FRAME_COUNT := 18
const FLOOD_ATTACK_TOTAL_DURATION := 0.8
const FLOOD_ATTACK_DASH_DISTANCE := 56.0

var run_state: RunState
var audio_node
var deck_service: DeckService
var enemy: EnemyData

var rng := RandomNumberGenerator.new()

var enemy_hp: int
var enemy_turn_counter: int = 0

var player_energy: int = 0
var player_block: int = 0

var offensive_buff_this_combat: int = 0
var draw_bonus_next_turn: int = 0
var heal_next_turn: int = 0
var temporary_cost_reduction_this_turn: int = 0
var suppress_enemy_meter_gain_turns: int = 0

var is_player_turn: bool = false
var battle_finished: bool = false
var is_boss_battle: bool = false

var player_stats: Label
var enemy_stats: Label
var meter_label: Label
var energy_label: Label
var log_label: RichTextLabel
var meter_bar: TextureProgressBar
var hand_hbox: HBoxContainer
var end_turn_button: Button
var character_layer: Control
var player_mc: TextureRect
var enemy_mc: TextureRect
var player_mc_base_pos: Vector2 = Vector2.ZERO
var enemy_mc_base_pos: Vector2 = Vector2.ZERO
var player_idle_tween: Tween
var enemy_idle_tween: Tween
var card_art_cache: Dictionary = {}
var hand_hover_tweens: Dictionary = {}

var drag_preview_shadow_panel: Panel
var drag_preview_panel: Panel
var drag_preview_art: TextureRect
var drag_preview_cost_label: Label
var drag_preview_name_label: Label
var drag_preview_effect_label: Label
var drag_preview_active: bool = false
var sfx_hit_player: AudioStreamPlayer

var _attack_overlay: TextureRect
var _attack_frames: Array = []
var _attack_frame_index: int = 0
var _attack_timer: float = 0.0
var _attack_overlay_start_x: float = 0.0
var _enemy_attack_overlay: TextureRect
var _enemy_attack_frames: Array = []
var _enemy_attack_overlay_start_x: float = 0.0

var reward_panel: Control
var reward_button_a: Button
var reward_button_b: Button
var reward_card_a: CardData = null
var reward_card_b: CardData = null

func _ready() -> void:
	rng.randomize()
	run_state = get_node("/root/RunStateNode")
	audio_node = get_node_or_null("/root/AudioNode")

	_cache_ui_nodes()
	UIStyle.apply_to_scene(self)
	_bind_ui_events()
	_setup_drag_preview_panel()
	_setup_audio()
	_preload_attack_frames()

	var node := run_state.get_current_node()
	if node == null or node.enemy_kind == null:
		get_tree().change_scene_to_file("res://scenes/Map.tscn")
		return

	enemy = GameDatabase.get_enemy_by_type(node.enemy_kind)
	enemy_hp = enemy.max_hp
	is_boss_battle = node.node_type == GameEnums.NodeType.BOSS
	_play_combat_bgm()
	_setup_character_art()
	_preload_enemy_attack_frames()

	deck_service = DeckService.new(run_state.deck_card_ids)
	draw_bonus_next_turn += run_state.consume_pending_extra_draw()

	_log("Battle dimulai melawan %s." % enemy.display_name)
	_start_player_turn()

func _cache_ui_nodes() -> void:
	player_stats = get_node("Margin/VBox/TopRow/PlayerStats")
	enemy_stats = get_node("Margin/VBox/TopRow/EnemyStats")
	meter_bar = get_node("Margin/VBox/MeterBar")
	meter_label = get_node("Margin/VBox/MeterLabel")
	log_label = get_node("Margin/VBox/LogLabel")
	hand_hbox = get_node("Margin/VBox/HandScroll/HandHBox")
	energy_label = get_node("Margin/VBox/BottomRow/EnergyLabel")
	end_turn_button = get_node("Margin/VBox/BottomRow/EndTurnButton")
	character_layer = get_node_or_null("CharacterLayer")
	player_mc = get_node_or_null("CharacterLayer/PlayerMC")
	enemy_mc = get_node_or_null("CharacterLayer/EnemyMC")

	reward_panel = get_node("RewardPanel")
	reward_button_a = get_node_or_null("RewardPanel/RewardVBox/RewardButtons/RewardButtonA")
	reward_button_b = get_node_or_null("RewardPanel/RewardVBox/RewardButtons/RewardButtonB")

	if reward_button_a == null or reward_button_b == null:
		reward_button_a = get_node_or_null("RewardPanel/RewardButtons/RewardButton")
		reward_button_b = get_node_or_null("RewardPanel/RewardButtons/RewardButton2")

	meter_bar.max_value = run_state.temperature_max
	reward_panel.visible = false

func _bind_ui_events() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	if reward_button_a != null:
		reward_button_a.pressed.connect(_on_reward_a)
	if reward_button_b != null:
		reward_button_b.pressed.connect(_on_reward_b)

func _start_player_turn() -> void:
	if battle_finished:
		return

	is_player_turn = true
	player_energy = 3
	temporary_cost_reduction_this_turn = 0

	if heal_next_turn > 0:
		_play_sfx("sfx_heal")
		run_state.heal_player(heal_next_turn)
		_log("Efek heal next turn aktif: +%d HP." % heal_next_turn)
		heal_next_turn = 0

	deck_service.discard_hand()

	var draw_amount := 5 + draw_bonus_next_turn
	draw_bonus_next_turn = 0
	deck_service.draw_cards(draw_amount)

	_refresh_ui()

func _refresh_ui() -> void:
	player_stats.text = "Player HP: %d/%d | Block: %d" % [run_state.current_hp, run_state.max_hp, player_block]
	enemy_stats.text = "%s HP: %d/%d" % [enemy.display_name, enemy_hp, enemy.max_hp]

	meter_bar.value = run_state.temperature
	meter_label.text = "Temperature: %d/%d" % [run_state.temperature, run_state.temperature_max]
	energy_label.text = "Energy: %d/3" % player_energy

	end_turn_button.disabled = (not is_player_turn) or battle_finished
	_refresh_hand_buttons()

func _refresh_hand_buttons() -> void:
	hand_hbox.add_theme_constant_override("separation", HAND_CARD_GAP)
	_hide_drag_preview()

	for tween in hand_hover_tweens.values():
		if tween is Tween:
			(tween as Tween).kill()
	hand_hover_tweens.clear()

	for child in hand_hbox.get_children():
		child.queue_free()

	var hand := deck_service.get_hand()
	for i in range(hand.size()):
		var card := hand[i]
		var cost := _get_effective_cost(card)
		hand_hbox.add_child(_create_hand_card_view(card, i, cost))

func _create_hand_card_view(card: CardData, hand_index: int, effective_cost: int) -> Control:
	var card_root := Control.new()
	card_root.custom_minimum_size = HAND_CARD_SIZE + HAND_SHADOW_HOVER_OFFSET
	card_root.pivot_offset = HAND_CARD_SIZE * 0.5

	var shadow_panel := Panel.new()
	shadow_panel.name = "ShadowPanel"
	shadow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow_panel.layout_mode = 0
	shadow_panel.position = HAND_SHADOW_OFFSET
	shadow_panel.size = HAND_CARD_SIZE
	shadow_panel.modulate = Color(1.0, 1.0, 1.0, HAND_SHADOW_ALPHA_NORMAL)
	shadow_panel.add_theme_stylebox_override("panel", _make_card_shadow_style())
	card_root.add_child(shadow_panel)

	var card_surface := Panel.new()
	card_surface.layout_mode = 0
	card_surface.offset_right = HAND_CARD_SIZE.x
	card_surface.offset_bottom = HAND_CARD_SIZE.y
	card_surface.clip_contents = true
	card_surface.add_theme_stylebox_override("panel", _make_card_border_style(card))
	card_root.add_child(card_surface)

	var fallback_bg := ColorRect.new()
	fallback_bg.layout_mode = 1
	fallback_bg.anchors_preset = 15
	fallback_bg.anchor_right = 1.0
	fallback_bg.anchor_bottom = 1.0
	fallback_bg.grow_horizontal = 2
	fallback_bg.grow_vertical = 2
	fallback_bg.color = _get_card_type_color(card.type, 0.28)
	card_surface.add_child(fallback_bg)

	var art := TextureRect.new()
	art.layout_mode = 1
	art.anchors_preset = 15
	art.anchor_right = 1.0
	art.anchor_bottom = 1.0
	art.grow_horizontal = 2
	art.grow_vertical = 2
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = _get_card_art(card.id)
	card_surface.add_child(art)

	var top_overlay := ColorRect.new()
	top_overlay.layout_mode = 0
	top_overlay.anchor_right = 1.0
	top_overlay.offset_right = HAND_CARD_SIZE.x
	top_overlay.offset_bottom = CARD_OVERLAY_TOP_HEIGHT
	top_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	card_surface.add_child(top_overlay)

	var bottom_overlay := ColorRect.new()
	bottom_overlay.layout_mode = 0
	bottom_overlay.anchor_top = 1.0
	bottom_overlay.anchor_right = 1.0
	bottom_overlay.anchor_bottom = 1.0
	bottom_overlay.offset_top = -CARD_OVERLAY_BOTTOM_HEIGHT
	bottom_overlay.offset_right = HAND_CARD_SIZE.x
	bottom_overlay.offset_bottom = HAND_CARD_SIZE.y
	bottom_overlay.color = Color(0.0, 0.0, 0.0, 0.62)
	card_surface.add_child(bottom_overlay)

	var cost_label := Label.new()
	cost_label.layout_mode = 0
	cost_label.offset_left = 12.0
	cost_label.offset_top = 6.0
	cost_label.offset_right = HAND_CARD_SIZE.x - 12.0
	cost_label.offset_bottom = 36.0
	cost_label.text = "COST %d" % effective_cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_override("font", UIStyle.get_font())
	cost_label.add_theme_font_size_override("font_size", 20)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	card_surface.add_child(cost_label)

	var name_label := Label.new()
	name_label.layout_mode = 0
	name_label.offset_left = 12.0
	name_label.offset_top = HAND_CARD_SIZE.y - CARD_OVERLAY_BOTTOM_HEIGHT + 8.0
	name_label.offset_right = HAND_CARD_SIZE.x - 12.0
	name_label.offset_bottom = HAND_CARD_SIZE.y - 70.0
	name_label.text = card.display_name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.add_theme_font_override("font", UIStyle.get_font())
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	card_surface.add_child(name_label)

	var effect_label := Label.new()
	effect_label.layout_mode = 0
	effect_label.offset_left = 12.0
	effect_label.offset_top = HAND_CARD_SIZE.y - 68.0
	effect_label.offset_right = HAND_CARD_SIZE.x - 12.0
	effect_label.offset_bottom = HAND_CARD_SIZE.y - 10.0
	effect_label.text = _build_card_short_text(card)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	effect_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	effect_label.add_theme_font_override("font", UIStyle.get_font())
	effect_label.add_theme_font_size_override("font_size", 14)
	effect_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	card_surface.add_child(effect_label)

	var click_button := Button.new()
	click_button.layout_mode = 1
	click_button.anchors_preset = 15
	click_button.anchor_right = 1.0
	click_button.anchor_bottom = 1.0
	click_button.grow_horizontal = 2
	click_button.grow_vertical = 2
	click_button.flat = true
	click_button.text = ""
	click_button.focus_mode = Control.FOCUS_NONE
	click_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_button.tooltip_text = _build_card_text(card, effective_cost)

	var no_style := StyleBoxEmpty.new()
	click_button.add_theme_stylebox_override("normal", no_style)
	click_button.add_theme_stylebox_override("hover", no_style)
	click_button.add_theme_stylebox_override("pressed", no_style)
	click_button.add_theme_stylebox_override("focus", no_style)
	click_button.add_theme_stylebox_override("disabled", no_style)

	var can_play := is_player_turn and (not battle_finished) and (effective_cost <= player_energy)
	click_button.disabled = not can_play
	click_button.pressed.connect(_on_hand_card_pressed.bind(hand_index))
	click_button.mouse_entered.connect(_on_hand_card_mouse_entered.bind(card_root))
	click_button.mouse_exited.connect(_on_hand_card_mouse_exited.bind(card_root))
	click_button.button_down.connect(_on_hand_card_button_down.bind(card, effective_cost))
	click_button.button_up.connect(_on_hand_card_button_up)
	card_surface.add_child(click_button)

	if not can_play:
		card_root.modulate = Color(0.6, 0.6, 0.6, 0.9)

	return card_root

func _on_hand_card_pressed(hand_index: int) -> void:
	_try_play_card(hand_index)

func _on_hand_card_mouse_entered(card_root: Control) -> void:
	_set_hand_card_hover(card_root, true)

func _on_hand_card_mouse_exited(card_root: Control) -> void:
	_set_hand_card_hover(card_root, false)

func _set_hand_card_hover(card_root: Control, hovered: bool) -> void:
	if card_root == null:
		return

	var shadow_panel := card_root.get_node_or_null("ShadowPanel") as Panel

	var key := card_root.get_instance_id()
	if hand_hover_tweens.has(key):
		var old_tween: Variant = hand_hover_tweens.get(key)
		if old_tween is Tween:
			(old_tween as Tween).kill()

	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hand_hover_tweens[key] = tween

	if hovered:
		card_root.z_index = 40
		tween.tween_property(card_root, "scale", CARD_HOVER_SCALE, 0.13)
		if shadow_panel != null:
			tween.parallel().tween_property(shadow_panel, "position", HAND_SHADOW_HOVER_OFFSET, 0.13)
			tween.parallel().tween_property(shadow_panel, "modulate:a", HAND_SHADOW_ALPHA_HOVER, 0.13)
	else:
		tween.tween_property(card_root, "scale", Vector2.ONE, 0.11)
		if shadow_panel != null:
			tween.parallel().tween_property(shadow_panel, "position", HAND_SHADOW_OFFSET, 0.11)
			tween.parallel().tween_property(shadow_panel, "modulate:a", HAND_SHADOW_ALPHA_NORMAL, 0.11)
		tween.tween_callback(func() -> void:
			if card_root != null:
				card_root.z_index = 0
		)

func _on_hand_card_button_down(card: CardData, effective_cost: int) -> void:
	_show_drag_preview(card, effective_cost)

func _on_hand_card_button_up() -> void:
	_hide_drag_preview()

func _setup_drag_preview_panel() -> void:
	drag_preview_shadow_panel = Panel.new()
	drag_preview_shadow_panel.visible = false
	drag_preview_shadow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview_shadow_panel.z_index = 239
	drag_preview_shadow_panel.custom_minimum_size = CARD_PREVIEW_SIZE
	drag_preview_shadow_panel.size = CARD_PREVIEW_SIZE
	drag_preview_shadow_panel.add_theme_stylebox_override("panel", _make_preview_shadow_style())
	add_child(drag_preview_shadow_panel)

	drag_preview_panel = Panel.new()
	drag_preview_panel.visible = false
	drag_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview_panel.z_index = 240
	drag_preview_panel.custom_minimum_size = CARD_PREVIEW_SIZE
	drag_preview_panel.size = CARD_PREVIEW_SIZE
	drag_preview_panel.clip_contents = true
	drag_preview_panel.add_theme_stylebox_override("panel", _make_preview_border_style(GameEnums.CardType.OFFENSIVE))
	add_child(drag_preview_panel)

	var fallback_bg := ColorRect.new()
	fallback_bg.layout_mode = 1
	fallback_bg.anchors_preset = 15
	fallback_bg.anchor_right = 1.0
	fallback_bg.anchor_bottom = 1.0
	fallback_bg.grow_horizontal = 2
	fallback_bg.grow_vertical = 2
	fallback_bg.color = Color(0.08, 0.08, 0.12, 0.95)
	drag_preview_panel.add_child(fallback_bg)

	drag_preview_art = TextureRect.new()
	drag_preview_art.layout_mode = 1
	drag_preview_art.anchors_preset = 15
	drag_preview_art.anchor_right = 1.0
	drag_preview_art.anchor_bottom = 1.0
	drag_preview_art.grow_horizontal = 2
	drag_preview_art.grow_vertical = 2
	drag_preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	drag_preview_panel.add_child(drag_preview_art)

	var top_overlay := ColorRect.new()
	top_overlay.layout_mode = 0
	top_overlay.anchor_right = 1.0
	top_overlay.offset_right = CARD_PREVIEW_SIZE.x
	top_overlay.offset_bottom = 58.0
	top_overlay.color = Color(0.0, 0.0, 0.0, 0.58)
	drag_preview_panel.add_child(top_overlay)

	var bottom_overlay := ColorRect.new()
	bottom_overlay.layout_mode = 0
	bottom_overlay.anchor_top = 1.0
	bottom_overlay.anchor_right = 1.0
	bottom_overlay.anchor_bottom = 1.0
	bottom_overlay.offset_top = -172.0
	bottom_overlay.offset_right = CARD_PREVIEW_SIZE.x
	bottom_overlay.offset_bottom = CARD_PREVIEW_SIZE.y
	bottom_overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	drag_preview_panel.add_child(bottom_overlay)

	drag_preview_cost_label = Label.new()
	drag_preview_cost_label.layout_mode = 0
	drag_preview_cost_label.offset_left = 16.0
	drag_preview_cost_label.offset_top = 10.0
	drag_preview_cost_label.offset_right = CARD_PREVIEW_SIZE.x - 16.0
	drag_preview_cost_label.offset_bottom = 44.0
	drag_preview_cost_label.add_theme_font_override("font", UIStyle.get_font())
	drag_preview_cost_label.add_theme_font_size_override("font_size", 28)
	drag_preview_cost_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	drag_preview_panel.add_child(drag_preview_cost_label)

	drag_preview_name_label = Label.new()
	drag_preview_name_label.layout_mode = 0
	drag_preview_name_label.offset_left = 16.0
	drag_preview_name_label.offset_top = CARD_PREVIEW_SIZE.y - 160.0
	drag_preview_name_label.offset_right = CARD_PREVIEW_SIZE.x - 16.0
	drag_preview_name_label.offset_bottom = CARD_PREVIEW_SIZE.y - 94.0
	drag_preview_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drag_preview_name_label.add_theme_font_override("font", UIStyle.get_font())
	drag_preview_name_label.add_theme_font_size_override("font_size", 25)
	drag_preview_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	drag_preview_panel.add_child(drag_preview_name_label)

	drag_preview_effect_label = Label.new()
	drag_preview_effect_label.layout_mode = 0
	drag_preview_effect_label.offset_left = 16.0
	drag_preview_effect_label.offset_top = CARD_PREVIEW_SIZE.y - 94.0
	drag_preview_effect_label.offset_right = CARD_PREVIEW_SIZE.x - 16.0
	drag_preview_effect_label.offset_bottom = CARD_PREVIEW_SIZE.y - 14.0
	drag_preview_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drag_preview_effect_label.add_theme_font_override("font", UIStyle.get_font())
	drag_preview_effect_label.add_theme_font_size_override("font_size", 17)
	drag_preview_effect_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	drag_preview_panel.add_child(drag_preview_effect_label)

func _show_drag_preview(card: CardData, effective_cost: int) -> void:
	if drag_preview_panel == null:
		return

	drag_preview_panel.add_theme_stylebox_override("panel", _make_preview_border_style(card.type))
	drag_preview_art.texture = _get_card_art(card.id)
	drag_preview_cost_label.text = "COST %d" % effective_cost
	drag_preview_name_label.text = card.display_name
	drag_preview_effect_label.text = _build_card_text(card, effective_cost)
	if drag_preview_shadow_panel != null:
		drag_preview_shadow_panel.visible = true
	drag_preview_panel.visible = true
	drag_preview_active = true
	_update_drag_preview_position()

func _hide_drag_preview() -> void:
	drag_preview_active = false
	if drag_preview_shadow_panel != null:
		drag_preview_shadow_panel.visible = false
	if drag_preview_panel != null:
		drag_preview_panel.visible = false

func _process(_delta: float) -> void:
	if drag_preview_active:
		_update_drag_preview_position()

func _play_combat_bgm() -> void:
	if audio_node == null:
		return
	var bgm_id := "bgm_boss" if is_boss_battle else "bgm_battle"
	audio_node.call("play_bgm", bgm_id)

func _play_sfx(sfx_id: String) -> void:
	if audio_node == null:
		return
	audio_node.call("play_sfx", sfx_id)

func _setup_audio() -> void:
	if audio_node != null:
		return
	sfx_hit_player = get_node_or_null("SfxHitPlayer")
	if sfx_hit_player == null:
		sfx_hit_player = AudioStreamPlayer.new()
		sfx_hit_player.name = "SfxHitPlayer"
		add_child(sfx_hit_player)

	if not ResourceLoader.exists(SFX_HIT_PATH):
		return

	var stream := load(SFX_HIT_PATH)
	if stream is AudioStream:
		sfx_hit_player.stream = stream as AudioStream

func _play_hit_sfx() -> void:
	_play_sfx("sfx_hit")
	if audio_node != null:
		return
	if sfx_hit_player == null or sfx_hit_player.stream == null:
		return
	if sfx_hit_player.playing:
		sfx_hit_player.stop()
	sfx_hit_player.play()

func _preload_attack_frames() -> void:
	_attack_frames.clear()
	for i in range(1, CHAR_ATTACK_FRAME_COUNT + 1):
		var path := "%s/%d.png" % [CHAR_ATTACK_PATH, i]
		if ResourceLoader.exists(path):
			var tex := load(path)
			if tex is Texture2D:
				_attack_frames.append(tex)

	_attack_overlay = TextureRect.new()
	_attack_overlay.name = "PlayerAttackOverlay"
	_attack_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_attack_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_attack_overlay.visible = false
	if character_layer != null:
		character_layer.add_child(_attack_overlay)
	else:
		add_child(_attack_overlay)

func _play_player_attack_animation() -> void:
	if player_mc == null:
		return
	if _attack_frames.size() == 0:
		var t := create_tween()
		t.tween_property(player_mc, "position:x", player_mc_base_pos.x + 600.0, 0.09)
		t.tween_property(player_mc, "position:x", player_mc_base_pos.x, 0.11)
		return

	_attack_overlay.texture = _attack_frames[0]
	_attack_overlay.size = player_mc.size
	_attack_overlay.expand_mode = player_mc.expand_mode
	_attack_overlay.stretch_mode = player_mc.stretch_mode
	_attack_overlay.position = player_mc.position
	_attack_overlay_start_x = _attack_overlay.position.x
	_attack_overlay.visible = true
	_attack_overlay.modulate = Color.WHITE
	_attack_frame_index = 0

	player_mc.visible = false

	var total_frames := _attack_frames.size()
	var total_duration := PLAYER_ATTACK_TOTAL_DURATION

	var t := create_tween().set_parallel(true)
	t.tween_method(_update_attack_frame.bind(total_frames), 0, total_frames, total_duration)
	t.tween_property(_attack_overlay, "position:x", _attack_overlay_start_x + PLAYER_ATTACK_DASH_DISTANCE, PLAYER_ATTACK_HIT_TIME)
	t.tween_property(_attack_overlay, "position:x", _attack_overlay_start_x, total_duration - PLAYER_ATTACK_HIT_TIME).set_delay(PLAYER_ATTACK_HIT_TIME)
	t.tween_callback(_finish_player_attack_animation).set_delay(total_duration)

func _update_attack_frame(progress: float, total: int) -> void:
	var idx := clampi(int(progress), 0, total - 1)
	if idx < _attack_frames.size():
		_attack_overlay.texture = _attack_frames[idx]

func _finish_player_attack_animation() -> void:
	if player_mc != null:
		player_mc.visible = true
		player_mc.position.x = player_mc_base_pos.x
	if _attack_overlay != null:
		_attack_overlay.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and (not mouse_event.pressed):
			_hide_drag_preview()

func _update_drag_preview_position() -> void:
	if drag_preview_panel == null:
		return

	var viewport_size := get_viewport_rect().size
	var pos := get_global_mouse_position() + CARD_PREVIEW_OFFSET

	pos.x = clamp(pos.x, 8.0, viewport_size.x - CARD_PREVIEW_SIZE.x - 8.0)
	pos.y = clamp(pos.y, 8.0, viewport_size.y - CARD_PREVIEW_SIZE.y - 8.0)

	if drag_preview_shadow_panel != null:
		drag_preview_shadow_panel.global_position = pos + CARD_PREVIEW_SHADOW_OFFSET
	drag_preview_panel.global_position = pos

func _build_card_short_text(card: CardData) -> String:
	var lines: Array[String] = []

	if card.damage > 0:
		lines.append("DMG %d" % card.damage)
	if card.block > 0:
		lines.append("BLK %d" % card.block)
	if card.heal > 0:
		lines.append("HEAL %d" % card.heal)
	if card.meter_delta != 0:
		lines.append("TEMP %d" % card.meter_delta)
	if card.draw_now > 0:
		lines.append("DRAW %d" % card.draw_now)
	if card.draw_next_turn > 0:
		lines.append("NEXT DRAW %d" % card.draw_next_turn)
	if card.heal_next_turn > 0:
		lines.append("NEXT HEAL %d" % card.heal_next_turn)
	if card.offensive_buff > 0:
		lines.append("BUFF %d" % card.offensive_buff)
	if card.reduce_all_costs_this_turn:
		lines.append("ALL COST -1")
	if card.exhaust:
		lines.append("EXHAUST")

	if lines.is_empty():
		return "No extra effect"

	return " | ".join(PackedStringArray(lines))

func _make_card_border_style(card: CardData) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.08)
	style.border_color = _get_card_type_color(card.type, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style

func _make_card_shadow_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.38)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style

func _make_preview_shadow_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.42)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style

func _make_preview_border_style(card_type: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = _get_card_type_color(card_type, 1.0)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style

func _get_card_type_color(card_type: int, alpha: float = 1.0) -> Color:
	if card_type == GameEnums.CardType.DEFENSIVE:
		return Color(0.32, 0.74, 1.0, alpha)
	if card_type == GameEnums.CardType.OFFENSIVE:
		return Color(1.0, 0.42, 0.42, alpha)
	if card_type == GameEnums.CardType.UTILITY:
		return Color(0.45, 0.92, 0.55, alpha)
	return Color(0.98, 0.82, 0.35, alpha)

func _build_card_text(card: CardData, effective_cost: int) -> String:
	var text := "%s\nCost: %d\nType: %s | Elemen: %s" % [
		card.display_name,
		effective_cost,
		str(card.type),
		str(card.element)
	]

	if card.damage > 0: text += "\nDamage: %d" % card.damage
	if card.block > 0: text += "\nBlock: %d" % card.block
	if card.heal > 0: text += "\nHeal: %d" % card.heal
	if card.meter_delta != 0: text += "\nMeter: %d" % card.meter_delta
	if card.draw_now > 0: text += "\nDraw now: +%d" % card.draw_now
	if card.draw_next_turn > 0: text += "\nDraw next turn: +%d" % card.draw_next_turn
	if card.heal_next_turn > 0: text += "\nHeal next turn: +%d" % card.heal_next_turn
	if card.offensive_buff > 0: text += "\nOffense buff combat: +%d" % card.offensive_buff
	if card.reduce_all_costs_this_turn: text += "\nAll card cost -1 (this turn)"
	if card.exhaust: text += "\nExhaust"

	return text

func _get_effective_cost(card: CardData) -> int:
	return maxi(0, card.cost - temporary_cost_reduction_this_turn)

func _try_play_card(hand_index: int) -> void:
	if (not is_player_turn) or battle_finished:
		return

	var card := deck_service.peek_hand(hand_index)
	if card == null:
		return

	var cost := _get_effective_cost(card)
	if cost > player_energy:
		_log("Energy tidak cukup.")
		return

	var played := deck_service.remove_card_from_hand(hand_index)
	if played == null:
		return

	player_energy -= cost
	_play_sfx("sfx_card_click")
	_apply_card_effects(played)

	if played.exhaust:
		deck_service.exhaust(played)
	else:
		deck_service.discard(played)

	if played.damage <= 0 and enemy_hp <= 0:
		_handle_battle_win()
		return

	_refresh_ui()

func _apply_card_effects(card: CardData) -> void:
	_log("Main kartu: %s" % card.display_name)

	if card.block > 0:
		player_block += card.block
		_log("Block +%d" % card.block)

	if card.damage > 0:
		var damage := DamageCalculator.calculate_damage(card, enemy, offensive_buff_this_combat)
		var mult := DamageCalculator.get_element_multiplier(enemy.type, card.element)
		_play_player_attack_animation()
		_queue_damage_effect(damage, mult)

	if card.heal > 0:
		_play_sfx("sfx_heal")
		run_state.heal_player(card.heal)
		_log("Heal +%d" % card.heal)

	if card.meter_delta != 0:
		run_state.add_temperature(card.meter_delta)
		_log("Temperature delta: %d" % card.meter_delta)

	if card.draw_now > 0:
		deck_service.draw_cards(card.draw_now)
		_log("Draw now +%d" % card.draw_now)

	if card.draw_next_turn > 0:
		draw_bonus_next_turn += card.draw_next_turn
		_log("Bonus draw next turn +%d" % card.draw_next_turn)

	if card.heal_next_turn > 0:
		heal_next_turn += card.heal_next_turn
		_log("Heal next turn +%d" % card.heal_next_turn)

	if card.offensive_buff > 0:
		offensive_buff_this_combat += card.offensive_buff
		_log("Buff offensive combat +%d" % card.offensive_buff)

	if card.reduce_all_costs_this_turn:
		temporary_cost_reduction_this_turn = 1
		_log("Semua cost kartu -1 untuk turn ini.")

	if card.suppress_enemy_meter_gain_turns > 0:
		suppress_enemy_meter_gain_turns += card.suppress_enemy_meter_gain_turns
		_log("Kenaikan meter musuh ditahan 1 turn.")

func _queue_damage_effect(damage: int, mult: float) -> void:
	if battle_finished:
		return

	var t := create_tween()
	t.tween_interval(PLAYER_ATTACK_HIT_TIME)
	t.tween_callback(func() -> void:
		if battle_finished:
			return
		enemy_hp = maxi(0, enemy_hp - damage)
		_play_enemy_hit_animation()
		_play_hit_sfx()
		_log("Damage ke %s: %d (x%.1f)" % [enemy.display_name, damage, mult])
		_refresh_ui()
		if enemy_hp <= 0:
			_handle_battle_win()
	)

func _on_end_turn_pressed() -> void:
	if (not is_player_turn) or battle_finished:
		return
	_play_sfx("sfx_card_click")
	_enemy_turn_async()

func _enemy_turn_async() -> void:
	is_player_turn = false
	deck_service.discard_hand()
	_refresh_ui()

	await get_tree().create_timer(0.35).timeout

	enemy_turn_counter += 1

	var attack := _calculate_enemy_attack_damage()
	var damage_to_hp := maxi(0, attack - player_block)
	player_block = maxi(0, player_block - attack)
	await _play_enemy_attack_animation()

	if damage_to_hp > 0:
		run_state.apply_damage_to_player(damage_to_hp)
		_play_player_hit_animation()
		_play_hit_sfx()

	_log("%s menyerang: %d (HP kena: %d)" % [enemy.display_name, attack, damage_to_hp])

	var meter_gain := _calculate_enemy_meter_gain()
	if suppress_enemy_meter_gain_turns > 0:
		meter_gain = maxi(0, meter_gain - 1)
		suppress_enemy_meter_gain_turns -= 1

	run_state.add_temperature(meter_gain)
	_log("Temperature naik +%d" % meter_gain)

	if run_state.is_player_dead():
		_handle_battle_lose("Player HP habis.")
		return

	if run_state.is_temperature_full():
		_handle_battle_lose("Temperature meter penuh (10/10).")
		return

	await get_tree().create_timer(0.35).timeout
	_start_player_turn()

func _calculate_enemy_attack_damage() -> int:
	var attack := enemy.base_attack

	if enemy.type == GameEnums.EnemyType.HEATWAVE and enemy.attack_scale_every_turns > 0 and enemy_turn_counter % enemy.attack_scale_every_turns == 0:
		attack += enemy.attack_scale_amount

	if enemy.type == GameEnums.EnemyType.CLIMATE_COLLAPSE and _is_boss_phase_two():
		attack += enemy.phase_two_attack_bonus

	return attack

func _calculate_enemy_meter_gain() -> int:
	if enemy.type == GameEnums.EnemyType.CLIMATE_COLLAPSE and _is_boss_phase_two():
		return enemy.phase_two_meter_per_turn
	return enemy.meter_per_turn

func _is_boss_phase_two() -> bool:
	if not enemy.has_phase_two:
		return false
	var hp_percent := (float(enemy_hp) * 100.0) / float(enemy.max_hp)
	return hp_percent <= float(enemy.phase_two_threshold_percent)

func _handle_battle_win() -> void:
	if battle_finished:
		return

	battle_finished = true
	is_player_turn = false
	_refresh_ui()

	_log("%s kalah." % enemy.display_name)

	if is_boss_battle:
		run_state.mark_run_win("Anda menaklukkan Climate Collapse. Kota selamat.")
		run_state.advance_node()
		run_state.set_pending_cutscene("after_boss", "res://scenes/Result.tscn")
		get_tree().change_scene_to_file("res://scenes/Cutscene.tscn")
		return

	_show_reward_panel()

func _show_reward_panel() -> void:
	if reward_panel == null or reward_button_a == null or reward_button_b == null:
		_log("UI reward panel tidak lengkap, reward dilewati.")
		_go_to_post_battle_scene()
		return

	var options := GameDatabase.get_random_reward_options(rng, 2)
	if options.size() < 2:
		_go_to_post_battle_scene()
		return

	reward_card_a = options[0]
	reward_card_b = options[1]

	reward_button_a.text = reward_card_a.display_name
	reward_button_b.text = reward_card_b.display_name

	reward_panel.visible = true

func _on_reward_a() -> void:
	if reward_card_a != null:
		_pick_reward(reward_card_a)

func _on_reward_b() -> void:
	if reward_card_b != null:
		_pick_reward(reward_card_b)

func _pick_reward(card: CardData) -> void:
	_play_sfx("sfx_card_click")
	run_state.add_card_to_deck(card.id)
	_go_to_post_battle_scene()

func _go_to_post_battle_scene() -> void:
	run_state.advance_node()
	var cutscene_id := ""
	if enemy != null:
		if enemy.type == GameEnums.EnemyType.FLOOD:
			cutscene_id = "after_flood"
		elif enemy.type == GameEnums.EnemyType.HEATWAVE:
			cutscene_id = "after_heatwave"

	if cutscene_id != "":
		run_state.set_pending_cutscene(cutscene_id, "res://scenes/Map.tscn")
		get_tree().change_scene_to_file("res://scenes/Cutscene.tscn")
		return

	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _setup_character_art() -> void:
	if character_layer == null or player_mc == null or enemy_mc == null:
		return

	player_mc.texture = _load_first_texture(PLAYER_ART_CANDIDATES)
	enemy_mc.texture = _load_first_texture(_get_enemy_art_candidates())

	player_mc_base_pos = player_mc.position
	enemy_mc_base_pos = enemy_mc.position
	_start_idle_animation()

func _preload_enemy_attack_frames() -> void:
	_enemy_attack_frames.clear()
	if enemy == null or enemy.type != GameEnums.EnemyType.FLOOD:
		return

	for i in range(1, FLOOD_ATTACK_FRAME_COUNT + 1):
		var path := "%s/%d.png" % [FLOOD_ATTACK_PATH, i]
		if ResourceLoader.exists(path):
			var tex := load(path)
			if tex is Texture2D:
				_enemy_attack_frames.append(tex)

	if _enemy_attack_overlay == null:
		_enemy_attack_overlay = TextureRect.new()
		_enemy_attack_overlay.name = "EnemyAttackOverlay"
		_enemy_attack_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_enemy_attack_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_enemy_attack_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_enemy_attack_overlay.visible = false
		if character_layer != null:
			character_layer.add_child(_enemy_attack_overlay)
		else:
			add_child(_enemy_attack_overlay)

func _get_enemy_art_candidates() -> Array[String]:
	if enemy == null:
		return ["res://assets/placeholders/characters/enemy.png", "res://icon.svg"]

	if enemy.type == GameEnums.EnemyType.FLOOD:
		return [
			"res://assets/placeholders/characters/enemy_flood.png",
			"res://assets/placeholders/characters/enemy.png",
			"res://icon.svg"
		]
	if enemy.type == GameEnums.EnemyType.HEATWAVE:
		return [
			"res://assets/placeholders/characters/enemy_heatwave.png",
			"res://assets/placeholders/characters/enemy.png",
			"res://icon.svg"
		]
	return [
		"res://assets/placeholders/characters/enemy_boss.png",
		"res://assets/placeholders/characters/enemy.png",
		"res://icon.svg"
	]

func _load_first_texture(paths: Array[String]) -> Texture2D:
	for path in paths:
		if ResourceLoader.exists(path):
			var tex := load(path)
			if tex is Texture2D:
				return tex as Texture2D
	return null

func _get_card_art(card_id: String) -> Texture2D:
	if card_art_cache.has(card_id):
		return card_art_cache[card_id] as Texture2D

	var candidates: Array[String] = [
		"%s/%s.png" % [CARD_ART_BASE_PATH, card_id],
		"%s/%s.webp" % [CARD_ART_BASE_PATH, card_id],
		"%s/%s.jpg" % [CARD_ART_BASE_PATH, card_id],
		"%s/%s.jpeg" % [CARD_ART_BASE_PATH, card_id]
	]

	var art := _load_first_texture(candidates)
	card_art_cache[card_id] = art
	return art

func _start_idle_animation() -> void:
	if player_mc != null:
		if player_idle_tween != null:
			player_idle_tween.kill()
		# player_idle_tween = create_tween().set_loops()
		# player_idle_tween.tween_property(player_mc, "position:y", player_mc_base_pos.y - 8.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# player_idle_tween.tween_property(player_mc, "position:y", player_mc_base_pos.y, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if enemy_mc != null:
		if enemy_idle_tween != null:
			enemy_idle_tween.kill()
		# enemy_idle_tween = create_tween().set_loops()
		# enemy_idle_tween.tween_property(enemy_mc, "position:y", enemy_mc_base_pos.y - 8.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# enemy_idle_tween.tween_property(enemy_mc, "position:y", enemy_mc_base_pos.y, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _play_enemy_attack_animation() -> void:
	if enemy_mc == null:
		return

	if enemy != null and enemy.type == GameEnums.EnemyType.FLOOD and _enemy_attack_frames.size() > 0:
		_enemy_attack_overlay.texture = _enemy_attack_frames[0]
		_enemy_attack_overlay.size = enemy_mc.size
		_enemy_attack_overlay.expand_mode = enemy_mc.expand_mode
		_enemy_attack_overlay.stretch_mode = enemy_mc.stretch_mode
		_enemy_attack_overlay.position = enemy_mc.position
		_enemy_attack_overlay_start_x = _enemy_attack_overlay.position.x
		_enemy_attack_overlay.visible = true
		_enemy_attack_overlay.modulate = Color.WHITE
		enemy_mc.visible = false

		var total_frames := _enemy_attack_frames.size()
		var t := create_tween().set_parallel(true)
		t.tween_method(_update_enemy_attack_frame.bind(total_frames), 0, total_frames, FLOOD_ATTACK_TOTAL_DURATION)
		t.tween_property(_enemy_attack_overlay, "position:x", _enemy_attack_overlay_start_x - FLOOD_ATTACK_DASH_DISTANCE, 0.28)
		t.tween_property(_enemy_attack_overlay, "position:x", _enemy_attack_overlay_start_x, FLOOD_ATTACK_TOTAL_DURATION - 0.28).set_delay(0.28)
		t.tween_callback(_finish_enemy_attack_animation).set_delay(FLOOD_ATTACK_TOTAL_DURATION)
		await get_tree().create_timer(FLOOD_ATTACK_TOTAL_DURATION).timeout
		return

	var t := create_tween()
	t.tween_property(enemy_mc, "position:x", enemy_mc_base_pos.x - 48.0, 0.09)
	t.tween_property(enemy_mc, "position:x", enemy_mc_base_pos.x, 0.11)
	await t.finished

func _update_enemy_attack_frame(progress: float, total: int) -> void:
	var idx := clampi(int(progress), 0, total - 1)
	if idx < _enemy_attack_frames.size() and _enemy_attack_overlay != null:
		_enemy_attack_overlay.texture = _enemy_attack_frames[idx]

func _finish_enemy_attack_animation() -> void:
	if enemy_mc != null:
		enemy_mc.visible = true
		enemy_mc.position.x = enemy_mc_base_pos.x
	if _enemy_attack_overlay != null:
		_enemy_attack_overlay.visible = false

func _play_enemy_hit_animation() -> void:
	if enemy_mc == null:
		return
	enemy_mc.modulate = Color(1.0, 0.65, 0.65, 1.0)
	var t := create_tween()
	t.tween_interval(0.09)
	t.tween_callback(func() -> void:
		if enemy_mc != null:
			enemy_mc.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)

func _play_player_hit_animation() -> void:
	if player_mc == null:
		return
	player_mc.modulate = Color(1.0, 0.65, 0.65, 1.0)
	var t := create_tween()
	t.tween_interval(0.09)
	t.tween_callback(func() -> void:
		if player_mc != null:
			player_mc.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)

func _handle_battle_lose(reason: String) -> void:
	if battle_finished:
		return
	battle_finished = true
	run_state.mark_run_lose(reason)
	get_tree().change_scene_to_file("res://scenes/Result.tscn")

func _log(message: String) -> void:
	log_label.text += "\n- %s" % message
