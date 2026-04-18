extends RefCounted
class_name EnemyData

var id: String = ""
var display_name: String = ""
var type: int = GameEnums.EnemyType.FLOOD

var max_hp: int = 1
var base_attack: int = 1
var meter_per_turn: int = 1

var attack_scale_every_turns: int = 0
var attack_scale_amount: int = 0

var has_phase_two: bool = false
var phase_two_threshold_percent: int = 50
var phase_two_meter_per_turn: int = 1
var phase_two_attack_bonus: int = 0
