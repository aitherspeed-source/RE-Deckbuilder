extends Node2D

# ────────────────────────────────────────────
#  EVENT ROOM — Placeholder
#  Full event system to be implemented later.
#  For now: just routes back to the map.
# ────────────────────────────────────────────

@onready var continue_button : Button = $VBox/ContinueButton

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed() -> void:
	GameManager.complete_room(GameManager.current_node_id)
