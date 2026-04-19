extends Control

# ────────────────────────────────────────────
#  SAFE ROOM UI
#  Shows 3 option buttons at start
#  Then shows deck picker for remove/upgrade
#  Then shows result screen before leaving
# ────────────────────────────────────────────

var safe_room  # Reference to SafeRoom node

# ────────────────────────────────────────────
#  SETUP
# ────────────────────────────────────────────
func setup(safe_room_node) -> void:
	safe_room = safe_room_node
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	show_main_options()

# ────────────────────────────────────────────
#  CLEAR UI
# ────────────────────────────────────────────
func clear() -> void:
	for child in get_children():
		child.queue_free()

# ────────────────────────────────────────────
#  SHOW MAIN OPTIONS
#  The 3 choice buttons
# ────────────────────────────────────────────
func show_main_options() -> void:
	clear()

	# Background
	var bg       = ColorRect.new()
	bg.color     = Color(0.08, 0.12, 0.1, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title    = Label.new()
	title.text   = "🏥 SAFE ROOM"
	title.position = Vector2(400, 60)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override(
		"font_color", Color(0.4, 1.0, 0.6))
	add_child(title)

	# Subtitle
	var sub      = Label.new()
	sub.text     = "Choose one option:"
	sub.position = Vector2(430, 120)
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override(
		"font_color", Color(0.8, 0.8, 0.8))
	add_child(sub)

	# Player stats display
	var stats    = Label.new()
	stats.text   = "❤️ HP: " + str(GameManager.player_current_hp) + \
		" / " + str(GameManager.player_max_hp) + \
		"     🃏 Deck: " + str(GameManager.player_deck.size()) + " cards"
	stats.position = Vector2(340, 158)
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_color_override(
		"font_color", Color(0.9, 0.9, 0.9))
	add_child(stats)

	# ── OPTION 1: HEAL ───────────────────────
	var heal_panel   = _make_option_panel(
		Vector2(100, 220),
		"🏥 REST & HEAL",
		"Restore " + str(safe_room.HEAL_AMOUNT) + " HP.\n\n" +
		"Current HP: " + str(GameManager.player_current_hp) +
		" / " + str(GameManager.player_max_hp),
		Color(0.2, 0.6, 0.3)
	)
	var heal_btn     = _make_confirm_button("Rest")
	heal_btn.pressed.connect(_on_heal_pressed)
	heal_panel.get_child(0).add_child(heal_btn)
	add_child(heal_panel)

	# ── OPTION 2: REMOVE CARD ────────────────
	var remove_panel = _make_option_panel(
		Vector2(410, 220),
		"🗑️ REMOVE CARD",
		"Remove one card\nfrom your deck.\n\n" +
		"Deck: " + str(GameManager.player_deck.size()) + " cards",
		Color(0.7, 0.3, 0.2)
	)
	var remove_btn   = _make_confirm_button("Remove")
	# Only allow if deck has more than 5 cards
	if GameManager.player_deck.size() <= 5:
		remove_btn.disabled = true
		remove_btn.text     = "Need 6+ cards"
	remove_btn.pressed.connect(_on_remove_pressed)
	remove_panel.get_child(0).add_child(remove_btn)
	add_child(remove_panel)

	# ── OPTION 3: UPGRADE CARD ───────────────
	var upgrade_panel = _make_option_panel(
		Vector2(720, 220),
		"⬆️ UPGRADE CARD",
		"Upgrade one card\nto a stronger version.\n\n" +
		"Adds + to name,\nimproves stats.",
		Color(0.3, 0.4, 0.8)
	)
	var upgrade_btn  = _make_confirm_button("Upgrade")
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	upgrade_panel.get_child(0).add_child(upgrade_btn)
	add_child(upgrade_panel)

	# ── LEAVE BUTTON ─────────────────────────
	var leave_btn    = Button.new()
	leave_btn.text   = "Leave Without Resting →"
	leave_btn.position = Vector2(420, 600)
	leave_btn.size   = Vector2(300, 44)
	leave_btn.add_theme_font_size_override("font_size", 16)
	leave_btn.add_theme_color_override(
		"font_color", Color(0.6, 0.6, 0.6))
	leave_btn.pressed.connect(_on_leave_pressed)
	add_child(leave_btn)

# ────────────────────────────────────────────
#  MAKE OPTION PANEL HELPER
# ────────────────────────────────────────────
func _make_option_panel(
		pos: Vector2,
		title: String,
		body: String,
		color: Color) -> PanelContainer:

	var panel        = PanelContainer.new()
	panel.position   = pos
	panel.size       = Vector2(280, 340)

	var vbox         = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title_label  = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var sep          = HSeparator.new()
	vbox.add_child(sep)

	var body_label   = Label.new()
	body_label.text  = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(240, 80)
	body_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(body_label)

	return panel

func _make_confirm_button(label: String) -> Button:
	var btn          = Button.new()
	btn.text         = "✅ " + label
	btn.custom_minimum_size = Vector2(240, 44)
	btn.add_theme_font_size_override("font_size", 17)
	return btn

# ────────────────────────────────────────────
#  SHOW DECK PICKER
#  Displays all cards in deck as buttons
#  action = "remove" or "upgrade"
# ────────────────────────────────────────────
func show_deck_picker(title_text: String,
		action: String) -> void:
	clear()

	# Background
	var bg       = ColorRect.new()
	bg.color     = Color(0.08, 0.08, 0.12, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title    = Label.new()
	title.text   = title_text
	title.position = Vector2(200, 30)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override(
		"font_color", Color(1.0, 0.9, 0.2))
	add_child(title)

	# Scroll container for cards
	var scroll   = ScrollContainer.new()
	scroll.position = Vector2(20, 80)
	scroll.size  = Vector2(1110, 540)
	add_child(scroll)

	var hbox     = HFlowContainer.new()
	hbox.custom_minimum_size = Vector2(1100, 0)
	hbox.add_theme_constant_override("h_separation", 10)
	hbox.add_theme_constant_override("v_separation", 10)
	scroll.add_child(hbox)

	# One button per card in deck
	for card in GameManager.player_deck:
		var btn  = Button.new()
		btn.text = card.card_name + \
			("\n⬆️ UPGRADEABLE" if not card.card_name.ends_with("+")
			else "\n✅ MAX") + \
			"\nCost: " + str(card.cost) + \
			"\n" + card.description
		btn.custom_minimum_size = Vector2(160, 160)
		btn.size = Vector2(160, 160)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 13)

		# Disable already upgraded cards for upgrade action
		if action == "upgrade" and card.card_name.ends_with("+"):
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)

		var chosen_card = card
		var chosen_action = action
		btn.pressed.connect(
			func(): _on_deck_card_picked(
				chosen_card, chosen_action))
		hbox.add_child(btn)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "← Back"
	back_btn.position = Vector2(20, 630)
	back_btn.size = Vector2(120, 40)
	back_btn.pressed.connect(show_main_options)
	add_child(back_btn)

# ────────────────────────────────────────────
#  SHOW DONE SCREEN
#  Shown after choosing an option
# ────────────────────────────────────────────
func show_done_screen(message: String) -> void:
	clear()

	var bg       = ColorRect.new()
	bg.color     = Color(0.08, 0.12, 0.1, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var msg      = Label.new()
	msg.text     = message
	msg.position = Vector2(340, 220)
	msg.add_theme_font_size_override("font_size", 28)
	msg.add_theme_color_override(
		"font_color", Color(0.4, 1.0, 0.6))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(500, 200)
	add_child(msg)

	# Updated stats
	var stats    = Label.new()
	stats.text   = "❤️ HP: " + \
		str(GameManager.player_current_hp) + \
		" / " + str(GameManager.player_max_hp) + \
		"     🃏 Deck: " + \
		str(GameManager.player_deck.size()) + " cards"
	stats.position = Vector2(340, 420)
	stats.add_theme_font_size_override("font_size", 18)
	add_child(stats)

	var leave_btn = Button.new()
	leave_btn.text = "Continue →"
	leave_btn.position = Vector2(440, 500)
	leave_btn.size = Vector2(260, 60)
	leave_btn.add_theme_font_size_override("font_size", 22)
	leave_btn.add_theme_color_override(
		"font_color", Color(0.4, 1.0, 0.6))
	leave_btn.pressed.connect(_on_leave_pressed)
	add_child(leave_btn)

# ────────────────────────────────────────────
#  CALLBACKS
# ────────────────────────────────────────────
func _on_heal_pressed() -> void:
	safe_room.choose_heal()

func _on_remove_pressed() -> void:
	safe_room.choose_remove()

func _on_upgrade_pressed() -> void:
	safe_room.choose_upgrade()

func _on_deck_card_picked(
		card: CardData, action: String) -> void:
	if action == "remove":
		safe_room.confirm_remove(card)
	elif action == "upgrade":
		safe_room.confirm_upgrade(card)

func _on_leave_pressed() -> void:
	safe_room.leave()
