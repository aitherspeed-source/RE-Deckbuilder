extends Node2D

# ────────────────────────────────────────────
#  EVENT ROOM
#  Picks a random event each visit.
#  Every choice has a real consequence.
#  Some choices set flags that echo forward
#  into future rooms on the same run.
# ────────────────────────────────────────────

var title_label   : Label
var flavour_label : Label
var result_label  : Label
var result_panel  : PanelContainer
var btn_a         : Button
var btn_b         : Button
var continue_btn  : Button
var content_vbox  : VBoxContainer
var separator_line: ColorRect
var continue_anchor: MarginContainer
var header_box: VBoxContainer
var ui_layer: CanvasLayer
var ui_root: Control

const EVENT_MARGIN := 28.0
const EVENT_MIN_CONTENT_W := 400.0
const EVENT_MAX_CONTENT_W := 1000.0

var events : Array = [
	{
		"id":       "supply_cache",
		"title":    "🧪 Infected Supply Cache",
		"flavour":  "An Umbra crate sits open in the corridor. Two compartments — one holds weapons, one holds medical supplies. Something has already been at it.",
		"option_a": "⚔️  Grab the weapons  [Take 6 damage, gain 2 cards]",
		"option_b": "💉  Grab the meds  [Heal 12 HP, gain 2 Infection]"
	},
	{
		"id":       "field_medic",
		"title":    "💉 Field Medic",
		"flavour":  "A wounded soldier slumped against the wall offers to patch you up. His hands are steady but his eyes keep drifting to your gear. He wants something in return.",
		"option_a": "🤝  Accept the offer  [Heal 20 HP, lose a random card]",
		"option_b": "💪  Take his supplies by force  [Gain 1 card, take 10 damage]"
	},
	{
		"id":       "abandoned_lab",
		"title":    "🔬 Abandoned Lab",
		"flavour":  "Research equipment still humming. Centrifuges spinning. Whoever worked here left mid-experiment. Two terminals are still active.",
		"option_a": "🔧  Use the equipment  [Upgrade a random card in your deck]",
		"option_b": "🎒  Grab the supplies  [Add a random card to your deck]"
	},
	{
		"id":       "umbra_broadcast",
		"title":    "📡 Umbra Broadcast",
		"flavour":  "A screen flickers to life. A calm corporate voice: 'Subject performing within acceptable parameters. Administering motivational reward.' You don't know if it's a trick.",
		"option_a": "✅  Accept the reward  [Heal 15 HP, gain 3 Infection]",
		"option_b": "📡  Override the signal  [Gain 2 random cards, gain 2 Infection]"
	},
	{
		"id":       "crawling_survivor",
		"title":    "🧟 Crawling Survivor",
		"flavour":  "They're infected. They know it. They've pushed their last card and weapon across the floor toward you. They ask you to end it. Their eyes are still human.",
		"option_a": "🤲  Help them  [Gain 1 card, take 4 damage]",
		"option_b": "🚶  Walk past  [Gain 2 Infection]"
	},
	{
		"id":       "security_door",
		"title":    "🚪 Locked Security Door",
		"flavour":  "A keypad blocks a side corridor. The code is scratched into the wall right next to it. Either Umbra wanted you in, or someone got desperate.",
		"option_a": "🔑  Enter the code  [50/50: Heal 15 HP OR gain 3 Infection]",
		"option_b": "🪓  Find another way  [Gain 1 card, take 5 damage]"
	},
	{
		"id":       "mutation_chamber",
		"title":    "🩸 Mutation Chamber",
		"flavour":  "Umbra's signature containment tank. Something suspended inside turns toward you. Two valves on the control panel — one releases it, one floods the room.",
		"option_a": "🔓  Release the specimen  [Gain 5 Infection, gain a rare card]",
		"option_b": "💧  Flood the chamber  [Take 10 damage, remove a card from deck]"
	},
	{
		"id":       "emergency_meds",
		"title":    "💊 Emergency Meds",
		"flavour":  "An overturned medkit. Three syringes. Two are clearly standard-issue field stims. The third has a handwritten label: 'DO NOT'. You're badly hurt.",
		"option_a": "✅  Take the safe ones  [Heal 20 HP]",
		"option_b": "⚠️  Take all three  [Heal 30 HP, gain 2 Infection]"
	}
]

var current_event : Dictionary = {}
var result_text   : String     = ""
var _auto_continue_started: bool = false

func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_pick_event()

func _pick_event() -> void:
	var seen      : Array = GameManager.events_seen_this_run
	var available : Array = []
	for event in events:
		if not seen.has(event["id"]):
			available.append(event)
	if available.is_empty():
		GameManager.events_seen_this_run.clear()
		available = events.duplicate()
	available.shuffle()
	current_event = available[0]
	GameManager.events_seen_this_run.append(current_event["id"])
	title_label.text   = current_event["title"]
	flavour_label.text = current_event["flavour"]
	btn_a.text         = current_event["option_a"]
	btn_b.text         = current_event["option_b"]
	if GameManager.signal_jammed:
		btn_a.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		var hint = Label.new()
		hint.text = "📡 Umbra signal jammed — their countermeasures are offline for this room."
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Insert hint between divider and flavour (index 3) in the procedural VBox.
		if content_vbox != null:
			content_vbox.add_child(hint)
			content_vbox.move_child(hint, 3)
		GameManager.signal_jammed = false

func _on_choice_a() -> void:
	btn_a.disabled = true
	btn_b.disabled = true
	match current_event["id"]:
		"supply_cache":
			GameManager.damage_player(6)
			_add_random_cards(2)
			GameManager.weapons_stolen = true
			result_text = "You grab the weapons and take a hit doing it. [+2 cards, -6 HP]\n⚠️ Umbra security has been notified of the theft."
		"field_medic":
			GameManager.heal_player(20)
			_pickpocket_random_card()
			result_text = "He patches you up well. You don't notice the missing card until he's gone. [+20 HP, -1 random card]"
		"abandoned_lab":
			_upgrade_random_card()
			result_text = "The equipment hums as it processes your card. It comes out sharper. [Random card upgraded ✨]"
		"umbra_broadcast":
			GameManager.heal_player(15)
			GameManager.player_infection += 3
			result_text = "A warm sensation floods your body. Whether medicine or something else — you feel better. [+15 HP, +3 Infection]"
		"crawling_survivor":
			_add_random_cards(1)
			GameManager.damage_player(4)
			GameManager.survivor_helped = true
			result_text = "You do what needs doing. They press a card into your hand at the end. [+1 card, -4 HP]\n💀 You won't forget this."
		"security_door":
			if randi() % 2 == 0:
				GameManager.heal_player(15)
				result_text = "The door slides open. A small supply room. Clean air. A moment of safety. [+15 HP] ✅"
			else:
				GameManager.player_infection += 3
				result_text = "Alarms. Gas vents. Something biological floods the corridor. You run. [+3 Infection] ❌"
		"mutation_chamber":
			GameManager.player_infection += 5
			_add_infection_rare_card()
			GameManager.specimen_released = true
			result_text = "The tank drains. Something slips into the darkness. You feel it in your blood too. [+5 Infection, +rare card]\n⚠️ The specimen is loose somewhere in the facility."
		"emergency_meds":
			GameManager.heal_player(20)
			result_text = "Standard stims. Clean. Effective. You feel human again. [+20 HP]"
	_show_result()

func _on_choice_b() -> void:
	btn_a.disabled = true
	btn_b.disabled = true
	match current_event["id"]:
		"supply_cache":
			GameManager.heal_player(12)
			GameManager.player_infection += 2
			GameManager.contaminated_meds = true
			result_text = "The meds work fast. Too fast. Something else was in them. [+12 HP, +2 Infection]\n⚠️ You'll feel the contamination next combat."
		"field_medic":
			_add_random_cards(1)
			GameManager.damage_player(10)
			result_text = "He puts up more of a fight than expected. Worth it. [+1 card, -10 HP]"
		"abandoned_lab":
			_add_random_cards(1)
			result_text = "You sweep the shelves. Something useful in the pile. [+1 random card]"
		"umbra_broadcast":
			_add_random_cards(2)
			GameManager.player_infection += 2
			GameManager.signal_jammed = true
			result_text = "Static. Then silence. The supply hatch pops open anyway — they got data from the interaction. [+2 cards, +2 Infection]\n📡 Their next signal is jammed."
		"crawling_survivor":
			GameManager.player_infection += 2
			GameManager.survivor_abandoned = true
			result_text = "You step around them and keep moving. Something follows you down the corridor. [+2 Infection]\n⚠️ They're still back there. For now."
		"security_door":
			_add_random_cards(1)
			GameManager.damage_player(5)
			result_text = "A vent shaft. Tight and sharp inside. You make it through with new supplies and fresh cuts. [+1 card, -5 HP]"
		"mutation_chamber":
			GameManager.damage_player(10)
			_remove_random_card()
			result_text = "The suppressant floods the room. You're soaked. Something gets stripped away in the wash. [-10 HP, -1 card]"
		"emergency_meds":
			GameManager.heal_player(30)
			GameManager.player_infection += 2
			result_text = "All three hit at once. The world goes white then sharp. The third was definitely not standard. [+30 HP, +2 Infection]"
	_show_result()

func _add_random_cards(count: int) -> void:
	var all_cards = CardLibrary.get_all_cards()
	all_cards.shuffle()
	for i in range(min(count, all_cards.size())):
		GameManager.add_card_to_deck(all_cards[i].duplicate())
		print("Event gave card: ", all_cards[i].card_name)

func _add_infection_rare_card() -> void:
	var all_cards  = CardLibrary.get_all_cards()
	var rare_names = ["Infected Rage", "Biohazard Round", "Fortify"]
	for card in all_cards:
		if rare_names.has(card.card_name):
			GameManager.add_card_to_deck(card.duplicate())
			print("Event gave rare card: ", card.card_name)
			return
	_add_random_cards(1)

func _upgrade_random_card() -> void:
	if GameManager.player_deck.is_empty():
		return
	var deck = GameManager.player_deck.duplicate()
	deck.shuffle()
	for card in deck:
		if "+" not in card.card_name:
			card.card_name  = card.card_name + " +"
			card.cost       = max(0, card.cost - 1)
			card.value += 3
			print("Upgraded: ", card.card_name)
			return
	print("All cards already upgraded.")

func _remove_random_card() -> void:
	if GameManager.player_deck.size() <= 1:
		result_text += "\n(Deck too small to remove a card.)"
		return
	var deck = GameManager.player_deck.duplicate()
	deck.shuffle()
	GameManager.remove_card_from_deck(deck[0])
	print("Event removed: ", deck[0].card_name)

func _pickpocket_random_card() -> void:
	if GameManager.player_deck.size() <= 1:
		return
	var deck = GameManager.player_deck.duplicate()
	deck.shuffle()
	GameManager.remove_card_from_deck(deck[0])
	print("Pickpocketed: ", deck[0].card_name)

func _show_result() -> void:
	btn_a.hide()
	btn_b.hide()
	result_label.text = result_text
	result_label.show()
	result_panel.show()
	if continue_btn != null:
		continue_btn.hide()

	if _auto_continue_started:
		return
	_auto_continue_started = true
	_auto_return_to_map_after_delay()

func _auto_return_to_map_after_delay() -> void:
	var t = get_tree().create_timer(3.0)
	t.timeout.connect(_on_continue_pressed)

func _on_continue_pressed() -> void:
	GameManager.complete_room(GameManager.current_node_id)

func _style_event_choice_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.02, 0.02, 0.8)
	normal.border_color = Color(0.45, 0.15, 0.15, 1.0)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.04, 0.04, 0.85)
	hover.border_color = Color(0.82, 0.22, 0.22, 1.0)
	hover.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.02, 0.02, 0.9)
	btn.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.08, 0.02, 0.02, 0.55)
	disabled.border_color = Color(0.24, 0.10, 0.10, 0.8)
	btn.add_theme_stylebox_override("disabled", disabled)
	var focus_sb := normal.duplicate() as StyleBoxFlat
	btn.add_theme_stylebox_override("focus", focus_sb)

func _build_ui() -> void:
	# Remove placeholder nodes from EventRoom.tscn so only the procedural UI remains.
	for child in get_children():
		child.free()

	var vp := get_viewport().get_visible_rect().size
	var content_w: float = clampf(vp.x * 0.60, EVENT_MIN_CONTENT_W, EVENT_MAX_CONTENT_W)

	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)

	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.05, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(bg)

	var bioscan = ColorRect.new()
	bioscan.color = Color(0.18, 0.08, 0.24, 0.05)
	bioscan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bioscan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(bioscan)

	content_vbox = VBoxContainer.new()
	content_vbox.name = "VBox"
	content_vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	content_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	content_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content_vbox.custom_minimum_size = Vector2(content_w, 0)
	content_vbox.add_theme_constant_override("separation", 16)
	ui_root.add_child(content_vbox)

	# Keep child order compatible with _pick_event() move_child(hint, 3):
	# [0 header_center, 1 divider, 2 spacer, 3 flavour, ...]
	var header_center = CenterContainer.new()
	content_vbox.add_child(header_center)

	header_box = VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 4)
	header_center.add_child(header_box)

	var tag = Label.new()
	tag.text = "❓  E V E N T"
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(tag)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(title_label)

	var div = Label.new()
	div.text = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	div.add_theme_color_override("font_color", Color(0.3, 0.2, 0.2))
	div.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(div)

	var flavour_spacer = Control.new()
	flavour_spacer.custom_minimum_size = Vector2(0, 6)
	content_vbox.add_child(flavour_spacer)

	flavour_label = Label.new()
	flavour_label.add_theme_font_size_override("font_size", 16)
	flavour_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	flavour_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavour_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavour_label.custom_minimum_size = Vector2(content_w, 0)
	flavour_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(flavour_label)

	var sep_spacer = Control.new()
	sep_spacer.custom_minimum_size = Vector2(0, 10)
	content_vbox.add_child(sep_spacer)

	separator_line = ColorRect.new()
	separator_line.color = Color(0.3, 0.2, 0.2, 1.0)
	separator_line.custom_minimum_size = Vector2(content_w, 2)
	separator_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content_vbox.add_child(separator_line)

	var gap_before_choices = Control.new()
	gap_before_choices.custom_minimum_size = Vector2(0, 12)
	content_vbox.add_child(gap_before_choices)

	btn_a = Button.new()
	_style_event_choice_button(btn_a)
	btn_a.add_theme_font_size_override("font_size", 15)
	btn_a.custom_minimum_size = Vector2(content_w, 64)
	btn_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_a.clip_text = false
	btn_a.pressed.connect(_on_choice_a)
	content_vbox.add_child(btn_a)

	btn_b = Button.new()
	_style_event_choice_button(btn_b)
	btn_b.add_theme_font_size_override("font_size", 15)
	btn_b.custom_minimum_size = Vector2(content_w, 64)
	btn_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_b.clip_text = false
	btn_b.pressed.connect(_on_choice_b)
	content_vbox.add_child(btn_b)

	result_panel = PanelContainer.new()
	var result_sb = StyleBoxFlat.new()
	result_sb.bg_color = Color(0.05, 0.08, 0.06, 1.0)
	result_sb.border_color = Color(0.25, 0.55, 0.35, 1.0)
	result_sb.set_border_width_all(2)
	result_sb.set_content_margin_all(14)
	result_panel.add_theme_stylebox_override("panel", result_sb)
	result_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_panel.hide()

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 16)
	result_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.custom_minimum_size = Vector2(content_w - 28, 0)
	result_label.hide()
	result_panel.add_child(result_label)
	content_vbox.add_child(result_panel)

	var bottom_spacer = Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_spacer.custom_minimum_size = Vector2(0, 8)
	content_vbox.add_child(bottom_spacer)

	# Continue button pinned to bottom-right (direct child of root).
	continue_anchor = MarginContainer.new()
	continue_anchor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	continue_anchor.add_theme_constant_override("margin_right", 40)
	continue_anchor.add_theme_constant_override("margin_bottom", 40)
	continue_anchor.mouse_filter = Control.MOUSE_FILTER_PASS
	ui_root.add_child(continue_anchor)

	continue_btn = Button.new()
	continue_btn.text = "Continue →"
	continue_btn.add_theme_font_size_override("font_size", 18)
	continue_btn.custom_minimum_size = Vector2(220, 50)
	continue_btn.hide()
	continue_btn.pressed.connect(_on_continue_pressed)
	continue_anchor.add_child(continue_btn)

func _on_viewport_resized() -> void:
	_reflow_layout_for_viewport()

func _reflow_layout_for_viewport() -> void:
	if flavour_label == null or btn_a == null or btn_b == null or result_label == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var content_w: float = clampf(vp.x * 0.60, EVENT_MIN_CONTENT_W, EVENT_MAX_CONTENT_W)
	if content_vbox != null:
		content_vbox.custom_minimum_size.x = content_w
	flavour_label.custom_minimum_size.x = content_w
	btn_a.custom_minimum_size.x = content_w
	btn_b.custom_minimum_size.x = content_w
	result_label.custom_minimum_size.x = maxf(content_w - 28.0, 120.0)
	if separator_line != null:
		separator_line.custom_minimum_size.x = content_w
