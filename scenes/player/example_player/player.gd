extends CharacterBody3D
class_name Character

enum State {
	IDLE, WALK, RUN, JUMP, FALL, GROUND_POUND, DIVE, WALL_SLIDE, WALL_JUMP, LAND, GROUND_POUND_RECOVERY, BONK
}

@export_category("General")
@export var gravity := -12.0

@export_category("Jumping")
@export var jump_force := 7.0
@export var jump_extra_force := 3.0
@export var jump_hold_time := 0.2
@export var apex_gravity = 0.8
@export var fall_multiplier := 1.8
@export var low_jump_multiplier := 2.8
@export var max_fall_speed := -20.0
@export var coyote_time_max := 0.15

@export_category("Movement")
@export var move_speed := 7.0
@export var acceleration := 15.0
@export var momentum_acceleration := 3.0
@export var momentum_deceleration := 20.0
@export var ground_deceleration := 30.0 
@export var ground_acceleration := 10.0
@export var air_deceleration := 0.0
@export var air_acceleration := 8.0 
@export var standard_air_influence := 0.3
var air_influence := standard_air_influence
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
@export var dive_speed := 8.0
@export var dive_horizontal_speed := 5.0
@export var dive_upward_boost := 6.0
@export var dive_air_modifier := 0.1
@export var max_dive_duration := 2.5
@export var dive_turn_speed := 2.0
var dive_timer := 0.0
var dive_air_influence = standard_air_influence * dive_air_modifier

@export var bonk_stun_time := 0.8
@export var dive_bonk_window := 0.5
var bonk_timer := 0.0
var stunned_timer := 0.0
var just_bonked = true

@export_category("Ground Pound Recovery")
@export var ground_pound_recovery_time := 0.25
@export var ground_pound_jump_multiplier := 1.4
var recovery_timer := 0.0

@export_category("Wall Interactions")
@export var wall_slide_min_speed := -1.0
@export var wall_slide_max_speed := -6.0
@export var wall_jump_force := Vector3(-7.5, 10, 0)
@export var wall_slide_lerp_duration := 3.0
@export var wall_jump_input_lock_duration := 0.15
var wall_jump_lock_timer := 0.0
var wall_slide_timer := 0.0

@export_category("Buffers")
@export var jump_buffer_time := 0.15
@export var dive_buffer_time := 0.15
@export var wall_jump_buffer_time := 0.15
@export var wall_coyote_time := 0.05
var wall_coyote_timer := 0.0
var was_on_wall := false
var wall_jump_buffer_timer := 0.0
var dive_buffer_timer := 0.0
var jump_buffer_timer := 0.0
var coyote_timer := 0.0

@onready var camera

var direction: Vector3
var current_speed := 0.0
var jump_hold_timer := 0.0
var jump_held := false
var just_dived = false
var bonk_cast

var current_state: State = State.FALL

@onready var nickname: Label3D = $PlayerNick/Nickname

@export_category("Objects")
@export var _body: Node3D = null

@export_category("Skin Colors")
@export var blue_texture : CompressedTexture2D
@export var yellow_texture : CompressedTexture2D
@export var green_texture : CompressedTexture2D
@export var red_texture : CompressedTexture2D

var _current_speed: float
var _respawn_point = Vector3(0, 5, 0)

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	bonk_cast = $BonkCast
	if is_multiplayer_authority():
		camera = $"../Camera"
		camera.camera.current = true
		camera.set_player(self)
	else:
		$Control.hide()
	
func _ready():
	if multiplayer.is_server():
		pass

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	var current_scene = get_tree().get_current_scene()
	if current_scene and current_scene.has_method("is_chat_visible") and current_scene.is_chat_visible() and is_on_floor():
		freeze()
		return
	
	update_debug_menu()
	handle_input()
	apply_gravity(delta)
	update_timers(delta)
	update_state(delta)
	move_character(delta)
	move_and_slide()
	
	_body.animate(velocity)
	_check_fall_and_respawn()

func update_timers(delta):
	# Wall jump coyote time
	var on_wall_now = is_touching_wall() and is_moving_into_wall()
	if !on_wall_now and was_on_wall:
		wall_coyote_timer = wall_coyote_time
	if wall_coyote_timer > 0.0:
		wall_coyote_timer -= delta
	was_on_wall = on_wall_now

	# jump coyote time
	if !is_on_floor():
		coyote_timer -= delta
	else:
		coyote_timer = coyote_time_max

	jump_buffer_timer -= delta
	dive_buffer_timer -= delta
	wall_jump_buffer_timer -= delta

	if is_on_floor():
		wall_jump_buffer_timer = 0.0

	if jump_held and jump_hold_timer > 0.0 and velocity.y > 0:
		velocity.y += jump_extra_force * delta
		jump_hold_timer -= delta
	else:
		jump_held = false

	if Input.is_action_just_released("jump"):
		jump_held = false

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
				ground_pound_started = false
				velocity.y = ground_pound_speed

		State.FALL:
			if is_on_floor():
				current_state = State.LAND
			elif Input.is_action_just_pressed("ground_pound"):
				current_state = State.GROUND_POUND
				ground_pound_started = false
				velocity.y = ground_pound_speed
			elif jump_buffer_timer > 0.0 and coyote_timer > 0.0:
				jump()
			elif is_touching_wall() and is_moving_into_wall():
				current_state = State.WALL_SLIDE
				wall_slide_timer = 0.0

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
				if dive_buffer_timer > 0.0:
					current_state = State.DIVE
					just_dived = true
					dive_buffer_timer = 0.0
					ground_pound_started = false
				elif is_on_floor():
					current_state = State.GROUND_POUND_RECOVERY
					recovery_timer = ground_pound_recovery_time
					ground_pound_started = false

		State.DIVE:
			if just_dived:
				bonk_timer = dive_bonk_window
				dive_timer = 0.0
				perform_dive(delta)
			just_dived = false
			
			dive_timer += delta
			if dive_timer >= max_dive_duration:
				current_state = State.FALL
		
			if bonk_timer > 0.0:
				bonk_timer -= delta
				if bonk_detection():
					just_bonked = true
					current_state = State.BONK
					
			if is_on_floor():
				current_state = State.IDLE

		State.GROUND_POUND_RECOVERY:
			recovery_timer -= delta
			if jump_buffer_timer > 0.0:
				velocity.y = jump_force * ground_pound_jump_multiplier
				current_state = State.JUMP
				jump_hold_timer = jump_hold_time
				jump_held = true
			elif recovery_timer <= 0.0:
				current_state = State.LAND
		
		State.WALL_SLIDE:
			if is_on_floor():
				current_state = State.LAND
			elif !is_on_wall() or !is_moving_into_wall():
				current_state = State.FALL
			elif wall_jump_buffer_timer > 0.0:
				perform_wall_jump()
				current_state = State.WALL_JUMP
			else:
				wall_slide_timer += delta
				var t = clamp(wall_slide_timer / wall_slide_lerp_duration, 0, 1)
				var slide_speed = lerp(wall_slide_min_speed, wall_slide_max_speed, t)
				if velocity.y < slide_speed:
					velocity.y = slide_speed
				velocity = Vector3(velocity.x * .9, velocity.y, velocity.z * .9)


		State.WALL_JUMP:
			if Input.is_action_just_pressed("ground_pound"):
				ground_pound_started = false
				current_state = State.GROUND_POUND
			if is_on_floor():
				current_state = State.LAND
			elif velocity.y < 0:
				current_state = State.FALL

		State.LAND:
			if direction.length() > 0.1:
				current_state = State.WALK
			else:
				current_state = State.IDLE
		
		State.BONK:
			if just_bonked:
				stunned_timer = bonk_stun_time
				bonk_timer = 0.0

				var wall_normal = get_wall_normal()
				if wall_normal == Vector3.ZERO:
					var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
					if horizontal_vel.length() > 0:
						wall_normal = -horizontal_vel.normalized()
					else:
						wall_normal = -transform.basis.z
				velocity = wall_normal * 3.0
				velocity.y = 1.5
			just_bonked = false
			if is_on_floor():
				stunned_timer -= delta
				velocity.x = 0
				velocity.z = 0
				if stunned_timer <= 0.0:
					just_bonked = true
					current_state = State.LAND

func freeze():
	velocity.x = 0
	velocity.z = 0
	_current_speed = 0
	_body.animate(Vector3.ZERO)

func handle_input():
	if camera == null:
		camera = $SpringArmOffset/SpringArm3D/Camera3D
		return
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var cam_basis = camera.global_transform.basis
	var cam_forward = -cam_basis.z
	var cam_right = cam_basis.x

	direction = (cam_forward * input_dir.y + cam_right * input_dir.x).normalized()

	if Input.is_action_just_pressed("spin"):
		dive_buffer_timer = dive_buffer_time
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
		wall_jump_buffer_timer = wall_jump_buffer_time 

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

func move_character(delta):
	if current_state in [State.GROUND_POUND, State.GROUND_POUND_RECOVERY]:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
	
	if current_state == State.BONK:
		direction = Vector3(0, 0, 0)
		
	if (current_state == State.DIVE):
		air_influence = dive_air_influence
	else:
		air_influence = standard_air_influence
		
	momentum_deceleration = ground_deceleration if is_on_floor() else air_deceleration
	momentum_acceleration = ground_acceleration if is_on_floor() else air_acceleration
		
	var input_magnitude = direction.length()
	var move_direction = direction.normalized() if input_magnitude > 0.05 else Vector3.ZERO
	
	if input_magnitude > 0.05:
		var target_angle = atan2(-move_direction.x, -move_direction.z)
		var angle_diff = abs(rad_to_deg(wrapf(target_angle - rotation.y, -PI, PI)))
		var turning_hard = angle_diff > turn_slowdown_threshold
		var slowdown = turn_slowdown_multiplier if turning_hard else 1.0
		current_speed = lerp(current_speed, move_speed * slowdown, momentum_acceleration * delta)
		var turn_speed = dive_turn_speed if current_state == State.DIVE else 10.0
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)
	else:
		current_speed = lerp(current_speed, 0.0, momentum_deceleration * delta)
	
	var desired_velocity = move_direction * current_speed
	
	if is_on_floor():
		velocity.x = lerp(velocity.x, desired_velocity.x, acceleration * delta)
		velocity.z = lerp(velocity.z, desired_velocity.z, acceleration * delta)
	else:
		velocity.x = lerp(velocity.x, desired_velocity.x, air_acceleration * air_influence * delta)
		velocity.z = lerp(velocity.z, desired_velocity.z, air_acceleration * air_influence * delta)
	
		if input_magnitude < 0.05:
			velocity.x = lerp(velocity.x, 0.0, air_deceleration * delta)
			velocity.z = lerp(velocity.z, 0.0, air_deceleration * delta)
	
	move_and_slide()

func _check_fall_and_respawn():
	if global_transform.origin.y < -15.0:
		_respawn()
		
func _respawn():
	global_transform.origin = _respawn_point
	velocity = Vector3.ZERO
	
@rpc("any_peer", "reliable")
func change_nick(new_nick: String):
	if nickname:
		nickname.text = new_nick
		
func get_texture_from_name(skin_name: String) -> CompressedTexture2D:
	match skin_name:
		"blue": return blue_texture
		"green": return green_texture
		"red": return red_texture
		"yellow": return yellow_texture
		_: return blue_texture
		
@rpc("any_peer", "reliable")
func set_player_skin(skin_name: String) -> void:
	var texture = get_texture_from_name(skin_name)
	var bottom: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Bottom")
	var chest: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Chest")
	var face: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Face")
	var limbs_head: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head")
	
	set_mesh_texture(bottom, texture)
	set_mesh_texture(chest, texture)
	set_mesh_texture(face, texture)
	set_mesh_texture(limbs_head, texture)
	
func set_mesh_texture(mesh_instance: MeshInstance3D, texture: CompressedTexture2D) -> void:
	if mesh_instance:
		var material := mesh_instance.get_surface_override_material(0)
		if material and material is StandardMaterial3D:
			var new_material := material
			new_material.albedo_texture = texture
			mesh_instance.set_surface_override_material(0, new_material)

func perform_spin(delta):
	#float/jump/attack thing
	pass

func perform_dive(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var flat_forward = Vector3.FORWARD.rotated(Vector3.UP, camera.global_transform.basis.get_euler().y)
	var flat_right = Vector3.RIGHT.rotated(Vector3.UP, camera.global_transform.basis.get_euler().y)
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
	if position.y < -30:
		position = Vector3(position.x, 100, position.z)
	
	$Control/Label.text = " Position : " + str(round_vector3(position)) + "\n Velocity : " + str(round_vector3(velocity)) + "\n State : " + str(State.keys()[current_state])

func round_vector3(vec: Vector3) -> Vector3:
	return Vector3(round(vec.x * 10.0) / 10.0, round(vec.y * 10.0) / 10.0, round(vec.z * 10.0) / 10.0)

func get_speed():
	return Vector3(velocity.x, 0, velocity.z)

func is_moving_into_wall() -> bool:
	var wall_normal = get_wall_normal()
	if direction.length() < 0.05:
		return false
	return direction.dot(-wall_normal) > 0.5

func bonk_detection() -> bool:
	return bonk_cast.is_colliding()

func is_touching_wall() -> bool:
	return get_slide_collision_count() > 0 and !is_on_floor()

func perform_wall_jump():
	var wall_normal = get_wall_normal()
	velocity = -wall_normal * wall_jump_force.x
	velocity.y = wall_jump_force.y
	wall_jump_buffer_timer = 0.0
	wall_jump_lock_timer = wall_jump_input_lock_duration
	current_state = State.WALL_JUMP

func jump():
	velocity.y = jump_force
	current_state = State.JUMP
	jump_hold_timer = jump_hold_time
	jump_held = true
	jump_buffer_timer = 0.0
