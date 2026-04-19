extends Effect
class_name InfectionEffect

func _init() -> void:
	effect_name           = "Infection"
	description           = "Takes damage equal to stacks at end of turn."
	icon                  = "🧫"
	trigger_on_turn_end   = true
	trigger_on_turn_start = false
	duration              = -1

func apply(entity) -> void:
	print("🧫 Infection applied! ",
		entity.name, " now has ", stacks, " Infection.")
	if entity.has_signal("infection_changed"):
		entity.emit_signal("infection_changed", stacks)

func on_turn_trigger(entity) -> void:
	if is_blocked:
		return
	var damage = get_effective_value()
	print("🧫 Infection deals ", damage, " damage to ", entity.name)
	# Directly reduce HP to avoid infinite loop
	entity.current_hp -= damage
	entity.current_hp = max(entity.current_hp, 0)
	if entity.has_signal("hp_changed"):
		entity.emit_signal("hp_changed", entity.current_hp, entity.max_hp)
	print("  HP: ", entity.current_hp, "/", entity.max_hp)
	if entity.current_hp <= 0:
		entity.die()

func tick(_entity) -> void:
	pass

func remove(entity) -> void:
	stacks = 0
	if entity.has_signal("infection_changed"):
		entity.emit_signal("infection_changed", 0)
	print("🧫 Infection cleared from ", entity.name)
