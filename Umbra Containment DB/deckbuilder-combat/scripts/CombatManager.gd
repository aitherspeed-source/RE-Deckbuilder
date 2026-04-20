extends Node2D

# ────────────────────────────────────────────
#  COMBAT MANAGER
#  Now syncs with GameManager on entry/exit
#  Handles Elite and Infection Zone variants
# ────────────────────────────────────────────

@onready var player : Node2D = $Player
@onready var enemy  : Node2D = $Enemy
@onready var ui               = $UI/GameUI
const BOSS_ENEMY_DIR := "res://data/enemies/bosses/"

# What type of combat is this?
# Pulled from GameManager on _ready
var room_type : int = 0

enum TurnState {
	PLAYER_TURN,
	ENEMY_TURN,
	COMBAT_OVER
}

var current_turn : TurnState = TurnState.PLAYER_TURN
var turn_number  : int = 1

# ────────────────────────────────────────────
#  READY — sync from GameManager
# ────────────────────────────────────────────
func _ready() -> void:
	var node = GameManager.get_map_node(GameManager.current_node_id)
	if node != null:
		room_type = node.room_type

	print("=============================")
	print("   COMBAT BEGIN!")
	print("=============================")

	# Sync player stats FROM GameManager
	_sync_player_from_manager()
	setup_combat()

# ────────────────────────────────────────────
#  SYNC PLAYER FROM MANAGER
#  Loads HP, infection, deck from the run state
# ────────────────────────────────────────────
func _sync_player_from_manager() -> void:
	# Copy HP
	player.current_hp = GameManager.player_current_hp
	player.max_hp     = GameManager.player_max_hp

	# Copy deck (duplicate so originals stay clean)
	player.deck = []
	for card in GameManager.player_deck:
		player.deck.append(card.duplicate())
	player.deck.shuffle()

	# Apply carried infection from GameManager
	if GameManager.player_infection > 0:
		player.effect_manager.apply_effect(
			"Infection", GameManager.player_infection)

	print("Synced from GameManager:")
	print("  HP: ", player.current_hp, "/", player.max_hp)
	print("  Deck: ", player.deck.size(), " cards")
	print("  Infection: ", GameManager.player_infection)

	# ── CHECK EVENT FLAGS ─────────────────────────
	# Contaminated meds: this combat starts with +1 extra Infection
	if GameManager.contaminated_meds:
		player.effect_manager.apply_effect("Infection", 1)
		GameManager.contaminated_meds = false
		print("☣️ Contaminated meds: +1 Infection at combat start")

	# Survivor abandoned: they turned and tracked you down
	if GameManager.survivor_abandoned:
		enemy.enemy_name     = "Turned Survivor"
		enemy.intent_override = "...You left me..."
		GameManager.survivor_abandoned = false
		print("🧟 The survivor you abandoned has turned.")

	# Specimen released: it found you — appears as tougher enemy in a Hallway
	if GameManager.specimen_released:
		var _node = GameManager.get_map_node(GameManager.current_node_id)
		if _node != null and _node.room_type == GameManager.RoomType.HALLWAY:
			enemy.enemy_name    = "The Specimen"
			enemy.max_hp        = 55
			enemy.current_hp    = 55
			enemy.attack_damage = 10
			enemy.heavy_damage  = 20
			GameManager.specimen_released = false
			print("🩸 The Specimen has tracked you down!")

# ────────────────────────────────────────────
#  SYNC PLAYER TO MANAGER
#  Saves HP, infection back after combat
# ────────────────────────────────────────────
func _sync_player_to_manager() -> void:
	GameManager.player_current_hp = player.current_hp
	GameManager.player_max_hp     = player.max_hp
	GameManager.player_infection  = \
		player.effect_manager.get_stacks("Infection")
	# Deck is already updated via GameManager.player_deck
	print("Synced back to GameManager:")
	print("  HP: ", GameManager.player_current_hp)
	print("  Infection: ", GameManager.player_infection)

# ────────────────────────────────────────────
#  SETUP COMBAT
# ────────────────────────────────────────────
func setup_combat() -> void:
	print("Deck loaded: ", player.deck.size(), " cards.")
	# Hallway/normal fights should not carry evolution metadata.
	enemy.clear_evolution_data()

	# Scale enemy for Elite rooms
	var node = GameManager.get_map_node(
		GameManager.current_node_id)
	if node != null:
		match node.room_type:
			GameManager.RoomType.ELITE:
				enemy.max_hp     = 70
				enemy.current_hp = 70
				enemy.attack_damage  = 12
				enemy.heavy_damage   = 24
				print("⭐ Elite combat! Enemy buffed.")
			GameManager.RoomType.INFECTION_ZONE:
				enemy.max_hp     = 35
				enemy.current_hp = 35
				print("☣️ Infection Zone combat!")
			GameManager.RoomType.BOSS:
				var boss_data = _load_random_boss_enemy_data()
				if boss_data != null:
					enemy.apply_from_enemy_data(boss_data)
					print("💀 BOSS combat! Loaded: ", boss_data.enemy_name)
				else:
					enemy.max_hp     = 120
					enemy.current_hp = 120
					enemy.attack_damage  = 15
					enemy.heavy_damage   = 30
					enemy.enemy_name = "The Infected"
					print("💀 BOSS combat! (fallback)")

	ui.setup()
	start_player_turn()

# ────────────────────────────────────────────
#  PLAYER TURN
# ────────────────────────────────────────────
func start_player_turn() -> void:
	current_turn = TurnState.PLAYER_TURN
	print("")
	print("─────────────────────────────")
	print("  TURN ", turn_number, " — YOUR TURN")
	print("─────────────────────────────")
	enemy.reset_block()
	player.start_turn()
	print("Intent: ", enemy.get_intent_text())
	# Re-enable the End Turn button now that it's actually the player's turn
	ui.end_turn_button.disabled = false
	ui.rebuild_hand()

func play_card(index: int) -> void:
	if current_turn != TurnState.PLAYER_TURN:
		print("It's not your turn!")
		return
	if index < 0 or index >= player.hand.size():
		print("No card at index ", index)
		return

	var card = player.hand[index]
	if player.ammo < card.cost:
		print("Not enough ammo!")
		return

	player.spend_ammo(card.cost)
	CardLibrary.execute_card(card, player, enemy)
	player.play_card(card)
	print_combat_state()
	check_combat_end()

func end_player_turn() -> void:
	if current_turn != TurnState.PLAYER_TURN:
		return
	print("")
	print("You end your turn.")
	player.end_turn()
	check_combat_end()
	if current_turn != TurnState.COMBAT_OVER:
		start_enemy_turn()

# ────────────────────────────────────────────
#  ENEMY TURN
# ────────────────────────────────────────────
func start_enemy_turn() -> void:
	current_turn = TurnState.ENEMY_TURN
	print("")
	print("─────────────────────────────")
	print("  ENEMY TURN")
	print("─────────────────────────────")
	enemy.start_turn(player)
	print_combat_state()
	check_combat_end()
	if current_turn != TurnState.COMBAT_OVER:
		turn_number += 1
		start_player_turn()

# ────────────────────────────────────────────
#  CHECK WIN / LOSS
# ────────────────────────────────────────────
func check_combat_end() -> void:
	if enemy.current_hp <= 0:
		current_turn = TurnState.COMBAT_OVER
		print("Enemy defeated!")
		_sync_player_to_manager()
		var node = GameManager.get_map_node(GameManager.current_node_id)
		if node != null and node.room_type == GameManager.RoomType.BOSS:
			print("Facility Cleared!")
			GameManager.end_run(true)
			ui.show_result(true)
		else:
			ui.show_reward_screen()
		return

	if player.current_hp <= 0:
		current_turn = TurnState.COMBAT_OVER
		print("Player died!")
		_sync_player_to_manager()
		GameManager.end_run(false)
		ui.show_result(false)
		return

# ────────────────────────────────────────────
#  PRINT COMBAT STATE
# ────────────────────────────────────────────
func print_combat_state() -> void:
	print("")
	print("[ PLAYER ] HP: ", player.current_hp, "/", player.max_hp,
		" | Block: ", player.effect_manager.get_stacks("Block"),
		" | Ammo: ", player.ammo, "/", player.max_ammo,
		" | Infection: ", player.effect_manager.get_stacks("Infection"))
	print("[ ENEMY  ] HP: ", enemy.current_hp, "/", enemy.max_hp,
		" | Block: ", enemy.effect_manager.get_stacks("Block"))
	print("[ HAND   ] ", player.hand.size(), " cards:")
	for i in range(player.hand.size()):
		var c = player.hand[i]
		print("  [", i, "] ", c.card_name,
			  " (Cost: ", c.cost, ")")
	print("")

func _load_random_boss_enemy_data() -> EnemyData:
	var resources : Array[EnemyData] = []
	var seen_paths := {}

	var dir := DirAccess.open(BOSS_ENEMY_DIR)
	if dir == null:
		print("No boss enemy directory: ", BOSS_ENEMY_DIR)
		return null

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var candidate = _normalize_enemy_resource_name(file_name)
			if candidate != "":
				var full_path = BOSS_ENEMY_DIR + candidate
				if ResourceLoader.exists(full_path) and not seen_paths.has(full_path):
					seen_paths[full_path] = true
					var loaded = ResourceLoader.load(full_path)
					if loaded is EnemyData:
						resources.append(loaded as EnemyData)
					else:
						print("Skipped non-EnemyData resource: ", full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	if resources.is_empty():
		return null

	resources.shuffle()
	return resources[0]

func _normalize_enemy_resource_name(file_name: String) -> String:
	var normalized := file_name
	if normalized.ends_with(".import"):
		normalized = normalized.substr(0, normalized.length() - ".import".length())
	if normalized.ends_with(".remap"):
		normalized = normalized.substr(0, normalized.length() - ".remap".length())
	if not normalized.ends_with(".tres"):
		return ""
	return normalized
