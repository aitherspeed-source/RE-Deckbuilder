extends Control

# ────────────────────────────────────────────
#  MAP UI CONTROL
#  Fills the full screen so all map buttons
#  are clickable anywhere on screen
# ────────────────────────────────────────────
func _ready() -> void:
	# Fill the whole screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
