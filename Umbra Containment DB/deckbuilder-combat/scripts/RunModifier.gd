extends Resource
class_name RunModifier

@export var modifier_name: String = "Unknown Modifier"
@export var priority: int = 10 # Lower numbers happen first

# These are "Hooks." They do nothing now, but we will "Override" them 
# in specific files like Sepsis.gd later.

func on_combat_start(_context): pass
func on_turn_start(_context): pass
func on_card_played(_card, _context): pass
func on_turn_end(_context): pass
func on_infection_tier_changed(_new_tier, _context): pass
