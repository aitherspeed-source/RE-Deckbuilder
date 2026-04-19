extends Node

var entity = null
var active_effects : Dictionary = {}

func setup(owner_entity) -> void:
	entity = owner_entity
	print("EffectManager ready for: ", entity.name)

# ────────────────────────────────────────────
#  APPLY EFFECT
# ────────────────────────────────────────────
func apply_effect(effect_id: String, stacks: int = 1) -> void:
	if stacks <= 0:
		return

	if active_effects.has(effect_id):
		var existing = active_effects[effect_id]
		existing.add_stacks(stacks)
		existing.apply(entity)
		return

	var new_effect = _create_effect(effect_id)
	if new_effect == null:
		print("ERROR: Unknown effect: ", effect_id)
		return

	new_effect.stacks = stacks
	active_effects[effect_id] = new_effect
	new_effect.apply(entity)
	print("New effect: ", effect_id,
		" (", stacks, " stacks) on ", entity.name)

# ────────────────────────────────────────────
#  REMOVE EFFECT
# ────────────────────────────────────────────
func remove_effect(effect_id: String) -> void:
	if active_effects.has(effect_id):
		active_effects[effect_id].remove(entity)
		active_effects.erase(effect_id)

# ────────────────────────────────────────────
#  QUERIES
# ────────────────────────────────────────────
func has_effect(effect_id: String) -> bool:
	return active_effects.has(effect_id)

func get_effect(effect_id: String):
	return active_effects.get(effect_id, null)

func get_stacks(effect_id: String) -> int:
	if active_effects.has(effect_id):
		return active_effects[effect_id].stacks
	return 0

# ────────────────────────────────────────────
#  TURN TRIGGERS
# ────────────────────────────────────────────
func trigger_turn_start() -> void:
	print("--- ", entity.name, " turn START effects ---")
	_trigger_effects(true)
	_cleanup_expired()

func trigger_turn_end() -> void:
	print("--- ", entity.name, " turn END effects ---")
	_trigger_effects(false)
	_cleanup_expired()

# ────────────────────────────────────────────
#  RECEIVE DAMAGE — routes through Block
# ────────────────────────────────────────────
func receive_damage(amount: int) -> void:
	var final_damage = amount

	if active_effects.has("Block"):
		var block_effect = active_effects["Block"]
		final_damage = block_effect.absorb_damage(final_damage)
		if entity.has_signal("block_changed"):
			entity.emit_signal("block_changed", block_effect.stacks)
		if block_effect.is_expired():
			active_effects.erase("Block")

	if final_damage > 0:
		entity.current_hp -= final_damage
		entity.current_hp  = max(entity.current_hp, 0)
		if entity.has_signal("hp_changed"):
			entity.emit_signal("hp_changed",
				entity.current_hp, entity.max_hp)
		print(entity.name, " takes ", final_damage,
			" damage! HP: ", entity.current_hp,
			"/", entity.max_hp)
		if entity.current_hp <= 0:
			entity.die()

# ────────────────────────────────────────────
#  CALCULATE OUTGOING DAMAGE
# ────────────────────────────────────────────
func calculate_outgoing_damage(base_damage: int) -> int:
	var damage = base_damage

	if active_effects.has("Strength"):
		damage = active_effects["Strength"].modify_damage(damage)

	if active_effects.has("Weak"):
		damage = active_effects["Weak"].modify_damage(damage)

	return damage

# ────────────────────────────────────────────
#  UI SUMMARY
# ────────────────────────────────────────────
func get_ui_summary() -> Array:
	var summary : Array = []
	for effect_id in active_effects:
		var effect = active_effects[effect_id]
		if not effect.is_expired():
			summary.append(effect.get_ui_text())
	return summary

# ────────────────────────────────────────────
#  PRIVATE
# ────────────────────────────────────────────
func _trigger_effects(is_turn_start: bool) -> void:
	for effect_id in active_effects.keys():
		var effect = active_effects[effect_id]
		var should_trigger = (
			(is_turn_start and effect.trigger_on_turn_start) or
			(not is_turn_start and effect.trigger_on_turn_end)
		)
		if should_trigger:
			effect.on_turn_trigger(entity)
			effect.tick(entity)

func _cleanup_expired() -> void:
	var to_remove : Array = []
	for effect_id in active_effects:
		if active_effects[effect_id].is_expired():
			to_remove.append(effect_id)
	for effect_id in to_remove:
		active_effects[effect_id].remove(entity)
		active_effects.erase(effect_id)
		print("Cleaned up expired effect: ", effect_id)

func _create_effect(effect_id: String):
	match effect_id:
		"Infection": return InfectionEffect.new()
		"Block":     return BlockEffect.new()
		"Bleed":     return BleedEffect.new()
		"Weak":      return WeakEffect.new()
		"Strength":  return StrengthEffect.new()
		_:
			print("ERROR: No effect class for: ", effect_id)
			return null
