extends Effect
class_name InfectionEffect

func _init() -> void:
	effect_name           = "Infection"
	description           = "Triggers states for player, deals damage to enemies."
	icon                  = "🧫"
	trigger_on_turn_end   = true
	trigger_on_turn_start = false
	duration              = -1

func apply(entity) -> void:
	if entity.has_signal("infection_changed"):
		entity.emit_signal("infection_changed", stacks)

func on_turn_trigger(entity) -> void:
	if is_blocked:
		return

	# CHECK: Is this the Player or an Enemy?
	if entity.is_in_group("player"):
		# Player: Do NOT take damage. Trigger the Tier Manager instead.
		RunModifierManager.resolve_infection_tier(stacks)
		print("🧫 Player Infection Tier checked. Stacks: ", stacks)
	else:
		# Enemy: Keep the old logic. Infection still kills enemies!
		var damage = get_effective_value()
		entity.take_damage(damage)
		print("🧫 Infection deals ", damage, " damage to ", entity.name)

func tick(_entity) -> void:
	pass

func remove(entity) -> void:
	stacks = 0
	if entity.has_signal("infection_changed"):
		entity.emit_signal("infection_changed", 0)
