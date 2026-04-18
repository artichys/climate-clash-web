extends RefCounted
class_name DeckService

var _rng := RandomNumberGenerator.new()
var _draw_pile: Array[CardData] = []
var _discard_pile: Array[CardData] = []
var _hand: Array[CardData] = []
var _exhaust_pile: Array[CardData] = []

func _init(deck_card_ids: Array[String]) -> void:
	_rng.randomize()

	for id in deck_card_ids:
		var card := GameDatabase.get_card_by_id(id)
		if card != null:
			_draw_pile.append(card)

	_shuffle_draw_pile()

func get_hand() -> Array[CardData]:
	return _hand

func peek_hand(index: int) -> CardData:
	if index < 0 or index >= _hand.size():
		return null
	return _hand[index]

func remove_card_from_hand(index: int) -> CardData:
	if index < 0 or index >= _hand.size():
		return null
	var c := _hand[index]
	_hand.remove_at(index)
	return c

func draw_cards(amount: int) -> void:
	for i in range(amount):
		if _draw_pile.is_empty():
			_refill_draw_pile_from_discard()
			if _draw_pile.is_empty():
				break

		var c := _draw_pile[0]
		_draw_pile.remove_at(0)
		_hand.append(c)

func discard(card: CardData) -> void:
	_discard_pile.append(card)

func exhaust(card: CardData) -> void:
	_exhaust_pile.append(card)

func discard_hand() -> void:
	for c in _hand:
		_discard_pile.append(c)
	_hand.clear()

func add_card_to_deck(card: CardData) -> void:
	_discard_pile.append(card)

func _refill_draw_pile_from_discard() -> void:
	if _discard_pile.is_empty():
		return

	_draw_pile.append_array(_discard_pile)
	_discard_pile.clear()
	_shuffle_draw_pile()

func _shuffle_draw_pile() -> void:
	for i in range(_draw_pile.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := _draw_pile[i]
		_draw_pile[i] = _draw_pile[j]
		_draw_pile[j] = tmp
