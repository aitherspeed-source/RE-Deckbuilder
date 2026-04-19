extends Resource
class_name MapNode

# ────────────────────────────────────────────
#  MAP NODE RESOURCE
#  Represents one room on the map.
#  Stored in GameManager.map_nodes array.
# ────────────────────────────────────────────

# Unique ID for this node
var node_id   : int = -1

# Which row this node sits on (0 = start, 6 = boss)
var row       : int = 0

# Column position within the row (for display)
var col       : int = 0

# Room type — matches GameManager.RoomType enum
var room_type : int = 0

# Has the player already visited this room?
var visited   : bool = false

# Is this node currently selectable?
var available : bool = false

# World position on the map (set by MapGenerator)
var position  : Vector2 = Vector2.ZERO

# ────────────────────────────────────────────
#  INIT — set up a node quickly
# ────────────────────────────────────────────
func setup(id: int, p_row: int, p_col: int,
		   p_type: int, p_pos: Vector2) -> void:
	node_id   = id
	row       = p_row
	col       = p_col
	room_type = p_type
	position  = p_pos
	visited   = false
	available = false

# ────────────────────────────────────────────
#  HELPERS
# ────────────────────────────────────────────
func get_icon() -> String:
	return GameManager.ROOM_ICONS.get(room_type, "❓")

func get_display_name() -> String:
	return GameManager.ROOM_NAMES.get(room_type, "Unknown")
