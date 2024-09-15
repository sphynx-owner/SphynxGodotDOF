extends "res://addons/SphynxDOFToolkit/dof_compositor_effect.gd"

@export_group("Shader Parameters")
@export var tile_size : int = 40

@export var linear_falloff_slope : float = 1

@export var importance_bias : float = 40

@export var maximum_jitter_value : float = 0.95

@export var minimum_user_threshold : float = 1.5

@export var focal_distance : float = 10

@export var focal_amount : float = 1

@export var max_focal_amount : float = 20
