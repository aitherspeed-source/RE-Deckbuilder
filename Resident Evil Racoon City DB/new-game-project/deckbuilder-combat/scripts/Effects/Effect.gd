extends RefCounted
class_name Effect

var effect_name  : String = "Base Effect"
var description  : String = "Does nothing."
var icon         : String = "❓"
var stacks       : int    = 1
var max_stacks   : int    = 99
var trigger_on_turn_start : bool = false
var trigger_on_turn_end   : bool = true
var duration     : int    = -1
var damage_multiplier : float = 1.0
var stack_multiplier  : float = 1.0
var is_blocked        : bool  = false

func apply(entity) -> void:
	print(effect_name, " applied to ", entity.name, " (", stacks, " stacks)")

func on_turn_trigger(entity) -> void:
	print(effect_name, " triggered on ", entity.name)

func tick(entity) -> void:
	if duration > 0:
		duration -= 1
		if duration == 0:
			remove(entity)

func remove(entity) -> void:
	print(effect_name, " wore off on ", entity.name)

func add_stacks(amount: int) -> void:
	var real_amount = int(amount * stack_multiplier)
	stacks = min(stacks + real_amount, max_stacks)
	print(effect_name, " stacks → ", stacks)

func remove_stacks(amount: int) -> void:
	stacks = max(stacks - amount, 0)

func is_expired() -> bool:
	return stacks <= 0

func get_effective_value() -> int:
	return int(stacks * damage_multiplier)
