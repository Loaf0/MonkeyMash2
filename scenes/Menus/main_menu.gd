extends Control

@export_category("Skin Colors")
@export var blue_texture : CompressedTexture2D
@export var yellow_texture : CompressedTexture2D
@export var green_texture : CompressedTexture2D
@export var red_texture : CompressedTexture2D
@export var indigo_texture : CompressedTexture2D
@export var forest_texture : CompressedTexture2D
@export var midnight_texture : CompressedTexture2D
@export var noir_texture : CompressedTexture2D
@export var ourple_texture : CompressedTexture2D
@export var corn_texture : CompressedTexture2D
@export var rust_texture : CompressedTexture2D
@export var pink_texture : CompressedTexture2D
@export var orange_texture : CompressedTexture2D

enum cameraLocations {MAIN, CHARACTER_SELECT, OPTIONS} 

var current_state: cameraLocations = cameraLocations.MAIN

@onready var bottom: MeshInstance3D = $"CanvasLayer/3DGodotRobot/RobotArmature/Skeleton3D/Bottom"
@onready var chest: MeshInstance3D = $"CanvasLayer/3DGodotRobot/RobotArmature/Skeleton3D/Chest"
@onready var face: MeshInstance3D = $"CanvasLayer/3DGodotRobot/RobotArmature/Skeleton3D/Face"
@onready var limbs_head: MeshInstance3D = $"CanvasLayer/3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head"

@onready var char_select_menu = $CharacterSelectButtons
@onready var main_menu = $MainMenuButtons

@onready var anim = $"CanvasLayer/3DGodotRobot/AnimationPlayer"
@onready var cam = $CanvasLayer/MainMenuCamera

@onready var charSelectPos = $"CanvasLayer/CameraLocations/Character Select Pos"
@onready var charLookPos = $"CanvasLayer/CameraLocations/Character Select LookPos"

@onready var skin_selector = $CharacterSelectButtons/VBox/MarginContainer/SkinSelect

var desired_pos : Vector3 
var desired_look_pos : Vector3 

func _ready() -> void:
	char_select_menu.visible = false
	main_menu.visible = true
	var x = orbit_center.x + orbit_radius * cos(orbit_angle)
	var z = orbit_center.z + orbit_radius * sin(orbit_angle)
	var y = orbit_height
	desired_pos = Vector3(x, y, z)
	desired_look_pos = orbit_center
	cam.position = desired_pos
	cam.look_at(desired_look_pos)

var orbit_center: Vector3 = Vector3.ZERO
var orbit_radius: float = 50.0
var orbit_height: float = 15.0
var orbit_speed: float = 0.1
var orbit_angle: float = 0.0

func _process(delta: float) -> void:
	lerp_cam_to(delta)
	if current_state == cameraLocations.MAIN:
		orbit_angle += delta * orbit_speed
		var x = orbit_center.x + orbit_radius * cos(orbit_angle)
		var z = orbit_center.z + orbit_radius * sin(orbit_angle)
		var y = orbit_height
		desired_pos = Vector3(x, y, z)
		desired_look_pos = orbit_center
	if current_state == cameraLocations.CHARACTER_SELECT:
		desired_pos = charSelectPos.position
		desired_look_pos = charLookPos.position
		if desired_pos.distance_to(cam.position) < 5 and anim.current_animation == "Idle":
			anim.play("MenuIdle", 0.2)
			

func _on_host_pressed() -> void:
	pass # Replace with function body.

func _on_join_pressed() -> void:
	pass # Replace with function body.

func _on_edit_char_pressed() -> void:
	anim.play("Idle")
	current_state = cameraLocations.CHARACTER_SELECT
	char_select_menu.visible = true
	main_menu.visible = false

func _on_settings_pressed() -> void:
	pass # Replace with function body.

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_skin_select_item_selected(index: int) -> void:
	print("Skin select index " + str(index) + " " + skin_selector.get_item_text(index))
	set_player_skin(skin_selector.get_item_text(index))
	Settings.COLOR = skin_selector.get_item_text(index)

func _on_return_pressed() -> void:
	current_state = cameraLocations.MAIN
	char_select_menu.visible = false
	main_menu.visible = true

func set_player_skin(skin_name: String) -> void:
	var texture = get_texture_from_name(skin_name.to_lower())
	
	set_mesh_texture(bottom, texture)
	set_mesh_texture(chest, texture)
	set_mesh_texture(face, texture)
	set_mesh_texture(limbs_head, texture)

func get_texture_from_name(skin_name: String) -> CompressedTexture2D:
	match skin_name:
		"blue": return blue_texture
		"green": return green_texture
		"red": return red_texture
		"yellow": return yellow_texture
		"corn": return corn_texture
		"noir": return noir_texture
		"forest": return forest_texture
		"ourple": return ourple_texture
		"indigo": return indigo_texture
		"midnight": return midnight_texture
		"rust": return rust_texture
		"pink": return pink_texture
		"orange": return orange_texture
		_: return blue_texture

func set_mesh_texture(mesh_instance: MeshInstance3D, texture: CompressedTexture2D) -> void:
	if mesh_instance:
		var material := mesh_instance.get_surface_override_material(0)
		if material and material is StandardMaterial3D:
			var new_material := material
			new_material.albedo_texture = texture
			mesh_instance.set_surface_override_material(0, new_material)

func lerp_cam_to(delta: float) -> void:
	cam.position = cam.position.lerp(desired_pos, delta * 3.0)

	var direction = (desired_look_pos - cam.position).normalized()
	var target_rotation = cam.global_transform.looking_at(desired_look_pos, Vector3.UP).basis
	var current_transform = cam.global_transform
	current_transform.basis = current_transform.basis.slerp(target_rotation, delta * 1.0)
	cam.global_transform = current_transform

func _on_nick_input_text_changed(new_text: String) -> void:
	Settings.NAME = new_text
