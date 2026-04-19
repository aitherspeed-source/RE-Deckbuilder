extends Node2D

# ────────────────────────────────────────────
#  SIGNALS
# ────────────────────────────────────────────
signal hp_changed(current_hp: int, max_hp: int)
signal block_changed(current_block: int)
signal infection_changed(current_infection: int)
signal intent_changed(intent_text: String)
signal enemy_died

# ────────────────────────────────────────────
#  ENEMY IDENTITY
# ────────────────────────────────────────────
var enemy_name   : String = "Infected Grunt"

# ────────────────────────────────────────────
#  ENEMY STATS
# ────────────────────────────────────────────
var max_hp       : int = 40
var current_hp   : int = 40

# ────────────────────────────────────────────
#  EFFECT MANAGER REFERENCE
# ────────────────────────────────────────────
@onready var effect_manager = $EffectManager

# ────────────────────────────────────────────
#  INTENT SYSTEM
# ────────────────────────────────────────────
enum Intent {
	ATTACK,
	DEFEND,
	INFECT,
	HEAVY_ATTACK
}

var current_intent : Intent  = Intent.ATTACK
var attack_damage  : int     = 8
var heavy_damage   : int     = 18
var defend_amount  : int     = 6
var infect_amount  : int     = 2
# Optional override — set by event flags (e.g. Turned Survivor)
var intent_override : String = ""

# ────────────────────────────────────────────
#  READY
# ────────────────────────────────────────────
func _ready() -> void:
	effect_manager.setup(self)
	print(enemy_name, " ready! HP: ", current_hp, "/", max_hp)
	choose_next_intent()

# ────────────────────────────────────────────
#  INTENT
# ────────────────────────────────────────────
func choose_next_intent() -> void:
	var roll = randi() % 4
	match roll:
		0: current_intent = Intent.ATTACK
		1: current_intent = Intent.DEFEND
		2: current_intent = Intent.INFECT
		3: current_intent = Intent.HEAVY_ATTACK
	emit_signal("intent_changed", get_intent_text())
	print(enemy_name, " intends to: ",
		  Intent.keys()[current_intent])

func get_intent_text() -> String:
	if intent_override != "":
		return intent_override
	match current_intent:
		Intent.ATTACK:
			return "⚔️ Attack for " + str(attack_damage)
		Intent.DEFEND:
			return "🛡️ Defend +" + str(defend_amount) + " Block"
		Intent.INFECT:
			return "🧫 Infect +" + str(infect_amount)
		Intent.HEAVY_ATTACK:
			return "💥 Heavy Attack for " + str(heavy_damage)
		_:
			return "???"

# ────────────────────────────────────────────
#  EXECUTE INTENT
# ────────────────────────────────────────────
func execute_intent(player) -> void:
	print(enemy_name, " executes: ",
		  Intent.keys()[current_intent])

	match current_intent:
		Intent.ATTACK:
			# Calculate outgoing damage with Strength/Weak
			var dmg = effect_manager.calculate_outgoing_damage(
				attack_damage)
			player.effect_manager.receive_damage(dmg)

		Intent.DEFEND:
			effect_manager.apply_effect("Block", defend_amount)

		Intent.INFECT:
			player.add_infection(infect_amount)

		Intent.HEAVY_ATTACK:
			var dmg = effect_manager.calculate_outgoing_damage(
				heavy_damage)
			player.effect_manager.receive_damage(dmg)

	choose_next_intent()

# ────────────────────────────────────────────
#  TAKE DAMAGE
#  Routes through EffectManager
# ────────────────────────────────────────────
func take_damage(amount: int) -> void:
	effect_manager.receive_damage(amount)

# ────────────────────────────────────────────
#  BLOCK + INFECTION — via EffectManager
# ────────────────────────────────────────────
func add_block(amount: int) -> void:
	effect_manager.apply_effect("Block", amount)

func add_infection(amount: int) -> void:
	effect_manager.apply_effect("Infection", amount)

# ────────────────────────────────────────────
#  TURN SYSTEM
# ────────────────────────────────────────────
func start_turn(player) -> void:
	print("--- ", enemy_name, "'s turn ---")
	effect_manager.trigger_turn_start()
	execute_intent(player)
	effect_manager.trigger_turn_end()

func reset_block() -> void:
	effect_manager.apply_effect("Block", 0)
	emit_signal("block_changed", 0)

# ────────────────────────────────────────────
#  DEATH
# ────────────────────────────────────────────
func die() -> void:
	emit_signal("enemy_died")
	print(enemy_name, " has been defeated!")
