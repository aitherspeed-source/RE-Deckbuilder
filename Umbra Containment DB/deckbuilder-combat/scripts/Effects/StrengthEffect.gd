extends Effect
class_name StrengthEffect

func _init() -> void:
	effect_name           = "Strength"
	description           = "Increases all damage dealt by stacks."
	icon                  = "💪"
	trigger_on_turn_start = false
	trigger_on_turn_end   = false
	duration              = -1

func apply(entity) -> void:
	print("💪 Strength applied! ",
		entity.name, " gains ", stacks, " Strength.")

func modify_damage(base_damage: int) -> int:
	if is_blocked or stacks <= 0:
		return base_damage
	var bonus = get_effective_value()
	var total = base_damage + bonus
	print("💪 Strength adds ", bonus,
		" damage: ", base_damage, " → ", total)
	return total

func on_turn_trigger(_entity) -> void:
	pass

func tick(_entity) -> void:
	pass

func remove(entity) -> void:
	stacks = 0
	print("💪 Strength removed from ", entity.name)
