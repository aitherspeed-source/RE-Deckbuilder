extends Node

# ────────────────────────────────────────────
#  STATUS EFFECTS MANAGER
#  Handles all status effects in the game:
#
#  🧫 INFECTION  — deals damage each turn, never expires
#  🛡️ BLOCK      — absorbs damage, resets each turn
#  🩸 BLEED      — deals damage and reduces by 1 each turn
#  💪 STRENGTH   — increases all attack damage dealt
#  🔱 WEAK       — reduces all attack damage dealt by 25%
#  🐢 FRAIL      — reduces all block gained by 25%
# ────────────────────────────────────────────

# ────────────────────────────────────────────
#  APPLY STATUS EFFECT to a target (player or enemy)
# ────────────────────────────────────────────
static func apply_effect(target, effect_name: String, stacks: int) -> void:
	match effect_name:

		"infection":
			target.infection += stacks
			print(target.name, " gains ", stacks,
				  " Infection 🧫 (Total: ", target.infection, ")")

		"block":
			target.block += stacks
			print(target.name, " gains ", stacks,
				  " Block 🛡️ (Total: ", target.block, ")")

		"bleed":
			target.bleed += stacks
			print(target.name, " gains ", stacks,
				  " Bleed 🩸 (Total: ", target.bleed, ")")

		"strength":
			target.strength += stacks
			print(target.name, " gains ", stacks,
				  " Strength 💪 (Total: ", target.strength, ")")

		"weak":
			target.weak += stacks
			print(target.name, " gains ", stacks,
				  " Weak 🔱 stacks (Total: ", target.weak, ")")

		"frail":
			target.frail += stacks
			print(target.name, " gains ", stacks,
				  " Frail 🐢 stacks (Total: ", target.frail, ")")

		_:
			print("WARNING: Unknown effect: ", effect_name)

# ────────────────────────────────────────────
#  PROCESS END-OF-TURN EFFECTS for a target
#  Call this at the END of each entity's turn
# ────────────────────────────────────────────
static func process_end_of_turn(target) -> void:
	print("--- Processing end-of-turn effects for: ", target.name, " ---")

	# 🧫 INFECTION — deal damage equal to stacks (never expires)
	if target.infection > 0:
		print("  🧫 Infection deals ", target.infection, " damage!")
		target.current_hp -= target.infection
		target.current_hp = max(target.current_hp, 0)
		print("  HP: ", target.current_hp, "/", target.max_hp)

	# 🩸 BLEED — deal damage equal to stacks, then reduce by 1
	if target.bleed > 0:
		print("  🩸 Bleed deals ", target.bleed, " damage!")
		target.current_hp -= target.bleed
		target.current_hp = max(target.current_hp, 0)
		target.bleed -= 1   # Bleed fades over time
		target.bleed = max(target.bleed, 0)
		print("  HP: ", target.current_hp, "/", target.max_hp,
			  " | Bleed remaining: ", target.bleed)

# ────────────────────────────────────────────
#  PROCESS START-OF-TURN EFFECTS for a target
#  Call this at the START of each entity's turn
# ────────────────────────────────────────────
static func process_start_of_turn(target) -> void:
	print("--- Processing start-of-turn effects for: ", target.name, " ---")

	# 🛡️ BLOCK resets to 0 at the start of your turn
	if target.block > 0:
		print("  🛡️ Block resets (was ", target.block, ")")
		target.block = 0

	# 🔱 WEAK — reduce by 1 stack each turn
	if target.weak > 0:
		target.weak -= 1
		print("  🔱 Weak fades. Remaining: ", target.weak)

	# 🐢 FRAIL — reduce by 1 stack each turn
	if target.frail > 0:
		target.frail -= 1
		print("  🐢 Frail fades. Remaining: ", target.frail)

# ────────────────────────────────────────────
#  CALCULATE DAMAGE with status modifiers
#  Call this BEFORE applying damage to a target
#
#  attacker = the one dealing damage
#  base     = the raw damage number from the card
#  returns  = the final damage after modifiers
# ────────────────────────────────────────────
static func calculate_damage(attacker, base_damage: int) -> int:
	var damage = base_damage

	# 💪 STRENGTH adds flat bonus damage
	if "strength" in attacker and attacker.strength > 0:
		damage += attacker.strength
		print("  💪 Strength adds ", attacker.strength, " damage!")

	# 🔱 WEAK reduces damage dealt by 25%
	if "weak" in attacker and attacker.weak > 0:
		damage = int(damage * 0.75)
		print("  🔱 Weak reduces damage to ", damage)

	return damage

# ────────────────────────────────────────────
#  CALCULATE BLOCK with status modifiers
#  Call this BEFORE applying block to a target
#
#  target   = the one gaining block
#  base     = the raw block number from the card
#  returns  = the final block after modifiers
# ────────────────────────────────────────────
static func calculate_block(target, base_block: int) -> int:
	var block = base_block

	# 🐢 FRAIL reduces block gained by 25%
	if "frail" in target and target.frail > 0:
		block = int(block * 0.75)
		print("  🐢 Frail reduces block to ", block)

	return block

# ────────────────────────────────────────────
#  GET STATUS SUMMARY — for UI display later
#  Returns a readable string of all active effects
# ────────────────────────────────────────────
static func get_status_summary(target) -> String:
	var parts : Array = []

	if "block"     in target and target.block     > 0:
		parts.append("🛡️ Block: "     + str(target.block))
	if "infection" in target and target.infection > 0:
		parts.append("🧫 Infection: " + str(target.infection))
	if "bleed"     in target and target.bleed     > 0:
		parts.append("🩸 Bleed: "     + str(target.bleed))
	if "strength"  in target and target.strength  > 0:
		parts.append("💪 Strength: "  + str(target.strength))
	if "weak"      in target and target.weak      > 0:
		parts.append("🔱 Weak: "      + str(target.weak))
	if "frail"     in target and target.frail     > 0:
		parts.append("🐢 Frail: "     + str(target.frail))

	if parts.is_empty():
		return "No active effects"
	return ", ".join(parts)
