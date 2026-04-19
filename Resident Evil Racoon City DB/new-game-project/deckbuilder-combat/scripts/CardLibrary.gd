extends Node

const CARDS_PATH = "res://data/cards/"

func get_all_cards() -> Array:
	var cards : Array = []
	var dir = DirAccess.open(CARDS_PATH)
	if dir == null:
		print("ERROR: Could not open cards folder at ", CARDS_PATH)
		return cards
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path = CARDS_PATH + file_name
			var card = load(full_path)
			if card is CardData:
				cards.append(card)
				print("Loaded card: ", card.card_name)
			else:
				print("WARNING: ", file_name, " is not a CardData resource!")
		file_name = dir.get_next()
	dir.list_dir_end()
	print("Total cards loaded: ", cards.size())
	return cards

func get_starter_deck() -> Array:
	var all_cards = get_all_cards()
	var starter   : Array = []
	var starter_list : Dictionary = {
		"Pistol Shot":    3,
		"Take Cover":     2,
		"Hollow Point":   2,
		"Adrenaline":     1,
		"Field Dressing": 1,
	}
	for card_name in starter_list:
		var copies = starter_list[card_name]
		var found  = get_card_by_name(card_name, all_cards)
		if found != null:
			for i in range(copies):
				starter.append(found.duplicate())
		else:
			print("WARNING: Starter card not found: ", card_name)
	print("Starter deck size: ", starter.size())
	return starter

func get_card_by_name(card_name: String, card_pool: Array = []) -> CardData:
	var pool = card_pool if not card_pool.is_empty() else get_all_cards()
	for card in pool:
		if card.card_name == card_name:
			return card
	print("WARNING: Card not found: ", card_name)
	return null

func execute_card(card: CardData, player, enemy) -> void:
	var effect = card.effect
	var value  = card.value
	var value2 = card.value2
	print("Executing: ", card.card_name, " | ", effect)

	match effect:
		"deal_damage":
			var dmg = player.effect_manager.calculate_outgoing_damage(value)
			enemy.effect_manager.receive_damage(dmg)

		"deal_damage_twice":
			var dmg = player.effect_manager.calculate_outgoing_damage(value)
			enemy.effect_manager.receive_damage(dmg)
			enemy.effect_manager.receive_damage(dmg)

		"damage_and_infect":
			var dmg = player.effect_manager.calculate_outgoing_damage(value)
			enemy.effect_manager.receive_damage(dmg)
			enemy.effect_manager.apply_effect("Infection", value2)

		"gain_block":
			player.effect_manager.apply_effect("Block", value)

		"gain_ammo_and_draw":
			player.ammo = min(player.ammo + value, player.max_ammo)
			player.emit_signal("ammo_changed", player.ammo, player.max_ammo)
			player.draw_cards(value2)

		"apply_infection":
			enemy.effect_manager.apply_effect("Infection", value)

		"heal_and_block":
			player.heal(value)
			player.effect_manager.apply_effect("Block", value2)

		"rage_attack":
			player.effect_manager.apply_effect("Infection", value2)
			var dmg = player.effect_manager.calculate_outgoing_damage(value)
			enemy.effect_manager.receive_damage(dmg)

		"fortify":
			player.effect_manager.apply_effect("Block", value)

		_:
			print("WARNING: Unknown effect: ", effect)
