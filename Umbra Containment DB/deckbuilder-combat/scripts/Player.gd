extends Node2D

# ────────────────────────────────────────────
#  SIGNALS
# ────────────────────────────────────────────
signal hp_changed(current_hp: int, max_hp: int)
signal block_changed(current_block: int)
signal ammo_changed(current_ammo: int, max_ammo: int)
signal infection_changed(current_infection: int)
signal player_died

# ────────────────────────────────────────────
#  PLAYER STATS
# ────────────────────────────────────────────
var max_hp       : int = 70
var current_hp   : int = 70
var ammo         : int = 3
var max_ammo     : int = 3
var actions      : int = 1

# ────────────────────────────────────────────
#  DECK SYSTEM
# ────────────────────────────────────────────
var deck         : Array = []
var hand         : Array = []
var discard_pile : Array = []
var hand_size    : int   = 5    # Max cards in hand at once
var max_hand_size: int   = 10   # Hard cap — can never exceed this
# ────────────────────────────────────────────
#  EFFECT MANAGER REFERENCE
# ────────────────────────────────────────────
@onready var effect_manager = $EffectManager

# ────────────────────────────────────────────
#  READY
# ────────────────────────────────────────────

func _ready():
	add_to_group("player") # <--- ADD THIS LINE
	print("SUCCESS: Player node has joined the 'player' group!")
	
	effect_manager.setup(self)
	print("Player ready! HP: ", current_hp, "/", max_hp)

# ────────────────────────────────────────────
#  TAKE DAMAGE
#  Routes through EffectManager so Block
#  and other defensive effects apply cleanly
# ────────────────────────────────────────────
func take_damage(amount: int) -> void:
	effect_manager.receive_damage(amount)

# ────────────────────────────────────────────
#  HEALING
# ────────────────────────────────────────────
func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)
	emit_signal("hp_changed", current_hp, max_hp)
	print("Player heals ", amount,
		  ". HP: ", current_hp, "/", max_hp)

# ────────────────────────────────────────────
#  BLOCK — now applies via EffectManager
# ────────────────────────────────────────────
func add_block(amount: int) -> void:
	effect_manager.apply_effect("Block", amount)

# ────────────────────────────────────────────
#  INFECTION — now applies via EffectManager
# ────────────────────────────────────────────
func add_infection(amount: int) -> void:
	effect_manager.apply_effect("Infection", amount)

# ────────────────────────────────────────────
#  AMMO
# ────────────────────────────────────────────
func spend_ammo(amount: int) -> bool:
	if ammo >= amount:
		ammo -= amount
		emit_signal("ammo_changed", ammo, max_ammo)
		print("Spent ", amount, " ammo. Remaining: ", ammo)
		return true
	print("Not enough ammo!")
	return false

func restore_ammo() -> void:
	ammo = max_ammo
	emit_signal("ammo_changed", ammo, max_ammo)
	print("Ammo restored to ", ammo)

# ────────────────────────────────────────────
#  TURN SYSTEM
# ────────────────────────────────────────────
func start_turn() -> void:
	print("--- Player starting turn ---")
	print("Deck: ", deck.size(),
		  " | Hand: ", hand.size(),
		  " | Discard: ", discard_pile.size())
	effect_manager.trigger_turn_start()
	restore_ammo()
	# Draw up to hand_size but never exceed max_hand_size
	var cards_needed = hand_size - hand.size()
	if cards_needed > 0:
		draw_cards(cards_needed)
	else:
		print("Hand already has ", hand.size(), " cards — skipping draw.")

func end_turn() -> void:
	print("--- Player ending turn ---")
	discard_hand()
	effect_manager.trigger_turn_end()
	print("Player turn ended.")

# ────────────────────────────────────────────
#  DRAW CARDS
#  Draws up to `amount` cards respecting:
#    - Current hand size (won't overdraw)
#    - Max hand size hard cap
#    - Auto-reshuffles discard when deck empty
#    - Stops gracefully if no cards available
# ────────────────────────────────────────────
func draw_cards(amount: int) -> void:
	# How many cards can we actually draw?
	var space_in_hand = max_hand_size - hand.size()
	var cards_to_draw = min(amount, space_in_hand)

	if cards_to_draw <= 0:
		print("Hand is full! Cannot draw more cards. (",
			  hand.size(), "/", max_hand_size, ")")
		return

	print("Drawing ", cards_to_draw, " card(s)...",
		  " (Hand: ", hand.size(),
		  "/", max_hand_size, ")")

	var drawn = 0
	for i in range(cards_to_draw):
		# If deck is empty, try to reshuffle
		if deck.is_empty():
			if discard_pile.is_empty():
				# Both deck and discard are empty — stop drawing
				print("⚠️ No cards left anywhere!",
					  " Drew ", drawn, "/", cards_to_draw)
				break
			reshuffle_discard()

		# Draw the top card
		var card = deck.pop_front()
		hand.append(card)
		drawn += 1
		print("  Drew: ", card.card_name,
			  " | Hand: ", hand.size(),
			  " | Deck: ", deck.size(),
			  " | Discard: ", discard_pile.size())

	print("Draw complete. Hand size: ", hand.size())

# ────────────────────────────────────────────
#  RESHUFFLE DISCARD INTO DECK
#  Called automatically when deck runs out
# ────────────────────────────────────────────
func reshuffle_discard() -> void:
	if discard_pile.is_empty():
		print("⚠️ Cannot reshuffle — discard pile is empty!")
		return

	print("🔀 Reshuffling ", discard_pile.size(),
		  " cards from discard into deck...")
	deck = discard_pile.duplicate()
	deck.shuffle()
	discard_pile.clear()
	print("  Deck now has ", deck.size(), " cards.")

# ────────────────────────────────────────────
#  PLAY CARD
#  Moves card from hand to discard pile
# ────────────────────────────────────────────
func play_card(card: CardData) -> void:
	if hand.has(card):
		hand.erase(card)
		discard_pile.append(card)
		print("Played: ", card.card_name,
			  " | Hand: ", hand.size(),
			  " | Discard: ", discard_pile.size())
	else:
		print("WARNING: Tried to play card not in hand: ",
			  card.card_name)

# ────────────────────────────────────────────
#  DISCARD HAND
#  Moves ALL remaining hand cards to discard
#  Called at end of turn
# ────────────────────────────────────────────
func discard_hand() -> void:
	if hand.is_empty():
		print("Hand already empty — nothing to discard.")
		return

	print("Discarding ", hand.size(), " card(s) from hand:")
	for card in hand:
		print("  Discarded: ", card.card_name)
		discard_pile.append(card)
	hand.clear()
	print("Hand cleared. Discard pile: ",
		  discard_pile.size(), " cards.")

# ────────────────────────────────────────────
#  DEATH
# ────────────────────────────────────────────
func die() -> void:
	emit_signal("player_died")
	print("Player has died! Game Over.")


# Add this to Player.gd
func apply_effect(effect_name: String, amount: int) -> void:
	# Check if the player has an EffectManager child node
	if has_node("EffectManager"):
		$EffectManager.apply_effect(effect_name, amount)
	else:
		# If you don't use an EffectManager node, 
		# we'll print a warning so we know why it's failing
		print("!!! ERROR: Player node needs an 'EffectManager' child to use apply_effect()")
