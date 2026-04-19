extends Control

# ────────────────────────────────────────────
#  COMBAT UI
# ────────────────────────────────────────────

var combat_manager

var enemy_name_label       : Label
var enemy_hp_label         : Label
var enemy_block_label      : Label
var enemy_intent_label     : Label
var player_hp_label        : Label
var player_block_label     : Label
var player_ammo_label      : Label
var player_infection_label : Label
var hand_container         : HBoxContainer
var end_turn_button        : Button
var card_buttons           : Array = []

# ────────────────────────────────────────────
func _ready() -> void:
	combat_manager = get_parent().get_parent()

func setup() -> void:
	build_ui()
	connect_signals()

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

func _on_player_hp_changed(current_hp: int, max_hp: int) -> void:
	player_hp_label.text = "❤️ HP: " + str(current_hp) + " / " + str(max_hp)

func _on_player_block_changed(current_block: int) -> void:
	player_block_label.text = "🛡️ Block: " + str(current_block)

func _on_player_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	player_ammo_label.text = "🔵 Ammo: " + str(current_ammo) + " / " + str(max_ammo)
	rebuild_hand()

func _on_player_infection_changed(current_infection: int) -> void:
	player_infection_label.text = "🧫 Infection: " + str(current_infection)

func _on_enemy_hp_changed(current_hp: int, max_hp: int) -> void:
	enemy_hp_label.text = "HP: " + str(current_hp) + " / " + str(max_hp)

func _on_enemy_block_changed(current_block: int) -> void:
	enemy_block_label.text = "🛡️ Block: " + str(current_block)

func _on_enemy_intent_changed(intent_text: String) -> void:
	enemy_intent_label.text = "Intent: " + intent_text

# ────────────────────────────────────────────
#  BUILD UI
# ────────────────────────────────────────────
func build_ui() -> void:
	var player = combat_manager.player
	var enemy  = combat_manager.enemy

	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── ENEMY PANEL ─────────────────────────
	var enemy_panel = PanelContainer.new()
	enemy_panel.position = Vector2(300, 40)
	enemy_panel.size = Vector2(400, 150)
	add_child(enemy_panel)

	var enemy_vbox = VBoxContainer.new()
	enemy_panel.add_child(enemy_vbox)

	enemy_name_label = Label.new()
	enemy_name_label.text = enemy.enemy_name
	enemy_name_label.add_theme_font_size_override("font_size", 20)
	enemy_vbox.add_child(enemy_name_label)

	enemy_hp_label = Label.new()
	enemy_hp_label.text = "HP: " + str(enemy.current_hp) + " / " + str(enemy.max_hp)
	enemy_vbox.add_child(enemy_hp_label)

	enemy_block_label = Label.new()
	enemy_block_label.text = "🛡️ Block: 0"
	enemy_vbox.add_child(enemy_block_label)

	enemy_intent_label = Label.new()
	enemy_intent_label.text = "Intent: " + enemy.get_intent_text()
	enemy_intent_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	enemy_vbox.add_child(enemy_intent_label)

	# ── PLAYER PANEL ────────────────────────
	var player_panel = PanelContainer.new()
	player_panel.position = Vector2(20, 450)
	player_panel.size = Vector2(220, 160)
	add_child(player_panel)

	var player_vbox = VBoxContainer.new()
	player_panel.add_child(player_vbox)

	var player_title = Label.new()
	player_title.text = "── PLAYER ──"
	player_title.add_theme_font_size_override("font_size", 16)
	player_vbox.add_child(player_title)

	player_hp_label = Label.new()
	player_hp_label.text = "❤️ HP: " + str(player.current_hp) + " / " + str(player.max_hp)
	player_vbox.add_child(player_hp_label)

	player_block_label = Label.new()
	player_block_label.text = "🛡️ Block: " + str(player.effect_manager.get_stacks("Block"))
	player_vbox.add_child(player_block_label)

	player_ammo_label = Label.new()
	player_ammo_label.text = "🔵 Ammo: " + str(player.ammo) + " / " + str(player.max_ammo)
	player_ammo_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	player_vbox.add_child(player_ammo_label)

	player_infection_label = Label.new()
	player_infection_label.text = "🧫 Infection: " + str(player.effect_manager.get_stacks("Infection"))
	player_infection_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	player_vbox.add_child(player_infection_label)

	# ── HAND CONTAINER ───────────────────────
	hand_container = HBoxContainer.new()
	hand_container.position = Vector2(250, 440)
	hand_container.size = Vector2(600, 180)
	hand_container.add_theme_constant_override("separation", 10)
	add_child(hand_container)

	# ── END TURN BUTTON ──────────────────────
	end_turn_button = Button.new()
	end_turn_button.text = "END TURN"
	end_turn_button.position = Vector2(870, 500)
	end_turn_button.size = Vector2(130, 60)
	end_turn_button.add_theme_font_size_override("font_size", 18)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	add_child(end_turn_button)

	# ── TITLE ────────────────────────────────
	var title = Label.new()
	title.text = "⚔️ COMBAT"
	title.position = Vector2(20, 20)
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)

	# ── MAP BUTTON ───────────────────────────
	var map_btn = Button.new()
	map_btn.text = "🗺️ Map"
	map_btn.position = Vector2(20, 400)
	map_btn.size = Vector2(80, 36)
	map_btn.pressed.connect(_on_map_pressed)
	add_child(map_btn)

	rebuild_hand()

# ────────────────────────────────────────────
#  REBUILD HAND
# ────────────────────────────────────────────
func rebuild_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	card_buttons.clear()

	var player = combat_manager.player
	for i in range(player.hand.size()):
		var card = player.hand[i]
		var btn = Button.new()
		btn.text = card.card_name + "\nCost: " + str(card.cost) + "\n" + card.description
		btn.size = Vector2(110, 160)
		btn.custom_minimum_size = Vector2(110, 160)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var title = Label.new()
	title.text = "⚔️ VICTORY! Choose a Card Reward:"
	title.position = Vector2(280, 140)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
	add_child(title)

	var all_cards = CardLibrary.get_all_cards()
	all_cards.shuffle()
	var rewards : Array = []
	for i in range(min(3, all_cards.size())):
		rewards.append(all_cards[i])

	var positions = [Vector2(180, 220), Vector2(420, 220), Vector2(660, 220)]

	for i in range(rewards.size()):
		var card = rewards[i]
		var card_panel = PanelContainer.new()
		card_panel.position = positions[i]
		card_panel.size = Vector2(200, 300)
		add_child(card_panel)

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

	var skip_btn = Button.new()
	skip_btn.text = "Skip Reward →"
	skip_btn.position = Vector2(480, 560)
	skip_btn.size = Vector2(200, 50)
	skip_btn.add_theme_font_size_override("font_size", 16)
	skip_btn.pressed.connect(_on_reward_skipped)
	add_child(skip_btn)

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

	var result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 64)
	result_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	if won:
		result_label.text = "⚔️ YOU WIN! ⚔️"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
	else:
		result_label.text = "💀 GAME OVER 💀"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	add_child(result_label)

	var restart_btn = Button.new()
	restart_btn.text = "🔄 New Run"
	restart_btn.position = Vector2(476, 420)
	restart_btn.size = Vector2(200, 60)
	restart_btn.add_theme_font_size_override("font_size", 20)
	restart_btn.pressed.connect(_on_restart_pressed)
	add_child(restart_btn)

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
	end_turn_button.disabled = false

func _on_map_pressed() -> void:
	get_tree().change_scene_to_file(GameManager.SCENE_MAP)

func update_ui() -> void:
	rebuild_hand()
