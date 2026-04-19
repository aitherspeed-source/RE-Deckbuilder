extends Effect
class_name WeakEffect

const DAMAGE_REDUCTION : float = 0.25

func _init() -> void:
	effect_name           = "Weak"
	description           = "Reduces damage dealt by 25%. Fades each turn."
	icon                  = "🔱"
	trigger_on_turn_start = true
	trigger_on_turn_end   = false
	duration              = -1 

func apply(entity) -> void:
	print("🔱 Weak applied! ",
		  entity.name, " is weakened for ",
		  stacks, " turns.")

func modify_damage(base_damage: int) -> int:
	if is_blocked or stacks <= 0:
		return base_damage
	var reduced = int(base_damage * (1.0 - DAMAGE_REDUCTION))
	print("🔱 Weak reduces damage: ",
		  base_damage, " → ", reduced)
	return reduced

func on_turn_trigger(entity) -> void:
	remove_stacks(1)
	print("🔱 Weak fades on ", entity.name,
		  ". Remaining: ", stacks)
