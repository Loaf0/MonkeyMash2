extends Node3D
class_name Body

const LERP_VELOCITY: float = 0.15

enum State {
	IDLE, WALK, RUN, JUMP, FALL, GROUND_POUND, DIVE, 
	WALL_SLIDE, WALL_JUMP, LAND, GROUND_POUND_RECOVERY, 
	BONK, CROUCH, SLIDE, LONG_JUMP, EMOTE1
}

@export_category("Objects")
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func apply_rotation(_velocity: Vector3) -> void:
	var new_rotation_y = lerp_angle(rotation.y, atan2(-_velocity.x, -_velocity.z), LERP_VELOCITY)
	rotation.y = new_rotation_y
	
	rpc("sync_player_rotation", new_rotation_y)

func animate(state) -> void:
	match state:
		State.IDLE, State.LAND:
			animation_player.play("Idle", 0.2)
		State.WALK:
			animation_player.play("Run", 0.3)
		State.RUN:
			animation_player.play("Sprint", 0.3)
		State.JUMP:
			animation_player.play("Jump", 0.2)
		State.FALL:
			animation_player.play("Fall", 0.3)
		State.CROUCH, State.GROUND_POUND, State.GROUND_POUND_RECOVERY:
			animation_player.play("Crouch", 0.15)
		State.SLIDE:
			animation_player.play("GroundSlide", 0.2)
		State.LONG_JUMP:
			animation_player.play("LongJump", 0.15)
		State.DIVE, State.BONK:
			animation_player.play("Dive", 0.1)
		State.WALL_SLIDE:
			animation_player.play("WallSlide", 0.2)
		State.WALL_JUMP:
			animation_player.play("WallJump", 0.3)
		State.EMOTE1:
			animation_player.play("Emote1", 0.2)

@rpc("any_peer", "reliable")
func sync_player_rotation(rotation_y: float) -> void:
	rotation.y = rotation_y
