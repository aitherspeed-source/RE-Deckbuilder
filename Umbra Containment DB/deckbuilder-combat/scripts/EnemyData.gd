class_name EnemyData extends Resource

# Core identity/stats
@export var enemy_name: String = "New Enemy"
@export var max_hp: int = 40

# Base intent numbers used by enemy.gd execution
@export var attack_damage: int = 8
@export var heavy_damage: int = 18
@export var defend_amount: int = 6
@export var infect_amount: int = 2

# Weighted pools. Each entry example:
# {"kind": "attack", "weight": 2}
@export var intent_pool_phase_a: Array[Dictionary] = []
@export var intent_pool_phase_b: Array[Dictionary] = []

# Evolution
@export var evolution_name: String = "Evolved Enemy"
@export var evolution_threshold: float = 0.5
