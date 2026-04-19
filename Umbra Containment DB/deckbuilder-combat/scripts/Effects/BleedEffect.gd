extends Effect
class_name BleedEffect

func _init() -> void:
	effect_name           = "Bleed"
	description           = "Takes damage equal to stacks. Fades by 1 each turn."
	icon                  = "🩸"
	trigger_on_turn_end   = true
	trigger_on_turn_start = false
	duration              = -1

func apply(entity) -> void:
	print("🩸 Bleed applied! ",
		entity.name, " now has ", stacks, " Bleed.")

func on_turn_trigger(entity) -> void:
	if is_blocked:
		return
	var damage = get_effective_value()
	print("🩸 Bleed deals ", damage, " damage to ", entity.name)
	entity.current_hp -= damage
	entity.current_hp = max(entity.current_hp, 0)
	if entity.has_signal("hp_changed"):
		entity.emit_signal("hp_changed", entity.current_hp, entity.max_hp)
	remove_stacks(1)
	print("🩸 Bleed fades. Remaining: ", stacks)
	if entity.current_hp <= 0:
		entity.die()

func tick(_entity) -> void:
	pass

func remove(entity) -> void:
	stacks = 0
	print("🩸 Bleed cleared from ", entity.name)
