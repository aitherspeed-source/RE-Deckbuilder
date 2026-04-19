extends Node2D

# ────────────────────────────────────────────
#  SAFE ROOM
#  Player chooses ONE of three options:
#    1. Heal HP
#    2. Remove a card from deck
#    3. Upgrade a card in deck
# ────────────────────────────────────────────

@onready var ui = $UI/SafeRoomUI

# How much HP the heal option restores
const HEAL_AMOUNT : int = 20

enum SafeRoomState {
	CHOOSING_OPTION,  # Main menu — pick heal/remove/upgrade
	REMOVING_CARD,    # Showing deck to pick card to remove
	UPGRADING_CARD,   # Showing deck to pick card to upgrade
	DONE              # Option chosen, waiting to leave
}

var current_state : SafeRoomState = SafeRoomState.CHOOSING_OPTION

# ────────────────────────────────────────────
#  READY
# ────────────────────────────────────────────
func _ready() -> void:
	print("=== SAFE ROOM ===")
	print("Player HP: ", GameManager.player_current_hp,
		"/", GameManager.player_max_hp)
	ui.setup(self)

# ────────────────────────────────────────────
#  HEAL
# ────────────────────────────────────────────
func choose_heal() -> void:
	var healed = min(
		HEAL_AMOUNT,
		GameManager.player_max_hp - GameManager.player_current_hp)
	GameManager.heal_player(HEAL_AMOUNT)
	print("Player healed ", healed, " HP.")
	current_state = SafeRoomState.DONE
	ui.show_done_screen(
		"🏥 Healed " + str(healed) + " HP!\n\nHP: " +
		str(GameManager.player_current_hp) + "/" +
		str(GameManager.player_max_hp))

# ────────────────────────────────────────────
#  REMOVE CARD
# ────────────────────────────────────────────
func choose_remove() -> void:
	current_state = SafeRoomState.REMOVING_CARD
	ui.show_deck_picker(
		"🗑️ Choose a card to REMOVE from your deck:",
		"remove")

func confirm_remove(card: CardData) -> void:
	print("Removing card: ", card.card_name)
	GameManager.remove_card_from_deck(card)
	current_state = SafeRoomState.DONE
	ui.show_done_screen(
		"🗑️ Removed:\n" + card.card_name +
		"\n\nDeck size: " +
		str(GameManager.player_deck.size()) + " cards")

# ────────────────────────────────────────────
#  UPGRADE CARD
# ────────────────────────────────────────────
func choose_upgrade() -> void:
	current_state = SafeRoomState.UPGRADING_CARD
	ui.show_deck_picker(
		"⬆️ Choose a card to UPGRADE:",
		"upgrade")

func confirm_upgrade(card: CardData) -> void:
	print("Upgrading card: ", card.card_name)
	_apply_upgrade(card)
	current_state = SafeRoomState.DONE
	ui.show_done_screen(
		"⬆️ Upgraded:\n" + card.card_name + "+\n\n" +
		card.description)

# ────────────────────────────────────────────
#  APPLY UPGRADE LOGIC
#  Each upgrade improves the card's value
#  and adds a + to the name to show it's upgraded
# ────────────────────────────────────────────
func _apply_upgrade(card: CardData) -> void:
	# Don't upgrade twice
	if card.card_name.ends_with("+"):
		print("Card already upgraded!")
		return

	card.card_name = card.card_name + "+"

	match card.effect:
		"deal_damage":
			card.value     += 3
			card.description = "Deal " + str(card.value) + " damage."

		"deal_damage_twice":
			card.value     += 2
			card.description = "Deal " + str(card.value) + " damage twice."

		"damage_and_infect":
			card.value     += 2
			card.value2    += 1
			card.description = "Deal " + str(card.value) + \
				" damage. Apply " + str(card.value2) + " Infection."

		"gain_block":
			card.value     += 3
			card.description = "Gain " + str(card.value) + " Block."

		"gain_ammo_and_draw":
			card.cost       = max(card.cost - 1, 0)
			card.description = "Gain " + str(card.value) + \
				" Ammo. Draw " + str(card.value2) + " card."

		"apply_infection":
			card.value     += 2
			card.description = "Apply " + str(card.value) + " Infection."

		"heal_and_block":
			card.value     += 3
			card.value2    += 2
			card.description = "Heal " + str(card.value) + \
				" HP. Gain " + str(card.value2) + " Block."

		"rage_attack":
			card.value     += 4
			card.description = "Gain " + str(card.value2) + \
				" Infection. Deal " + str(card.value) + " damage."

		"fortify":
			card.value     += 3
			card.description = "Gain " + str(card.value) + \
				" Block. Next attack +3 damage."

		_:
			# Generic fallback — reduce cost by 1
			card.cost = max(card.cost - 1, 0)

	print("Upgraded to: ", card.card_name,
		" | Value: ", card.value,
		" | Cost: ", card.cost)

# ────────────────────────────────────────────
#  LEAVE SAFE ROOM
# ────────────────────────────────────────────
func leave() -> void:
	print("Leaving Safe Room.")
	GameManager.complete_room(GameManager.current_node_id)
