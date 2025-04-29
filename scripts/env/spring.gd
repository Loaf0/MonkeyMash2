extends Node3D

@export var spring_strength = 2

func _on_spring_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.velocity.y = body.jump_force * spring_strength
		body.current_state = body.State.JUMP
		body.jump_hold_timer = body.jump_hold_time
		body.jump_held = true
		body.jump_buffer_timer = 0.0
