extends Node
class_name RunState

var max_hp: int = 60
var current_hp: int = 60

var temperature: int = 0
var temperature_max: int = 10

var current_node_index: int = 0

var last_run_won: bool = false
var last_run_message: String = ""

var pending_extra_draw_next_battle: int = 0
var deck_card_ids: Array[String] = []

func _ready() -> void:
	reset_for_new_run()

func reset_for_new_run() -> void:
	current_hp = max_hp
	temperature = 0
	current_node_index = 0
	pending_extra_draw_next_battle = 0
	last_run_won = false
	last_run_message = ""
	deck_card_ids = GameDatabase.starter_deck.duplicate()

func heal_player(amount: int) -> void:
	current_hp = clamp(current_hp + amount, 0, max_hp)

func apply_damage_to_player(amount: int) -> void:
	current_hp = clamp(current_hp - amount, 0, max_hp)

func add_temperature(delta: int) -> void:
	temperature = clamp(temperature + delta, 0, temperature_max)

func is_player_dead() -> bool:
	return current_hp <= 0

func is_temperature_full() -> bool:
	return temperature >= temperature_max

func get_current_node() -> RunNodeData:
	var nodes := GameDatabase.get_run_nodes()
	if current_node_index < 0 or current_node_index >= nodes.size():
		return null
	return nodes[current_node_index]

func advance_node() -> void:
	current_node_index += 1

func add_card_to_deck(card_id: String) -> void:
	deck_card_ids.append(card_id)

func add_pending_extra_draw(amount: int) -> void:
	pending_extra_draw_next_battle += amount

func consume_pending_extra_draw() -> int:
	var v := pending_extra_draw_next_battle
	pending_extra_draw_next_battle = 0
	return v

func mark_run_win(message: String) -> void:
	last_run_won = true
	last_run_message = message

func mark_run_lose(message: String) -> void:
	last_run_won = false
	last_run_message = message
