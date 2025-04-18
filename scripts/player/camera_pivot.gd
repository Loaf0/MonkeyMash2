extends Node3D

@export var player: Node3D

@onready var camera: Node3D = $Camera

@export var camera_dist := 15.0
@export var camera_height := 0.5
@export var max_camera_dist := 8.0
@export var min_camera_dist := 5.0
@export var speed_zoom_mod = 20.0  
@export var rotation_speed := 3.5 
@export var move_smooth := 6.0
@export var vertical_limit := 50.0
@export var right_stick_influence := 45.0
@export var follow_behind_strength := 30.0

var using_mkb = false
var yaw := 0.0
var pitch := 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	yaw = rotation_degrees.y
	pitch = rotation_degrees.x

func _input(event):
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * Settings.MOUSE_SENSITIVITY
		pitch -= event.relative.y * Settings.MOUSE_SENSITIVITY
		pitch = clamp(pitch, -vertical_limit, vertical_limit)


func _physics_process(delta: float) -> void:
	handle_controller_input(delta)
	update_camera_position(delta)

func handle_controller_input(delta: float) -> void:
	var look_x := Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	var look_y := Input.get_action_strength("look_down") - Input.get_action_strength("look_up")

	if abs(look_x) > 0.05 or abs(look_y) > 0.05:
		yaw -= look_x * rotation_speed
		pitch -= look_y * rotation_speed
		pitch = clamp(pitch, -vertical_limit, vertical_limit)
	else:
		var move_x := Input.get_action_strength("left_stick_right") - Input.get_action_strength("left_stick_left")
		if abs(move_x) > 0.1:
			yaw -= move_x * right_stick_influence * delta

	rotation_degrees = Vector3(pitch, yaw, 0)

func update_camera_position(delta: float) -> void:
	if player:
		var player_speed = 50
		if player.has_method("get_speed"):
			player_speed = player.get_speed()

		camera_dist = lerp(min_camera_dist, max_camera_dist, player_speed / speed_zoom_mod)
		camera_dist = clamp(camera_dist, min_camera_dist, max_camera_dist)

		var target_pos = global_position
		target_pos.y = player.global_position.y + camera_height
		target_pos = target_pos.move_toward(
			Vector3(player.global_position.x, player.global_position.y + camera_height, player.global_position.z),
			delta * follow_behind_strength
		)
		global_position = target_pos

	var target_offset = Vector3(0, 0, camera_dist)

	camera.position = camera.position.move_toward(target_offset, delta * move_smooth)

func set_player(p):
	player = p
