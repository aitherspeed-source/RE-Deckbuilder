extends Effect
class_name BlockEffect

func _init() -> void:
	effect_name           = "Block"
	description           = "Absorbs damage. Resets at start of turn."
	icon                  = "🛡️"
	trigger_on_turn_start = true
	trigger_on_turn_end   = false
	duration              = -1

func apply(entity) -> void:
	print("🛡️ Block applied! ",
		entity.name, " now has ", stacks, " Block.")
	if entity.has_signal("block_changed"):
		entity.emit_signal("block_changed", stacks)

func absorb_damage(amount: int) -> int:
	if is_blocked:
		return amount
	var absorbed = min(stacks, amount)
	stacks      -= absorbed
	var leftover = amount - absorbed
	print("🛡️ Block absorbed ", absorbed,
		" damage. Remaining: ", stacks,
		" | Leftover: ", leftover)
	return leftover

func on_turn_trigger(entity) -> void:
	if stacks > 0:
		print("🛡️ Block reset on ", entity.name)
		stacks = 0
		if entity.has_signal("block_changed"):
			entity.emit_signal("block_changed", 0)

func tick(_entity) -> void:
	pass

func remove(entity) -> void:
	stacks = 0
	if entity.has_signal("block_changed"):
		entity.emit_signal("block_changed", 0)
	print("🛡️ Block removed from ", entity.name)
