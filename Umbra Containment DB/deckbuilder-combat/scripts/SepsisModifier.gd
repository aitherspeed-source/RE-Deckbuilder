extends RunModifier
class_name SepsisModifier

var cards_played_this_turn: int = 0

func on_turn_start(_context):
	cards_played_this_turn = 0

func on_card_played(_card, _context):
	cards_played_this_turn += 1

func on_turn_end(context):
	# Damage = Player's current ammo (Min 2) if they played < 2 cards
	if cards_played_this_turn < 2:
		var p = context.player
		var damage = max(p.ammo, 2)
		p.take_damage(damage)
		print("SEPSIS: Low activity detected. Dealt ", damage, " damage.")
