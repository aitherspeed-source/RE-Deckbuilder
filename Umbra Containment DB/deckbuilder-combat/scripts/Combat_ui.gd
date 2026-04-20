extends Control

# ────────────────────────────────────────────
#  COMBAT UI
# ────────────────────────────────────────────

# Step 6: background + text hierarchy (intent > headline > body)
const COLOR_BG := Color(0.06, 0.07, 0.10, 1.0)
const COLOR_TEXT_INTENT := Color(1.0, 0.82, 0.28)
const COLOR_TEXT_HEADLINE := Color(0.93, 0.94, 0.96)
const COLOR_TEXT_BODY := Color(0.70, 0.72, 0.76)
const COLOR_TEXT_MUTED := Color(0.50, 0.52, 0.56)
const FONT_INTENT := 24
const FONT_TITLE := 22
const FONT_ENEMY_NAME := 20
const FONT_BODY := 13
const FONT_SECTION := 14
const FONT_HAND_CARD := 14

# Step 7: spacing polish, card text trim, full-width HP bars
const MARGIN_SCREEN := 14
const SEP_MAIN_V := 8
const SEP_BOTTOM_ROW := 10
const SEP_HAND := 8
const SEP_ACTIONS := 6
const SEP_INTENT_TOP := 8
const SEP_PANEL_INNER := 4
const CARD_DESC_MAX_CHARS := 72

var combat_manager

var enemy_name_label       : Label
var enemy_hp_bar           : ProgressBar
var enemy_hp_label         : Label
var enemy_block_label      : Label
var enemy_intent_label     : Label
var player_hp_bar          : ProgressBar
var player_hp_label        : Label
var player_block_label     : Label
var player_ammo_label      : Label
var player_infection_label : Label
var hand_container         : HBoxContainer
var end_turn_button        : Button
var card_buttons           : Array = []
var evolution_flash_overlay: ColorRect
var rng := RandomNumberGenerator.new()
var _viewport_connected := false
const MUTATION_FLASH_COLOR := Color(0.5, 0.0, 1.0, 0.6)
const ELITE_CINEMATIC_EVOLUTIONS := [
	"Containment MR.X",
	"Enraged Alpha Stalker",
	"Apex Licker"
]

# ────────────────────────────────────────────
func _ready() -> void:
	combat_manager = get_parent().get_parent()
	rng.randomize()

func setup() -> void:
	build_ui()
	connect_signals()
	if not _viewport_connected:
		get_viewport().size_changed.connect(_on_viewport_resized)
		_viewport_connected = true

# ────────────────────────────────────────────
#  SIGNALS
# ────────────────────────────────────────────
func connect_signals() -> void:
	var player = combat_manager.player
	var enemy  = combat_manager.enemy
	player.hp_changed.connect(_on_player_hp_changed)
	player.block_changed.connect(_on_player_block_changed)
	player.ammo_changed.connect(_on_player_ammo_changed)
	player.infection_changed.connect(_on_player_infection_changed)
	enemy.hp_changed.connect(_on_enemy_hp_changed)
	enemy.block_changed.connect(_on_enemy_block_changed)
	enemy.intent_changed.connect(_on_enemy_intent_changed)
	if enemy.has_signal("enemy_evolved"):
		enemy.enemy_evolved.connect(_on_enemy_evolved)

func _on_player_hp_changed(current_hp: int, max_hp: int) -> void:
	player_hp_bar.max_value = max_hp
	player_hp_bar.value = current_hp
	player_hp_label.text = str(current_hp) + " / " + str(max_hp)

func _on_player_block_changed(current_block: int) -> void:
	player_block_label.text = "🛡️ Block: " + str(current_block)

func _on_player_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	player_ammo_label.text = "🔵 Ammo: " + str(current_ammo) + " / " + str(max_ammo)
	rebuild_hand()

func _on_player_infection_changed(current_infection: int) -> void:
	player_infection_label.text = "🧫 Infection: " + str(current_infection)

func _on_enemy_hp_changed(current_hp: int, max_hp: int) -> void:
	enemy_hp_bar.max_value = max_hp
	enemy_hp_bar.value = current_hp
	enemy_hp_label.text = str(current_hp) + " / " + str(max_hp)

func _on_enemy_block_changed(current_block: int) -> void:
	enemy_block_label.text = "🛡️ Block: " + str(current_block)

func _on_enemy_intent_changed(intent_text: String) -> void:
	enemy_intent_label.text = "NEXT: " + intent_text

func _on_enemy_evolved(new_name: String) -> void:
	var play_cinematic = false
	var room_type = combat_manager.room_type if combat_manager != null else -1
	if room_type == GameManager.RoomType.BOSS:
		play_cinematic = true
	elif ELITE_CINEMATIC_EVOLUTIONS.has(new_name):
		play_cinematic = true

	# Bosses and selected elite evolutions get the full cinematic pause.
	# Standard hallway evolutions only perform an immediate name update.
	if play_cinematic:
		await _play_evolution_fx(new_name)
	else:
		enemy_name_label.text = new_name

func _make_hp_bar(current_hp: int, max_hp: int) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.max_value = max_hp
	bar.value = current_hp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	return bar

func _hand_card_stylebox(fill: Color, border_col: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_content_margin_all(6)
	return sb

func _apply_hand_card_style(btn: Button) -> void:
	var normal = _hand_card_stylebox(
		Color(0.14, 0.15, 0.20),
		Color(0.40, 0.44, 0.50)
	)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override(
		"hover",
		_hand_card_stylebox(
			Color(0.18, 0.19, 0.25),
			Color(0.50, 0.56, 0.62)
		)
	)
	btn.add_theme_stylebox_override(
		"pressed",
		_hand_card_stylebox(
			Color(0.11, 0.12, 0.17),
			Color(0.36, 0.40, 0.46)
		)
	)
	btn.add_theme_stylebox_override(
		"disabled",
		_hand_card_stylebox(
			Color(0.09, 0.10, 0.13),
			Color(0.24, 0.26, 0.30)
		)
	)
	var focus_sb = normal.duplicate() as StyleBoxFlat
	btn.add_theme_stylebox_override("focus", focus_sb)

func _truncate_card_description(text: String) -> String:
	if text.length() <= CARD_DESC_MAX_CHARS:
		return text
	var cut: int = CARD_DESC_MAX_CHARS - 1
	return text.substr(0, cut).strip_edges() + "…"

func _calc_hand_card_size(card_count: int) -> Vector2:
	var count = max(card_count, 1)
	var available_w = max(hand_container.size.x, get_viewport_rect().size.x * 0.52)
	var spacing_total = float(max(count - 1, 0) * SEP_HAND)
	var raw_w = (available_w - spacing_total) / float(count)
	var card_w = clampf(raw_w, 82.0, 126.0)
	var card_h = clampf(card_w * 1.45, 122.0, 180.0)
	return Vector2(card_w, card_h)

# ────────────────────────────────────────────
#  BUILD UI
# ────────────────────────────────────────────
func build_ui() -> void:
	var player = combat_manager.player
	var enemy  = combat_manager.enemy

	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin_root = MarginContainer.new()
	margin_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_root.add_theme_constant_override("margin_left", MARGIN_SCREEN)
	margin_root.add_theme_constant_override("margin_top", MARGIN_SCREEN)
	margin_root.add_theme_constant_override("margin_right", MARGIN_SCREEN)
	margin_root.add_theme_constant_override("margin_bottom", MARGIN_SCREEN)
	add_child(margin_root)

	evolution_flash_overlay = ColorRect.new()
	evolution_flash_overlay.color = Color(0.9, 0.1, 0.1, 0.0)
	evolution_flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	evolution_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(evolution_flash_overlay)

	var main = VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", SEP_MAIN_V)
	margin_root.add_child(main)

	var title = Label.new()
	title.text = "⚔️ COMBAT"
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", COLOR_TEXT_HEADLINE)
	main.add_child(title)

	var enemy_center = CenterContainer.new()
	main.add_child(enemy_center)

	# ── ENEMY PANEL ─────────────────────────
	var enemy_panel = PanelContainer.new()
	enemy_panel.custom_minimum_size = Vector2(400, 170)
	enemy_center.add_child(enemy_panel)

	var enemy_vbox = VBoxContainer.new()
	enemy_vbox.add_theme_constant_override("separation", SEP_PANEL_INNER)
	enemy_panel.add_child(enemy_vbox)

	enemy_name_label = Label.new()
	enemy_name_label.text = enemy.enemy_name
	enemy_name_label.add_theme_font_size_override("font_size", FONT_ENEMY_NAME)
	enemy_name_label.add_theme_color_override("font_color", COLOR_TEXT_HEADLINE)
	enemy_vbox.add_child(enemy_name_label)

	enemy_hp_bar = _make_hp_bar(enemy.current_hp, enemy.max_hp)
	enemy_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_vbox.add_child(enemy_hp_bar)

	enemy_hp_label = Label.new()
	enemy_hp_label.text = str(enemy.current_hp) + " / " + str(enemy.max_hp)
	enemy_hp_label.add_theme_font_size_override("font_size", FONT_BODY)
	enemy_hp_label.add_theme_color_override("font_color", COLOR_TEXT_BODY)
	enemy_vbox.add_child(enemy_hp_label)

	enemy_block_label = Label.new()
	enemy_block_label.text = "🛡️ Block: 0"
	enemy_block_label.add_theme_font_size_override("font_size", FONT_BODY)
	enemy_block_label.add_theme_color_override("font_color", COLOR_TEXT_BODY)
	enemy_vbox.add_child(enemy_block_label)

	var intent_row = MarginContainer.new()
	intent_row.add_theme_constant_override("margin_top", SEP_INTENT_TOP)
	enemy_vbox.add_child(intent_row)

	enemy_intent_label = Label.new()
	enemy_intent_label.text = "NEXT: " + enemy.get_intent_text()
	enemy_intent_label.add_theme_font_size_override("font_size", FONT_INTENT)
	enemy_intent_label.add_theme_color_override("font_color", COLOR_TEXT_INTENT)
	enemy_intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_row.add_child(enemy_intent_label)

	var mid_spacer = Control.new()
	mid_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(mid_spacer)

	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", SEP_BOTTOM_ROW)
	bottom_row.alignment = BoxContainer.ALIGNMENT_END
	main.add_child(bottom_row)

	# ── PLAYER PANEL ────────────────────────
	var player_panel = PanelContainer.new()
	player_panel.custom_minimum_size = Vector2(220, 160)
	bottom_row.add_child(player_panel)

	var player_vbox = VBoxContainer.new()
	player_vbox.add_theme_constant_override("separation", SEP_PANEL_INNER)
	player_panel.add_child(player_vbox)

	var player_title = Label.new()
	player_title.text = "── PLAYER ──"
	player_title.add_theme_font_size_override("font_size", FONT_SECTION)
	player_title.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	player_vbox.add_child(player_title)

	player_hp_bar = _make_hp_bar(player.current_hp, player.max_hp)
	player_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_vbox.add_child(player_hp_bar)

	player_hp_label = Label.new()
	player_hp_label.text = str(player.current_hp) + " / " + str(player.max_hp)
	player_hp_label.add_theme_font_size_override("font_size", FONT_BODY)
	player_hp_label.add_theme_color_override("font_color", COLOR_TEXT_BODY)
	player_vbox.add_child(player_hp_label)

	player_block_label = Label.new()
	player_block_label.text = "🛡️ Block: " + str(player.effect_manager.get_stacks("Block"))
	player_block_label.add_theme_font_size_override("font_size", FONT_BODY)
	player_block_label.add_theme_color_override("font_color", COLOR_TEXT_BODY)
	player_vbox.add_child(player_block_label)

	player_ammo_label = Label.new()
	player_ammo_label.text = "🔵 Ammo: " + str(player.ammo) + " / " + str(player.max_ammo)
	player_ammo_label.add_theme_font_size_override("font_size", FONT_BODY)
	player_ammo_label.add_theme_color_override("font_color", Color(0.45, 0.82, 0.98))
	player_vbox.add_child(player_ammo_label)

	player_infection_label = Label.new()
	player_infection_label.text = "🧫 Infection: " + str(player.effect_manager.get_stacks("Infection"))
	player_infection_label.add_theme_font_size_override("font_size", FONT_BODY)
	player_infection_label.add_theme_color_override("font_color", Color(0.45, 0.92, 0.55))
	player_vbox.add_child(player_infection_label)

	# ── HAND CONTAINER ───────────────────────
	hand_container = HBoxContainer.new()
	hand_container.add_theme_constant_override("separation", SEP_HAND)
	hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_container.custom_minimum_size = Vector2(0, 180)
	bottom_row.add_child(hand_container)

	var actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", SEP_ACTIONS)
	bottom_row.add_child(actions)

	# ── END TURN BUTTON ──────────────────────
	end_turn_button = Button.new()
	end_turn_button.text = "END TURN"
	end_turn_button.custom_minimum_size = Vector2(130, 60)
	end_turn_button.add_theme_font_size_override("font_size", 18)
	end_turn_button.add_theme_color_override("font_color", COLOR_TEXT_HEADLINE)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	actions.add_child(end_turn_button)

	# ── MAP BUTTON ───────────────────────────
	var map_btn = Button.new()
	map_btn.text = "🗺️ Map"
	map_btn.custom_minimum_size = Vector2(130, 40)
	map_btn.add_theme_color_override("font_color", COLOR_TEXT_BODY)
	map_btn.pressed.connect(_on_map_pressed)
	actions.add_child(map_btn)

	rebuild_hand()

# ────────────────────────────────────────────
#  REBUILD HAND
# ────────────────────────────────────────────
func rebuild_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	card_buttons.clear()

	var player = combat_manager.player
	var size = _calc_hand_card_size(player.hand.size())
	for i in range(player.hand.size()):
		var card = player.hand[i]
		var btn = Button.new()
		var desc := _truncate_card_description(card.description)
		btn.text = card.card_name + "\nCost: " + str(card.cost) + "\n" + desc
		btn.size = size
		btn.custom_minimum_size = size
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", FONT_HAND_CARD)
		btn.add_theme_color_override("font_color", COLOR_TEXT_HEADLINE)
		_apply_hand_card_style(btn)
		if player.ammo < card.cost:
			btn.modulate = Color(0.5, 0.5, 0.5)
			btn.disabled = true
		else:
			btn.modulate = Color(1, 1, 1)
			btn.disabled = false
		var idx = i
		btn.pressed.connect(_on_card_pressed.bind(idx))
		hand_container.add_child(btn)
		card_buttons.append(btn)

# ────────────────────────────────────────────
#  CARD REWARD SCREEN
# ────────────────────────────────────────────
func show_reward_screen() -> void:
	end_turn_button.disabled = true
	for btn in card_buttons:
		btn.disabled = true

	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	root.add_child(margin)

	var layout = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var title = Label.new()
	title.text = "⚔️ VICTORY! Choose a Card Reward:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
	layout.add_child(title)

	var all_cards = CardLibrary.get_all_cards()
	all_cards.shuffle()
	var rewards : Array = []
	for i in range(min(3, all_cards.size())):
		rewards.append(all_cards[i])

	var center = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	center.add_child(row)

	for i in range(rewards.size()):
		var card = rewards[i]
		var card_panel = PanelContainer.new()
		card_panel.custom_minimum_size = Vector2(220, 310)
		row.add_child(card_panel)

		var vbox = VBoxContainer.new()
		card_panel.add_child(vbox)

		var name_label = Label.new()
		name_label.text = card.card_name
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		vbox.add_child(name_label)

		var type_label = Label.new()
		type_label.text = "[" + card.card_type.to_upper() + "]"
		type_label.add_theme_font_size_override("font_size", 13)
		type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(type_label)

		var cost_label = Label.new()
		cost_label.text = "🔵 Cost: " + str(card.cost)
		cost_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(cost_label)

		var desc_label = Label.new()
		desc_label.text = card.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(180, 80)
		vbox.add_child(desc_label)

		var pick_btn = Button.new()
		pick_btn.text = "✅ Add to Deck"
		pick_btn.custom_minimum_size = Vector2(180, 40)
		pick_btn.pressed.connect(_on_reward_picked.bind(card))
		vbox.add_child(pick_btn)

	var footer = HBoxContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(footer)

	var skip_btn = Button.new()
	skip_btn.text = "Skip Reward →"
	skip_btn.custom_minimum_size = Vector2(220, 50)
	skip_btn.add_theme_font_size_override("font_size", 16)
	skip_btn.pressed.connect(_on_reward_skipped)
	footer.add_child(skip_btn)

func _on_reward_picked(card: CardData) -> void:
	GameManager.add_card_to_deck(card)
	_finish_combat()

func _on_reward_skipped() -> void:
	_finish_combat()

func _finish_combat() -> void:
	GameManager.complete_room(GameManager.current_node_id)

# ────────────────────────────────────────────
#  GAME OVER SCREEN
# ────────────────────────────────────────────
func show_result(won: bool) -> void:
	end_turn_button.disabled = true
	for btn in card_buttons:
		btn.disabled = true

	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	var result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 64)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if won:
		result_label.text = "⚔️ YOU WIN! ⚔️"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
	else:
		result_label.text = "💀 GAME OVER 💀"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	box.add_child(result_label)

	var restart_btn = Button.new()
	restart_btn.text = "🔄 New Run"
	restart_btn.custom_minimum_size = Vector2(220, 60)
	restart_btn.add_theme_font_size_override("font_size", 20)
	restart_btn.pressed.connect(_on_restart_pressed)
	box.add_child(restart_btn)

func _on_restart_pressed() -> void:
	GameManager.start_new_run()
	get_tree().change_scene_to_file(GameManager.SCENE_MAP)

# ────────────────────────────────────────────
#  BUTTON CALLBACKS
# ────────────────────────────────────────────
func _on_card_pressed(index: int) -> void:
	combat_manager.play_card(index)
	rebuild_hand()

func _on_end_turn_pressed() -> void:
	end_turn_button.disabled = true
	combat_manager.end_player_turn()
	rebuild_hand()
	# Button is re-enabled by start_player_turn() instead
	# so the player can't spam End Turn mid-enemy-turn

func _on_map_pressed() -> void:
	get_tree().change_scene_to_file(GameManager.SCENE_MAP)

func update_ui() -> void:
	rebuild_hand()

func _play_evolution_fx(new_name: String) -> void:
	if evolution_flash_overlay == null:
		return

	# Mutation flash palette (distinct from damage red language).
	evolution_flash_overlay.color = MUTATION_FLASH_COLOR
	evolution_flash_overlay.color.a = 0.0

	# First pulse starts immediately.
	var flash_tween = create_tween()
	flash_tween.tween_property(evolution_flash_overlay, "color:a", 0.50, 0.04)

	# Brief impact pause; update name mid-flash.
	await get_tree().create_timer(0.05).timeout
	enemy_name_label.text = new_name
	await get_tree().create_timer(0.05).timeout

	# "Glitch" strobe: quick double pulse then fade.
	flash_tween.tween_property(evolution_flash_overlay, "color:a", 0.08, 0.03)
	flash_tween.tween_property(evolution_flash_overlay, "color:a", 0.42, 0.03)
	flash_tween.tween_property(evolution_flash_overlay, "color:a", 0.0, 0.12)

	var base_pos = position
	var shake_tween = create_tween()
	shake_tween.set_parallel(false)
	for i in range(6):
		var offset = Vector2(
			rng.randf_range(-9.0, 9.0),
			rng.randf_range(-5.0, 5.0)
		)
		shake_tween.tween_property(self, "position", base_pos + offset, 0.03)
	shake_tween.tween_property(self, "position", base_pos, 0.05)

func _on_viewport_resized() -> void:
	if is_inside_tree():
		rebuild_hand()
