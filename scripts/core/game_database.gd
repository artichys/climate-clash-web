extends RefCounted
class_name GameDatabase

static var starter_deck: Array[String] = [
	"water_pump",
	"water_pump",
	"flood_barrier",
	"flood_barrier",
	"solar_flare",
	"mangrove_wall",
	"policy_strike",
    "carbon_tax"
]

static var _cards: Dictionary = {}
static var _enemies: Dictionary = {}
static var _run_nodes: Array[RunNodeData] = []
static var _initialized: bool = false

static func _init_data() -> void:
	if _initialized:
		return

	_initialized = true

	_cards = {
		"flood_barrier": _make_card({"id":"flood_barrier","display_name":"Flood Barrier","type":GameEnums.CardType.DEFENSIVE,"element":GameEnums.ElementType.WATER,"cost":1,"block":7,"suppress_enemy_meter_gain_turns":1}),
		"solar_shade": _make_card({"id":"solar_shade","display_name":"Solar Shade","type":GameEnums.CardType.DEFENSIVE,"element":GameEnums.ElementType.THERMAL,"cost":1,"block":5,"suppress_enemy_meter_gain_turns":1}),
		"mangrove_wall": _make_card({"id":"mangrove_wall","display_name":"Mangrove Wall","type":GameEnums.CardType.DEFENSIVE,"element":GameEnums.ElementType.BIO,"cost":1,"block":4,"heal_next_turn":2}),
		"urban_shield": _make_card({"id":"urban_shield","display_name":"Urban Shield","type":GameEnums.CardType.DEFENSIVE,"element":GameEnums.ElementType.NEUTRAL,"cost":2,"block":8}),
		"water_pump": _make_card({"id":"water_pump","display_name":"Water Pump","type":GameEnums.CardType.OFFENSIVE,"element":GameEnums.ElementType.WATER,"cost":1,"damage":6}),
		"solar_flare": _make_card({"id":"solar_flare","display_name":"Solar Flare","type":GameEnums.CardType.OFFENSIVE,"element":GameEnums.ElementType.THERMAL,"cost":1,"damage":7}),
		"policy_strike": _make_card({"id":"policy_strike","display_name":"Policy Strike","type":GameEnums.CardType.OFFENSIVE,"element":GameEnums.ElementType.NEUTRAL,"cost":2,"damage":5,"draw_now":1}),
		"green_bomb": _make_card({"id":"green_bomb","display_name":"Green Bomb","type":GameEnums.CardType.OFFENSIVE,"element":GameEnums.ElementType.BIO,"cost":3,"damage":10,"exhaust":true}),
		"carbon_tax": _make_card({"id":"carbon_tax","display_name":"Carbon Tax","type":GameEnums.CardType.UTILITY,"element":GameEnums.ElementType.NEUTRAL,"cost":1,"meter_delta":-2}),
		"ev_initiative": _make_card({"id":"ev_initiative","display_name":"EV Initiative","type":GameEnums.CardType.UTILITY,"element":GameEnums.ElementType.NEUTRAL,"cost":1,"draw_next_turn":2}),
		"reforestation": _make_card({"id":"reforestation","display_name":"Reforestation","type":GameEnums.CardType.UTILITY,"element":GameEnums.ElementType.BIO,"cost":2,"heal":5}),
		"green_new_deal": _make_card({"id":"green_new_deal","display_name":"Green New Deal","type":GameEnums.CardType.SCALING,"element":GameEnums.ElementType.NEUTRAL,"cost":2,"offensive_buff":2}),
		"climate_pact": _make_card({"id":"climate_pact","display_name":"Climate Pact","type":GameEnums.CardType.SCALING,"element":GameEnums.ElementType.NEUTRAL,"cost":1,"reduce_all_costs_this_turn":true})
	}

	_enemies = {
		GameEnums.EnemyType.FLOOD: _make_enemy({"id":"flood","display_name":"Flood","type":GameEnums.EnemyType.FLOOD,"max_hp":40,"base_attack":7,"meter_per_turn":1}),
		GameEnums.EnemyType.HEATWAVE: _make_enemy({"id":"heatwave","display_name":"Heatwave","type":GameEnums.EnemyType.HEATWAVE,"max_hp":45,"base_attack":6,"meter_per_turn":2,"attack_scale_every_turns":3,"attack_scale_amount":2}),
		GameEnums.EnemyType.CLIMATE_COLLAPSE: _make_enemy({"id":"climate_collapse","display_name":"Climate Collapse","type":GameEnums.EnemyType.CLIMATE_COLLAPSE,"max_hp":80,"base_attack":9,"meter_per_turn":2,"has_phase_two":true,"phase_two_threshold_percent":50,"phase_two_meter_per_turn":3,"phase_two_attack_bonus":3})
	}

	_run_nodes = []
	var n1 := RunNodeData.new(); n1.index = 1; n1.node_type = GameEnums.NodeType.BATTLE; n1.enemy_kind = GameEnums.EnemyType.FLOOD; _run_nodes.append(n1)
	var n2 := RunNodeData.new(); n2.index = 2; n2.node_type = GameEnums.NodeType.BATTLE; n2.enemy_kind = GameEnums.EnemyType.HEATWAVE; _run_nodes.append(n2)
	var n3 := RunNodeData.new(); n3.index = 3; n3.node_type = GameEnums.NodeType.EVENT; n3.event_id = "sanctuary_green"; _run_nodes.append(n3)
	var n4 := RunNodeData.new(); n4.index = 4; n4.node_type = GameEnums.NodeType.BOSS; n4.enemy_kind = GameEnums.EnemyType.CLIMATE_COLLAPSE; _run_nodes.append(n4)

static func _make_card(data: Dictionary) -> CardData:
	var c := CardData.new()
	c.id = data.get("id", "")
	c.display_name = data.get("display_name", "")
	c.type = data.get("type", GameEnums.CardType.OFFENSIVE)
	c.element = data.get("element", GameEnums.ElementType.NEUTRAL)
	c.cost = data.get("cost", 1)
	c.damage = data.get("damage", 0)
	c.block = data.get("block", 0)
	c.heal = data.get("heal", 0)
	c.meter_delta = data.get("meter_delta", 0)
	c.draw_now = data.get("draw_now", 0)
	c.draw_next_turn = data.get("draw_next_turn", 0)
	c.heal_next_turn = data.get("heal_next_turn", 0)
	c.offensive_buff = data.get("offensive_buff", 0)
	c.reduce_all_costs_this_turn = data.get("reduce_all_costs_this_turn", false)
	c.suppress_enemy_meter_gain_turns = data.get("suppress_enemy_meter_gain_turns", 0)
	c.exhaust = data.get("exhaust", false)
	return c

static func _make_enemy(data: Dictionary) -> EnemyData:
	var e := EnemyData.new()
	e.id = data.get("id", "")
	e.display_name = data.get("display_name", "")
	e.type = data.get("type", GameEnums.EnemyType.FLOOD)
	e.max_hp = data.get("max_hp", 1)
	e.base_attack = data.get("base_attack", 1)
	e.meter_per_turn = data.get("meter_per_turn", 1)
	e.attack_scale_every_turns = data.get("attack_scale_every_turns", 0)
	e.attack_scale_amount = data.get("attack_scale_amount", 0)
	e.has_phase_two = data.get("has_phase_two", false)
	e.phase_two_threshold_percent = data.get("phase_two_threshold_percent", 50)
	e.phase_two_meter_per_turn = data.get("phase_two_meter_per_turn", 1)
	e.phase_two_attack_bonus = data.get("phase_two_attack_bonus", 0)
	return e

static func get_card_by_id(card_id: String) -> CardData:
	_init_data()
	if not _cards.has(card_id):
		return null
	return (_cards[card_id] as CardData).clone()

static func get_enemy_by_type(enemy_type: int) -> EnemyData:
	_init_data()
	return _enemies[enemy_type] as EnemyData

static func get_run_nodes() -> Array[RunNodeData]:
	_init_data()
	return _run_nodes

static func get_random_reward_options(rng: RandomNumberGenerator, count: int) -> Array[CardData]:
	_init_data()

	var pool: Array[CardData] = []
	for c in _cards.values():
		pool.append((c as CardData).clone())

	var result: Array[CardData] = []
	while result.size() < count and pool.size() > 0:
		var idx := rng.randi_range(0, pool.size() - 1)
		result.append(pool[idx])
		pool.remove_at(idx)

	return result
