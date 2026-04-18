extends Control

var run_state: RunState
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

var reward_panel: PanelContainer
var reward_button_a: Button
var reward_button_b: Button
var reward_card_a: CardData = null
var reward_card_b: CardData = null

func _ready() -> void:
	rng.randomize()
	run_state = get_node("/root/RunStateNode")

	_cache_ui_nodes()
	_bind_ui_events()

	var node := run_state.get_current_node()
	if node == null or node.enemy_kind == null:
		get_tree().change_scene_to_file("res://scenes/Map.tscn")
		return

	enemy = GameDatabase.get_enemy_by_type(node.enemy_kind)
	enemy_hp = enemy.max_hp
	is_boss_battle = node.node_type == GameEnums.NodeType.BOSS

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

	reward_panel = get_node("RewardPanel")
	reward_button_a = get_node("RewardPanel/RewardVBox/RewardButtons/RewardButtonA")
	reward_button_b = get_node("RewardPanel/RewardVBox/RewardButtons/RewardButtonB")

	meter_bar.max_value = run_state.temperature_max
	reward_panel.visible = false

func _bind_ui_events() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	reward_button_a.pressed.connect(_on_reward_a)
	reward_button_b.pressed.connect(_on_reward_b)

func _start_player_turn() -> void:
	if battle_finished:
		return

	is_player_turn = true
	player_energy = 3
	temporary_cost_reduction_this_turn = 0

	if heal_next_turn > 0:
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
	for child in hand_hbox.get_children():
		child.queue_free()

	var hand := deck_service.get_hand()
	for i in range(hand.size()):
		var card := hand[i]
		var cost := _get_effective_cost(card)

		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 130)
		button.text = _build_card_text(card, cost)
		button.disabled = (not is_player_turn) or (cost > player_energy) or battle_finished

		button.pressed.connect(func() -> void:
			_try_play_card(i)
		)

		hand_hbox.add_child(button)

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
	_apply_card_effects(played)

	if played.exhaust:
		deck_service.exhaust(played)
	else:
		deck_service.discard(played)

	if enemy_hp <= 0:
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
		enemy_hp = maxi(0, enemy_hp - damage)
		var mult := DamageCalculator.get_element_multiplier(enemy.type, card.element)
		_log("Damage ke %s: %d (x%.1f)" % [enemy.display_name, damage, mult])

	if card.heal > 0:
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

func _on_end_turn_pressed() -> void:
	if (not is_player_turn) or battle_finished:
		return
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

	if damage_to_hp > 0:
		run_state.apply_damage_to_player(damage_to_hp)

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
		get_tree().change_scene_to_file("res://scenes/Result.tscn")
		return

	_show_reward_panel()

func _show_reward_panel() -> void:
	var options := GameDatabase.get_random_reward_options(rng, 2)
	if options.size() < 2:
		run_state.advance_node()
		get_tree().change_scene_to_file("res://scenes/Map.tscn")
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
	run_state.add_card_to_deck(card.id)
	run_state.advance_node()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")

func _handle_battle_lose(reason: String) -> void:
	if battle_finished:
		return
	battle_finished = true
	run_state.mark_run_lose(reason)
	get_tree().change_scene_to_file("res://scenes/Result.tscn")

func _log(message: String) -> void:
	log_label.text += "\n- %s" % message
