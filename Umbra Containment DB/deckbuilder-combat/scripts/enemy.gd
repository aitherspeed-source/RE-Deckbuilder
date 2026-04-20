extends Node2D

# ────────────────────────────────────────────
#  SIGNALS
# ────────────────────────────────────────────
signal hp_changed(current_hp: int, max_hp: int)
signal block_changed(current_block: int)
signal infection_changed(current_infection: int)
signal intent_changed(intent_text: String)
signal enemy_evolved(new_name: String)
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
var active_intent_pool: Array[Dictionary] = []
var _phase_b_pool: Array[Dictionary] = []
var _data: EnemyData = null
var _evolution_name: String = ""
var _evolution_threshold: float = 0.5
var _has_evolved: bool = false

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
	if not active_intent_pool.is_empty():
		current_intent = _roll_intent_from_pool(active_intent_pool)
	else:
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

func after_damage() -> void:
	# Only enemies with valid evolution data can mutate.
	if _data == null:
		return
	if _data.evolution_name == "":
		return
	if _has_evolved:
		return
	if current_hp <= 0:
		return
	if float(current_hp) > float(max_hp) * _data.evolution_threshold:
		return

	_has_evolved = true
	enemy_name = _data.evolution_name
	# Mutation buff applies only when evolution actually triggers.
	effect_manager.apply_effect("Strength", 5)
	if not _phase_b_pool.is_empty():
		active_intent_pool = _phase_b_pool.duplicate(true)
	intent_override = ""
	choose_next_intent()
	emit_signal("enemy_evolved", enemy_name)
	emit_signal("intent_changed", get_intent_text())

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

func apply_from_enemy_data(data: EnemyData) -> void:
	_data = data
	enemy_name = data.enemy_name
	max_hp = data.max_hp
	current_hp = data.max_hp
	attack_damage = data.attack_damage
	heavy_damage = data.heavy_damage
	defend_amount = data.defend_amount
	infect_amount = data.infect_amount
	active_intent_pool = data.intent_pool_phase_a.duplicate(true)
	_phase_b_pool = data.intent_pool_phase_b.duplicate(true)
	_evolution_name = data.evolution_name
	_evolution_threshold = data.evolution_threshold
	_has_evolved = false
	intent_override = ""
	emit_signal("hp_changed", current_hp, max_hp)
	choose_next_intent()

func clear_evolution_data() -> void:
	_data = null
	_phase_b_pool.clear()
	_evolution_name = ""
	_evolution_threshold = 0.5
	_has_evolved = false

func _roll_intent_from_pool(pool: Array[Dictionary]) -> Intent:
	var total_weight := 0
	for item in pool:
		var w = int(item.get("weight", 1))
		total_weight += max(w, 1)

	if total_weight <= 0:
		return Intent.ATTACK

	var roll = randi() % total_weight
	var cursor := 0
	for item in pool:
		var w = max(int(item.get("weight", 1)), 1)
		cursor += w
		if roll < cursor:
			return _intent_from_kind(str(item.get("kind", "attack")))

	return Intent.ATTACK

func _intent_from_kind(kind: String) -> Intent:
	match kind.to_lower():
		"attack":
			return Intent.ATTACK
		"defend":
			return Intent.DEFEND
		"infect":
			return Intent.INFECT
		"heavy", "heavy_attack":
			return Intent.HEAVY_ATTACK
		_:
			return Intent.ATTACK
