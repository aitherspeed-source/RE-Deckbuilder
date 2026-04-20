extends Node2D

# ────────────────────────────────────────────
#  MAP SCENE
#  Displays the generated map and handles
#  player navigation between rooms
# ────────────────────────────────────────────

@onready var path_layer = $PathLayer
@onready var map_ui     = $UI/MapUI

# Visual settings for nodes
const NODE_RADIUS      : float = 28.0
const NODE_FONT_SIZE   : int   = 18

# Colors for each state
const COLOR_AVAILABLE  : Color = Color(1.0, 0.9, 0.2)   # Yellow
const COLOR_VISITED    : Color = Color(0.4, 0.4, 0.4)   # Grey
const COLOR_LOCKED     : Color = Color(0.2, 0.2, 0.25)  # Dark
const COLOR_CURRENT    : Color = Color(0.2, 1.0, 0.4)   # Green
const COLOR_PATH       : Color = Color(0.5, 0.5, 0.6)   # Dim blue
const COLOR_PATH_AVAIL : Color = Color(0.8, 0.8, 0.3)   # Bright

# Room type colors
const ROOM_COLORS : Dictionary = {
	0: Color(0.8, 0.3, 0.3),   # Hallway — red
	1: Color(0.3, 0.8, 0.5),   # Safe Room — green
	2: Color(0.5, 0.3, 0.8),   # Event — purple
	3: Color(1.0, 0.5, 0.0),   # Elite — orange
	4: Color(0.2, 0.7, 0.2),   # Infection Zone — dark green
	5: Color(0.9, 0.1, 0.1),   # Boss — bright red
}

# Stores button references by node_id
var node_buttons : Dictionary = {}

# ────────────────────────────────────────────
#  READY
# ────────────────────────────────────────────
func _ready() -> void:
	if not GameManager.run_active:
		GameManager.start_new_run()
		MapGenerator.generate()
	elif GameManager.map_nodes.is_empty():
		MapGenerator.generate()

	build_map_ui()
	build_header()
	print("Map scene ready. Nodes: ",
		  GameManager.map_nodes.size())

# ────────────────────────────────────────────
#  BUILD MAP UI
#  Draws paths first then nodes on top
# ────────────────────────────────────────────
func build_map_ui() -> void:
	# Clear any existing children
	for child in path_layer.get_children():
		child.queue_free()
	for child in map_ui.get_children():
		child.queue_free()
	node_buttons.clear()

	# Draw paths between connected nodes
	_draw_all_paths()

	# Draw each node as a button
	for node in GameManager.map_nodes:
		_create_node_button(node)

# ────────────────────────────────────────────
#  DRAW ALL PATHS
# ────────────────────────────────────────────
func _draw_all_paths() -> void:
	for from_id in GameManager.map_paths:
		var from_node = GameManager.get_map_node(from_id)
		if from_node == null:
			continue
		for to_id in GameManager.map_paths[from_id]:
			var to_node = GameManager.get_map_node(to_id)
			if to_node == null:
				continue
			_draw_path_line(from_node, to_node)

func _draw_path_line(from_node, to_node) -> void:
	var line      = Line2D.new()
	var is_active = (
		GameManager.is_node_visited(from_node.node_id) and
		GameManager.is_node_available(to_node.node_id)
	)
	line.default_color = (
		COLOR_PATH_AVAIL if is_active else COLOR_PATH)
	line.width         = 3.0
	line.add_point(from_node.position)
	line.add_point(to_node.position)
	path_layer.add_child(line)

# ────────────────────────────────────────────
#  CREATE NODE BUTTON
# ────────────────────────────────────────────
func _create_node_button(node) -> void:
	var is_visited   = GameManager.is_node_visited(node.node_id)
	var is_available = GameManager.is_node_available(node.node_id)
	var is_current   = (node.node_id == GameManager.current_node_id)

	# Container to hold icon + label
	var container = Control.new()
	container.position = node.position - Vector2(NODE_RADIUS, NODE_RADIUS)
	container.size     = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2 + 24)
	map_ui.add_child(container)

	# Circle button
	var btn = Button.new()
	btn.size         = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)
	btn.position     = Vector2(0, 0)
	btn.text         = node.get_icon()
	btn.add_theme_font_size_override("font_size", NODE_FONT_SIZE)
	btn.tooltip_text = node.get_display_name()

	# Color and state
	if is_current:
		btn.modulate = COLOR_CURRENT
	elif is_available:
		btn.modulate = COLOR_AVAILABLE
		btn.disabled = false
	elif is_visited:
		btn.modulate = COLOR_VISITED
		btn.disabled = true
	else:
		btn.modulate = COLOR_LOCKED
		btn.disabled = true

	# Apply room type color as background tint
	var room_color   = ROOM_COLORS.get(node.room_type, Color.WHITE)
	if is_available:
		btn.self_modulate = room_color
	else:
		btn.self_modulate = room_color.darkened(0.5)

	# Connect click
	var node_id = node.node_id
	btn.pressed.connect(func(): _on_node_pressed(node_id))
	container.add_child(btn)

	# Label below the button
	var label        = Label.new()
	label.text       = node.get_display_name()
	label.position   = Vector2(-20, NODE_RADIUS * 2 + 2)
	label.size       = Vector2(NODE_RADIUS * 4, 20)
	label.add_theme_font_size_override("font_size", 10)
	if is_available:
		label.add_theme_color_override(
			"font_color", COLOR_AVAILABLE)
	else:
		label.add_theme_color_override(
			"font_color", Color(0.5, 0.5, 0.5))
	container.add_child(label)

	node_buttons[node.node_id] = btn

# ────────────────────────────────────────────
#  BUILD HEADER — player stats at top
# ────────────────────────────────────────────
func build_header() -> void:
	var header = PanelContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.custom_minimum_size = Vector2(0, 58)
	map_ui.add_child(header)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	header.add_theme_stylebox_override("panel", bg_style)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	header.add_child(margin)

	var row = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var hp_label  = Label.new()
	hp_label.text = "❤️ HP: " + str(GameManager.player_current_hp) + \
		" / " + str(GameManager.player_max_hp)
	hp_label.add_theme_font_size_override("font_size", 18)
	row.add_child(hp_label)

	var inf_label = Label.new()
	inf_label.text = "🧫 Infection: " + str(GameManager.player_infection)
	inf_label.add_theme_font_size_override("font_size", 18)
	inf_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	row.add_child(inf_label)

	var deck_label = Label.new()
	deck_label.text = "🃏 Deck: " + str(GameManager.player_deck.size()) + " cards"
	deck_label.add_theme_font_size_override("font_size", 18)
	row.add_child(deck_label)

	var floor_label = Label.new()
	floor_label.text = "🗺️ Floor: " + str(GameManager.current_floor)
	floor_label.add_theme_font_size_override("font_size", 18)
	row.add_child(floor_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var title = Label.new()
	title.text = "SELECT YOUR PATH"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	row.add_child(title)

# ────────────────────────────────────────────
#  NODE PRESSED
# ────────────────────────────────────────────
func _on_node_pressed(node_id: int) -> void:
	if not GameManager.is_node_available(node_id):
		print("Node ", node_id, " is not available!")
		return

	var node = GameManager.get_map_node(node_id)
	if node == null:
		return

	print("Player selected: ", node.get_icon(),
		  " ", node.get_display_name())

	# Enter the room — GameManager handles scene change
	GameManager.enter_room(node_id)
