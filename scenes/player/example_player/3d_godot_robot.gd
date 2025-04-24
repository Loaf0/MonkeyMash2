extends Node3D
class_name Body

const LERP_VELOCITY: float = 0.15

enum State {
	IDLE, WALK, RUN, JUMP, FALL, GROUND_POUND, DIVE, 
	WALL_SLIDE, WALL_JUMP, LAND, GROUND_POUND_RECOVERY, 
	BONK, CROUCH, SLIDE, LONG_JUMP, EMOTE1
}

@export_category("Objects")
@export var _character: CharacterBody3D = null
@export var animation_player: AnimationPlayer = null

func apply_rotation(_velocity: Vector3) -> void:
	var new_rotation_y = lerp_angle(rotation.y, atan2(-_velocity.x, -_velocity.z), LERP_VELOCITY)
	rotation.y = new_rotation_y
	
	rpc("sync_player_rotation", new_rotation_y)
	
func animate(state) -> void:
	
	match state:
		State.IDLE, State.LAND:
			animation_player.play("Idle")
		State.WALK:
			animation_player.play("Run")
		State.RUN:
			animation_player.play("Sprint")
		State.JUMP:
			animation_player.play("Jump")
		State.FALL:
			animation_player.play("Fall")
		State.CROUCH, State.GROUND_POUND, State.GROUND_POUND_RECOVERY:
			animation_player.play("Crouch")
		State.SLIDE:
			animation_player.play("GroundSlide")
		State.LONG_JUMP:
			animation_player.play("LongJump")
		State.DIVE, State.BONK:
			animation_player.play("Dive")
		State.WALL_SLIDE:
			animation_player.play("WallSlide")
		State.WALL_JUMP:
			animation_player.play("WallJump")
		State.EMOTE1:
			animation_player.play("Emote1")
	pass

@rpc("any_peer", "reliable")
func sync_player_rotation(rotation_y: float) -> void:
	rotation.y = rotation_y
