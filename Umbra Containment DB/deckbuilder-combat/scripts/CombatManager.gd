extends Node2D

# ────────────────────────────────────────────
#  COMBAT MANAGER (Fixed & Hooked)
# ────────────────────────────────────────────

# New signals for the modifier system
signal player_turn_started
signal player_turn_ended
signal card_played(card_data)

@onready var player : Node2D = $Player
@onready var enemy  : Node2D = $Enemy
@onready var ui               = $UI/GameUI
const BOSS_ENEMY_DIR := "res://data/enemies/bosses/"

var room_type : int = 0

enum TurnState { PLAYER_TURN, ENEMY_TURN, COMBAT_OVER }
var current_turn : TurnState = TurnState.PLAYER_TURN
var turn_number  : int = 1

func _ready() -> void:
	var node = GameManager.get_map_node(GameManager.current_node_id)
	if node != null: room_type = node.room_type
	
	_sync_player_from_manager()
	setup_combat()

func _sync_player_from_manager() -> void:
	# Copy basic stats
	player.current_hp = GameManager.player_current_hp
	player.max_hp     = GameManager.player_max_hp
	player.ammo       = GameManager.player_ammo
	player.max_ammo   = GameManager.player_max_ammo
	
	# FIX: Instead of player.infection = X (which crashed), 
	# we tell the EffectManager to apply the infection stacks.
	if GameManager.player_infection > 0:
		player.apply_effect("Infection", GameManager.player_infection)

func setup_combat() -> void:
	start_player_turn()

func start_player_turn() -> void:
	current_turn = TurnState.PLAYER_TURN
	player.ammo = player.max_ammo
	player.draw_cards(5)
	
	# HOOK: Tell the modifier system turn started
	player_turn_started.emit()
	RunModifierManager.trigger_turn_start()
	
func end_player_turn() -> void:
	# HOOK: Tell the modifier system turn ended
	player_turn_ended.emit()
	RunModifierManager.trigger_turn_end()
	
	player.discard_hand()
	player.on_turn_end() # This will trigger InfectionEffect.on_turn_trigger
	
	current_turn = TurnState.ENEMY_TURN
	start_enemy_turn()

func play_card(card: CardData) -> void:
	if current_turn != TurnState.PLAYER_TURN: return
	if player.ammo < card.cost: return
	
	player.ammo -= card.cost
	player.hand.erase(card)
	
	# HOOK: Tell the modifier system a card was played
	card_played.emit(card)
	RunModifierManager.trigger_card_played(card)
	
	for effect in card.effects:
		effect.apply(enemy if effect.target_enemy else player)

func start_enemy_turn() -> void:
	enemy.take_turn()
	await get_tree().create_timer(1.0).timeout
	turn_number += 1
	start_player_turn()
