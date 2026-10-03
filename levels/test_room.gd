extends Node2D

# Sandbox room for testing movement feel. Keeps the camera inside the
# room and respawns the player at the start if they fall out the bottom.

# Camera bounds in pixels. Stopping just below the floor's top row keeps
# the deep fill bricks (which the tileset isn't really drawn for) off screen.
@export var camera_limits := Rect2i(0, 0, 768, 368)
# Falling below this y sends the player back to their spawn point.
@export var respawn_below_y: float = 480.0

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D


func _ready() -> void:
	camera.limit_left = camera_limits.position.x
	camera.limit_top = camera_limits.position.y
	camera.limit_right = camera_limits.end.x
	camera.limit_bottom = camera_limits.end.y
	# Without this the camera eases in from the origin on the first frame.
	camera.reset_smoothing()


func _physics_process(_delta: float) -> void:
	if player.global_position.y > respawn_below_y:
		player.respawn()
		camera.reset_smoothing()
