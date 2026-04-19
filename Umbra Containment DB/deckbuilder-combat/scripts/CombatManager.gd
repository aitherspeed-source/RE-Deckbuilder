extends Node2D

# ────────────────────────────────────────────
#  COMBAT MANAGER
#  Now syncs with GameManager on entry/exit
#  Handles Elite and Infection Zone variants
# ────────────────────────────────────────────

@onready var player : Node2D = $Player
@onready var enemy  : Node2D = $Enemy
@onready var ui               = $UI/GameUI

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
	room_type = GameManager.current_node_id

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
				enemy.max_hp     = 120
				enemy.current_hp = 120
				enemy.attack_damage  = 15
				enemy.heavy_damage   = 30
				enemy.enemy_name = "The Infected"
				print("💀 BOSS combat!")

	start_player_turn()
	ui.setup()

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
