extends Node

# ────────────────────────────────────────────
#  GAME MANAGER
#  Autoload — persists across ALL scenes.
#  Tracks everything about the current run:
#    - Player stats carried between rooms
#    - Current deck
#    - Map progress
#    - Which room we came from / going to
# ────────────────────────────────────────────

# ── RUN STATE ────────────────────────────────
var run_active     : bool  = false
var current_floor  : int   = 0   # 0 = map screen
var current_node_id: int   = -1  # Which map node player is on

# NEW: INFECTION TIER TRACKING
var current_infection_tier: int = 0
var active_devices: Array = [] # Stores your Containment Device resources

# ── PLAYER PERSISTENT STATS ──────────────────
# These carry over between every room
var player_max_hp     : int   = 70
var player_current_hp : int   = 70
var player_ammo       : int   = 3
var player_max_ammo   : int   = 3
var player_infection  : int   = 0  # Carries between rooms!
var player_gold       : int   = 0

# ── EVENT FLAGS ───────────────────────────────
# Set by EventRoom.gd, checked by CombatManager.gd
# Each flag echoes a player choice forward into future rooms
var weapons_stolen     : bool = false  # Grabbed weapons from supply cache → security guard appears before Boss
var contaminated_meds  : bool = false  # Took contaminated meds → next combat starts with +1 Infection
var survivor_helped    : bool = false  # Helped the crawling survivor → cache appears before Boss
var survivor_abandoned : bool = false  # Walked past survivor → they appear as enemy in next Hallway
var signal_jammed      : bool = false  # Overrode Umbra broadcast → next Event shows better option
var specimen_released  : bool = false  # Released mutation chamber → Specimen appears as enemy later
var umbra_alerted      : bool = false  # Reserved for future Experiment Log event

# ── EVENT TRACKING ────────────────────────────
# Prevents repeating events within a run until all 8 are exhausted
var events_seen_this_run : Array = []

# ── DECK ─────────────────────────────────────
# Stored as Array of card resource paths
# so it survives scene changes
var player_deck    : Array = []  # Array of CardData resources

# ── MAP DATA ─────────────────────────────────
var map_nodes      : Array = []  # All MapNode resources
var map_paths      : Dictionary = {}  # node_id → [connected node_ids]
var visited_nodes  : Array = []  # node_ids already visited
var available_nodes: Array = []  # node_ids player can visit next

# ── ROOM TYPE ENUM ────────────────────────────
enum RoomType {
	HALLWAY,        # Standard combat
	SAFE_ROOM,      # Heal / remove / upgrade card
	EVENT,          # Random event with choices
	ELITE,          # Tough combat, better rewards
	INFECTION_ZONE, # Apply infection, better rewards
	BOSS            # Final room of the map
}

# Room type display names and icons
const ROOM_NAMES : Dictionary = {
	RoomType.HALLWAY:        "Hallway",
	RoomType.SAFE_ROOM:      "Safe Room",
	RoomType.EVENT:          "Event",
	RoomType.ELITE:          "Elite",
	RoomType.INFECTION_ZONE: "Infection Zone",
	RoomType.BOSS:           "Boss"
}

const ROOM_ICONS : Dictionary = {
	RoomType.HALLWAY:        "🚪",
	RoomType.SAFE_ROOM:      "🏥",
	RoomType.EVENT:          "❓",
	RoomType.ELITE:          "⭐",
	RoomType.INFECTION_ZONE: "☣️",
	RoomType.BOSS:           "💀"
}

# ── SCENE PATHS ───────────────────────────────
const SCENE_MAP     = "res://scenes/Map.tscn"
const SCENE_COMBAT  = "res://scenes/Combat.tscn"
const SCENE_SAFE    = "res://scenes/rooms/SafeRoom.tscn"
const SCENE_EVENT   = "res://scenes/rooms/EventRoom.tscn"
const SCENE_BOSS    = "res://scenes/rooms/BossRoom.tscn"

# ── SIGNALS ───────────────────────────────────
signal run_started
signal room_entered(room_type: int, node_id: int)
signal room_completed(node_id: int)
signal run_ended(won: bool)
signal deck_changed
signal hp_changed(current: int, max_val: int)

# ────────────────────────────────────────────
#  START A NEW RUN
# ────────────────────────────────────────────
func start_new_run() -> void:
	print("=== STARTING NEW RUN ===")
	run_active        = true
	current_floor     = 0
	current_node_id   = -1
	player_current_hp = player_max_hp
	player_infection  = 0
	player_gold       = 0

	# Reset all event flags for a fresh run
	weapons_stolen     = false
	contaminated_meds  = false
	survivor_helped    = false
	survivor_abandoned = false
	signal_jammed      = false
	specimen_released  = false
	umbra_alerted      = false
	events_seen_this_run.clear()

	visited_nodes.clear()
	available_nodes.clear()
	map_nodes.clear()
	map_paths.clear()

	# Load the starter deck
	player_deck = CardLibrary.get_starter_deck()
	print("Starter deck loaded: ", player_deck.size(), " cards.")
	emit_signal("run_started")

# ────────────────────────────────────────────
#  ENTER A ROOM
# ────────────────────────────────────────────
func enter_room(node_id: int) -> void:
	current_node_id = node_id
	var node = get_map_node(node_id)
	if node == null:
		print("ERROR: No map node with id ", node_id)
		return

	current_floor = node.row
	print("Entering room: ", ROOM_ICONS[node.room_type],
		  " ", ROOM_NAMES[node.room_type],
		  " (Floor ", current_floor, ")")

	# Apply infection zone penalty on entry
	if node.room_type == RoomType.INFECTION_ZONE:
		player_infection += 2
		print("☣️ Infection Zone! Gained 2 Infection.",
			  " Total: ", player_infection)

	emit_signal("room_entered", node.room_type, node_id)

	# Load the correct scene for this room type
	_load_room_scene(node.room_type)

# ────────────────────────────────────────────
#  COMPLETE A ROOM
#  Call this when player finishes a room
# ────────────────────────────────────────────
func complete_room(node_id: int) -> void:
	if not visited_nodes.has(node_id):
		visited_nodes.append(node_id)

	# Update available nodes to the next connections
	available_nodes.clear()
	if map_paths.has(node_id):
		for connected_id in map_paths[node_id]:
			available_nodes.append(connected_id)

	print("Room complete! Next rooms available: ",
		  available_nodes.size())
	emit_signal("room_completed", node_id)

	# Go back to map
	get_tree().change_scene_to_file(SCENE_MAP)

# ────────────────────────────────────────────
#  LOAD ROOM SCENE by type
# ────────────────────────────────────────────
func _load_room_scene(room_type: int) -> void:
	match room_type:
		RoomType.HALLWAY, RoomType.ELITE, RoomType.INFECTION_ZONE:
			get_tree().change_scene_to_file(SCENE_COMBAT)
		RoomType.SAFE_ROOM:
			get_tree().change_scene_to_file(SCENE_SAFE)
		RoomType.EVENT:
			get_tree().change_scene_to_file(SCENE_EVENT)
		RoomType.BOSS:
			# Boss should start immediately (no placeholder click gate).
			get_tree().change_scene_to_file(SCENE_COMBAT)

# ────────────────────────────────────────────
#  PLAYER STAT HELPERS
# ────────────────────────────────────────────
func heal_player(amount: int) -> void:
	player_current_hp = min(
		player_current_hp + amount,
		player_max_hp)
	emit_signal("hp_changed", player_current_hp, player_max_hp)
	print("Player healed ", amount,
		  ". HP: ", player_current_hp, "/", player_max_hp)

func damage_player(amount: int) -> void:
	# Apply block check here later if needed
	player_current_hp = max(player_current_hp - amount, 0)
	emit_signal("hp_changed", player_current_hp, player_max_hp)
	print("Player took ", amount, " damage.",
		  " HP: ", player_current_hp, "/", player_max_hp)
	if player_current_hp <= 0:
		end_run(false)

# ────────────────────────────────────────────
#  DECK HELPERS
# ────────────────────────────────────────────
func add_card_to_deck(card: CardData) -> void:
	player_deck.append(card)
	emit_signal("deck_changed")
	print("Card added to deck: ", card.card_name,
		  " | Deck size: ", player_deck.size())

func remove_card_from_deck(card: CardData) -> void:
	player_deck.erase(card)
	emit_signal("deck_changed")
	print("Card removed from deck: ", card.card_name,
		  " | Deck size: ", player_deck.size())

# ────────────────────────────────────────────
#  MAP HELPERS
# ────────────────────────────────────────────
func get_map_node(node_id: int):
	for node in map_nodes:
		if node.node_id == node_id:
			return node
	return null

func is_node_available(node_id: int) -> bool:
	return available_nodes.has(node_id)

func is_node_visited(node_id: int) -> bool:
	return visited_nodes.has(node_id)

# ────────────────────────────────────────────
#  END RUN
# ────────────────────────────────────────────
func end_run(won: bool) -> void:
	run_active = false
	print(
		"=== RUN ENDED — ",
		"VICTORY!" if won else "DEFEAT",
		" ===")
	emit_signal("run_ended", won)
