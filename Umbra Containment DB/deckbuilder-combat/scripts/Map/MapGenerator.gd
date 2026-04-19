extends Node

# ────────────────────────────────────────────
#  MAP GENERATOR
#  Builds a 7-row branching map like Slay the Spire
#
#  ROW LAYOUT:
#   Row 0 → Always starts with 1 Hallway (entry point)
#   Row 1 → Branches out (2-3 nodes)
#   Row 2 → Mix of room types
#   Row 3 → More branching
#   Row 4 → Elite or Infection Zone guaranteed
#   Row 5 → Narrows back down
#   Row 6 → Always Boss
#
#  ROOM TYPE WEIGHTS per row:
#  Each row has a weighted pool of room types
#  so the map feels varied but fair
# ────────────────────────────────────────────

# How many nodes can appear in each row
const ROW_NODE_COUNTS : Array = [1, 3, 3, 2, 3, 2, 1]

# Room type pools per row
# Each entry is [RoomType, weight]
# Higher weight = appears more often
const ROW_POOLS : Array = [
	# Row 0 — Entry (always Hallway)
	[[0, 1]],
	# Row 1 — Early rooms
	[[0, 5], [2, 3], [1, 2]],
	# Row 2 — Mix
	[[0, 4], [2, 3], [1, 2], [5, 1]],
	# Row 3 — Getting harder
	[[0, 3], [2, 2], [4, 3], [3, 2]],
	# Row 4 — Elites and Infection
	[[3, 3], [4, 3], [0, 2], [2, 2]],
	# Row 5 — Pre-boss
	[[0, 3], [1, 3], [2, 2], [3, 2]],
	# Row 6 — Always Boss
	[[5, 1]]
]

# ────────────────────────────────────────────
#  GENERATE MAP
#  Returns nothing — writes directly into
#  GameManager.map_nodes and GameManager.map_paths
# ────────────────────────────────────────────
static func generate() -> void:
	GameManager.map_nodes.clear()
	GameManager.map_paths.clear()

	var next_id   : int   = 0
	# Stores node_ids per row for path connection
	var rows      : Array = []

	print("=== GENERATING MAP ===")

	# ── STEP 1: Create all nodes ─────────────
	for row_index in range(ROW_NODE_COUNTS.size()):
		var count     = ROW_NODE_COUNTS[row_index]
		var pool      = ROW_POOLS[row_index]
		var row_nodes : Array = []

		for col_index in range(count):
			var room_type = _pick_room_type(pool)
			var node      = MapNode.new()

			# Space nodes evenly across the screen
			var x = _get_node_x(col_index, count)
			var y = _get_node_y(row_index)

			node.setup(next_id, row_index,
					   col_index, room_type,
					   Vector2(x, y))

			GameManager.map_nodes.append(node)
			row_nodes.append(next_id)
			next_id += 1

			print("  Row ", row_index,
				  " Col ", col_index,
				  " → ", node.get_icon(),
				  " ", node.get_display_name(),
				  " (id:", node.node_id, ")")

		rows.append(row_nodes)

	# ── STEP 2: Connect rows with paths ──────
	for row_index in range(rows.size() - 1):
		var current_row = rows[row_index]
		var next_row    = rows[row_index + 1]

		for from_id in current_row:
			# Each node connects to 1-2 nodes in next row
			var connections = _pick_connections(
				from_id, current_row,
				next_row, row_index)

			GameManager.map_paths[from_id] = connections
			print("  Node ", from_id,
				  " → connects to: ", connections)

	# Boss node has no outgoing connections
	var boss_id = rows[rows.size() - 1][0]
	GameManager.map_paths[boss_id] = []

	# ── STEP 3: Set first node as available ───
	var start_id = rows[0][0]
	GameManager.available_nodes = [start_id]
	var start_node = GameManager.get_map_node(start_id)
	if start_node:
		start_node.available = true

	print("=== MAP GENERATED ===")
	print("  Total nodes: ", GameManager.map_nodes.size())
	print("  Start node: ", start_id)
	print("  Boss node: ", boss_id)

# ────────────────────────────────────────────
#  PRIVATE HELPERS
# ────────────────────────────────────────────

# Pick a room type from a weighted pool
static func _pick_room_type(pool: Array) -> int:
	# Calculate total weight
	var total_weight : int = 0
	for entry in pool:
		total_weight += entry[1]

	# Pick a random point in the weight range
	var roll = randi() % total_weight
	var cumulative = 0

	for entry in pool:
		cumulative += entry[1]
		if roll < cumulative:
			return entry[0]

	# Fallback
	return pool[0][0]

# Pick which next-row nodes to connect to
static func _pick_connections(from_id: int,
		current_row: Array,
		next_row: Array,
		row_index: int) -> Array:

	var connections : Array = []

	# Always connect to at least one next node
	# Use position in row to pick natural connections
	var from_index = current_row.find(from_id)
	var ratio = float(from_index) / max(current_row.size() - 1, 1)

	# Map ratio to next row index
	var target_index = int(
		round(ratio * (next_row.size() - 1)))
	target_index = clamp(
		target_index, 0, next_row.size() - 1)

	connections.append(next_row[target_index])

	# 40% chance to also connect to an adjacent node
	if next_row.size() > 1 and randf() < 0.4:
		var alt_index = target_index + (
			1 if target_index == 0 else -1)
		alt_index = clamp(
			alt_index, 0, next_row.size() - 1)
		var alt_id = next_row[alt_index]
		if not connections.has(alt_id):
			connections.append(alt_id)

	return connections

# Calculate X position for a node
static func _get_node_x(col: int, count: int) -> float:
	# Spread nodes evenly across 900px width
	# centered around x=500
	var total_width : float = 700.0
	var start_x     : float = 150.0
	if count == 1:
		return start_x + total_width / 2.0
	return start_x + (float(col) / (count - 1)) * total_width

# Calculate Y position for a node (row 0 = top)
static func _get_node_y(row: int) -> float:
	# 7 rows spread across 560px height
	# Row 0 at top (y=80), Row 6 at bottom (y=640)
	var start_y     : float = 80.0
	var total_height: float = 560.0
	var row_count   : int   = ROW_NODE_COUNTS.size()
	return start_y + (float(row) / (row_count - 1)) * total_height
