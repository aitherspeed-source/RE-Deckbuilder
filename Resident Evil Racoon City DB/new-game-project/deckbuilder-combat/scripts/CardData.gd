extends Resource
class_name CardData

# ────────────────────────────────────────────
#  CARD DATA RESOURCE
#  This is the blueprint for every card.
#  Each card will be saved as a .tres file
#  and filled in using the Godot Inspector.
# ────────────────────────────────────────────

# The @export keyword means this field shows
# up in the Inspector so you can edit it visually

@export var card_name    : String = "New Card"

@export_enum("attack", "skill", "power")
var card_type            : String = "attack"

@export var cost         : int = 1
@export var description  : String = "Does something."
@export var value        : int = 0
@export var value2       : int = 0

@export_enum(
	"deal_damage",
	"deal_damage_twice",
	"damage_and_infect",
	"gain_block",
	"gain_ammo_and_draw",
	"apply_infection",
	"heal_and_block",
	"rage_attack",
	"fortify"
)
var effect               : String = "deal_damage"
