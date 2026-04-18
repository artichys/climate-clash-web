extends RefCounted
class_name CardData

var id: String = ""
var display_name: String = ""
var type: int = GameEnums.CardType.OFFENSIVE
var element: int = GameEnums.ElementType.NEUTRAL
var cost: int = 1

var damage: int = 0
var block: int = 0
var heal: int = 0
var meter_delta: int = 0

var draw_now: int = 0
var draw_next_turn: int = 0
var heal_next_turn: int = 0

var offensive_buff: int = 0
var reduce_all_costs_this_turn: bool = false
var suppress_enemy_meter_gain_turns: int = 0

var exhaust: bool = false

func clone() -> CardData:
	var c := CardData.new()
	c.id = id
	c.display_name = display_name
	c.type = type
	c.element = element
	c.cost = cost
	c.damage = damage
	c.block = block
	c.heal = heal
	c.meter_delta = meter_delta
	c.draw_now = draw_now
	c.draw_next_turn = draw_next_turn
	c.heal_next_turn = heal_next_turn
	c.offensive_buff = offensive_buff
	c.reduce_all_costs_this_turn = reduce_all_costs_this_turn
	c.suppress_enemy_meter_gain_turns = suppress_enemy_meter_gain_turns
	c.exhaust = exhaust
	return c
