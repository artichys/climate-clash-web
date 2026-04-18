extends RefCounted
class_name DamageCalculator

static func get_element_multiplier(enemy_type: int, element_type: int) -> float:
	if enemy_type == GameEnums.EnemyType.FLOOD and element_type == GameEnums.ElementType.WATER:
		return 1.5
	if enemy_type == GameEnums.EnemyType.FLOOD and element_type == GameEnums.ElementType.THERMAL:
		return 0.5

	if enemy_type == GameEnums.EnemyType.HEATWAVE and element_type == GameEnums.ElementType.THERMAL:
		return 1.5
	if enemy_type == GameEnums.EnemyType.HEATWAVE and element_type == GameEnums.ElementType.WATER:
		return 0.5

	return 1.0

static func calculate_damage(card: CardData, enemy: EnemyData, offensive_buff: int) -> int:
	var base_damage := card.damage
	if card.type == GameEnums.CardType.OFFENSIVE:
		base_damage += offensive_buff

	var mult := get_element_multiplier(enemy.type, card.element)
	return int(round(base_damage * mult))
