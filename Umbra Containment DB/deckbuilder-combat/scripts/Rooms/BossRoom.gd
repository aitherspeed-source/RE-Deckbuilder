extends Node2D

# ────────────────────────────────────────────
#  BOSS ROOM — Placeholder
#  Full boss fight to be implemented later.
#  For now: routes to combat scene (boss is
#  handled by CombatManager's BOSS room type).
# ────────────────────────────────────────────

func _ready() -> void:
	# Auto-start boss combat (BossRoom is legacy placeholder).
	get_tree().change_scene_to_file("res://scenes/combat.tscn")
