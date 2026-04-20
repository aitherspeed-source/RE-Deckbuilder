extends Node

# We renamed 'sepsis_instance' to 'sepsis_logic' to avoid any future conflicts
var active_modifiers: Array = []
var sepsis_logic = SepsisModifier.new() 

func get_context():
	return {
		"player": get_tree().get_first_node_in_group("player"),
		"game_manager": GameManager
	}

# Called by InfectionEffect.gd whenever stacks are processed
func resolve_infection_tier(stacks: int):
	var new_tier = 0
	
	# Design: 5 stacks per Tier
	if stacks >= 20: new_tier = 4
	elif stacks >= 15: new_tier = 3
	elif stacks >= 10: new_tier = 2
	elif stacks >= 5: new_tier = 1
	else: new_tier = 0
	
	if new_tier != GameManager.current_infection_tier:
		GameManager.current_infection_tier = new_tier
		_update_active_states(new_tier)

func _update_active_states(tier: int):
	# Sepsis (Tier 1+)
	if tier >= 1:
		add_modifier(sepsis_logic)
	else:
		remove_modifier(sepsis_logic)

func add_modifier(mod):
	if not active_modifiers.has(mod):
		active_modifiers.append(mod)

func remove_modifier(mod):
	active_modifiers.erase(mod)

# Signal hooks called by CombatManager.gd
func trigger_turn_start():
	var context = get_context()
	for mod in active_modifiers:
		mod.on_turn_start(context)

func trigger_card_played(card):
	var context = get_context()
	for mod in active_modifiers:
		mod.on_card_played(card, context)

func trigger_turn_end():
	var context = get_context()
	for mod in active_modifiers:
		mod.on_turn_end(context)
