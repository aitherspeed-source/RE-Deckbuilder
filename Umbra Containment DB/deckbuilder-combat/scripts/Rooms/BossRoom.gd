extends Node2D

# ────────────────────────────────────────────
#  BOSS ROOM — Placeholder
#  Full boss fight to be implemented later.
#  For now: routes to combat scene (boss is
#  handled by CombatManager's BOSS room type).
# ────────────────────────────────────────────

@onready var continue_button : Button = $VBox/ContinueButton

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed() -> void:
	# Boss fight loads combat scene directly
	get_tree().change_scene_to_file("res://scenes/combat.tscn")
