extends CharacterBody3D

enum State {
	IDLE, WALK, RUN, JUMP, FALL, GROUND_POUND, DIVE, WALL_JUMP, LAND, GROUND_POUND_RECOVERY
}

@export_category("General")
@export var gravity := -15.0

@export_category("Jumping")
@export var jump_force := 10.0
@export var jump_extra_force := 5.0
@export var jump_hold_time := 0.2
@export var apex_gravity = 0.8
@export var fall_multiplier := 2.0
@export var low_jump_multiplier := 2.8
@export var max_fall_speed := -20.0
@export var coyote_time_max := 0.15
@export var jump_buffer_time := 0.2

@export_category("Movement")
@export var move_speed := 5.0
@export var run_speed := 7.0
@export var acceleration := 15.0
@export var momentum_acceleration := 3.0
@export var momentum_deceleration := 30.0
@export var ground_deceleration := 30.0 
@export var ground_acceleration := 15.0
@export var air_deceleration := 2.0
@export var air_acceleration := 6.0 
@export var dive_speed := 30.0
@export var max_snap_angle := 45.0
@export var turn_slowdown_threshold := 110.0
@export var turn_slowdown_multiplier := 0.9

@export_category("Ground Pound")
@export var ground_pound_speed := -16.0
@export var ground_pound_acceleration := 6.0 
@export var ground_pound_delay := 0.2 
var ground_pound_timer := 0.0
var ground_pound_started := false

@export_category("Dive")
@export var dive_horizontal_speed := 10.0
@export var dive_upward_boost := 8.0

@export_category("Ground Pound Recovery")
@export var ground_pound_recovery_time := 0.25
@export var ground_pound_jump_multiplier := 1.4
var recovery_timer := 0.0

@onready var camera = $"../Camera"

var direction: Vector3
var current_speed := 0.0

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var jump_hold_timer := 0.0
var jump_held := false
var just_dived = false

var current_state: State = State.FALL

func _ready():
	pass

func _physics_process(delta):
	update_debug_menu()
	handle_input()
	update_timers(delta)
	update_state(delta)
	apply_gravity(delta)
	move_character(delta)

func handle_input():
	var input_dir = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var cam_basis = camera.global_transform.basis
	var cam_forward = -cam_basis.z
	var cam_right = cam_basis.x

	direction = (cam_forward * input_dir.y + cam_right * input_dir.x).normalized()

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

func update_timers(delta):
	if !is_on_floor():
		coyote_timer -= delta
	else:
		coyote_timer = coyote_time_max

	jump_buffer_timer -= delta

	if jump_held and jump_hold_timer > 0.0 and velocity.y > 0:
		velocity.y += jump_extra_force * delta
		jump_hold_timer -= delta
	else:
		jump_held = false

	if Input.is_action_just_released("jump"):
		jump_held = false


func jump():
	velocity.y = jump_force
	current_state = State.JUMP
	jump_hold_timer = jump_hold_time
	jump_held = true
	jump_buffer_timer = 0.0

func apply_gravity(delta):
	var is_rising = velocity.y > 0
	var is_falling = velocity.y < 0
	var at_apex = abs(velocity.y) < 2.0

	if is_falling:
		velocity.y += gravity * fall_multiplier * delta
	elif !jump_held and is_rising:
		velocity.y += gravity * low_jump_multiplier * delta
	elif at_apex:
		velocity.y += gravity * apex_gravity * delta
	else:
		velocity.y += gravity * delta
	
	velocity.y = max(velocity.y, max_fall_speed)

func update_state(delta):
	match current_state:
		State.IDLE, State.WALK, State.RUN:
			if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
				jump()
			elif !is_on_floor():
				current_state = State.FALL
			elif direction.length() > 0.1:
				current_state = State.WALK
			else:
				current_state = State.IDLE

		State.JUMP:
			if velocity.y < 0:
				current_state = State.FALL
			elif Input.is_action_just_pressed("ground_pound"):
				current_state = State.GROUND_POUND
				velocity.y = ground_pound_speed

		State.FALL:
			if is_on_floor():
				current_state = State.LAND
			elif Input.is_action_just_pressed("ground_pound"):
				current_state = State.GROUND_POUND
				velocity.y = ground_pound_speed
			elif jump_buffer_timer > 0.0 and coyote_timer > 0.0:
				jump()

		State.GROUND_POUND:
			if !ground_pound_started:
				ground_pound_started = true
				ground_pound_timer = ground_pound_delay
				current_speed = 0
				velocity.y = 0 

			else:
				ground_pound_timer -= delta

				if ground_pound_timer <= 0.0:
					velocity.y = lerp(velocity.y, ground_pound_speed, ground_pound_acceleration * delta)
				else:
					velocity.y = 0
				if Input.is_action_just_pressed("spin"):
					current_state = State.DIVE
					just_dived = true
					ground_pound_started = false
				elif is_on_floor():
					current_state = State.GROUND_POUND_RECOVERY
					recovery_timer = ground_pound_recovery_time
					ground_pound_started = false

		State.DIVE:
			if just_dived:
				perform_dive(delta)
			just_dived = false
			
			if is_on_floor():
				current_state = State.IDLE


		State.GROUND_POUND_RECOVERY:
			recovery_timer -= delta

			if Input.is_action_just_pressed("jump"):
				velocity.y = jump_force * ground_pound_jump_multiplier
				current_state = State.JUMP
				jump_hold_timer = jump_hold_time
				jump_held = true
			elif recovery_timer <= 0.0:
				current_state = State.LAND

		State.LAND:
			if direction.length() > 0.1:
				current_state = State.WALK
			else:
				current_state = State.IDLE

func move_character(delta):
	momentum_deceleration = ground_deceleration if is_on_floor() else air_deceleration
	momentum_acceleration = ground_acceleration if is_on_floor() else air_acceleration
	
	var input_magnitude = direction.length()
	var move_direction = direction
	
	if current_state == State.DIVE:
		move_direction = Vector3.ZERO
		input_magnitude = 0
	
	if move_direction != Vector3.ZERO:
		move_direction = move_direction.normalized()
	
	if input_magnitude > 0.05:
		var target_angle = atan2(-move_direction.x, -move_direction.z)
		var angle_diff = abs(rad_to_deg(wrapf(target_angle - rotation.y, -PI, PI)))

		var turning_hard = angle_diff > turn_slowdown_threshold
		var slowdown = turn_slowdown_multiplier if turning_hard else 1.0

		current_speed = lerp(current_speed, run_speed * slowdown, momentum_acceleration * delta)
		rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)
	else:
		current_speed = lerp(current_speed, 0.0, momentum_deceleration * delta)

	var desired_velocity = move_direction * current_speed 

	if input_magnitude < 0.05:
		desired_velocity.x = lerp(velocity.x, 0.0, momentum_deceleration * delta)
		desired_velocity.z = lerp(velocity.z, 0.0, momentum_deceleration * delta)

	velocity.x = lerp(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = lerp(velocity.z, desired_velocity.z, acceleration * delta)

	if current_state == State.GROUND_POUND:
		velocity = Vector3(0, velocity.y, 0)
	

	move_and_slide()

func perform_spin(delta):
	#float/jump/attack thing from galaxy 
	pass

func perform_dive(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var camera_yaw = camera.global_transform.basis.get_euler().y
	var flat_forward = Vector3.FORWARD.rotated(Vector3.UP, camera_yaw)
	var flat_right = Vector3.RIGHT.rotated(Vector3.UP, camera_yaw)
	var dive_direction = (flat_forward * input_dir.y + flat_right * input_dir.x).normalized()
	
	if dive_direction.length() < 0.1:
		dive_direction = -global_transform.basis.z.normalized()
		dive_direction.y = 0  
	
	var horizontal_velocity = dive_direction * dive_horizontal_speed
	velocity.y = dive_upward_boost
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	
	if dive_direction.length() > 0.1:
		var target_angle = atan2(-dive_direction.x, -dive_direction.z)
		rotation.y = target_angle


func update_debug_menu():
	$Control/Label.text = " Position : " + str(round_vector3(position.round())) + "\n Velocity : " + str(round_vector3(velocity.round())) + "\n State : " + str(State.keys()[current_state])

func round_vector3(vec: Vector3) -> Vector3:
	return Vector3(
		round(vec.x * 100.0) / 100.0,
		round(vec.y * 100.0) / 100.0,
		round(vec.z * 100.0) / 100.0
	)

func get_speed():
	return Vector3(velocity.x, 0, velocity.z)
