extends Node3D

@export var sensitivity: Vector2 = Vector2(0.02,0.02)
@export var zoom_sensitivity: float = 0.35


@export var camera: Camera3D = null
@export var camera_lerp_speed: float = 10

var target_camera_pos: Vector3 = Vector3.ZERO
var target_camera_size: float = 20.0
var target_rot: Vector3 = Vector3.ZERO

func _ready() -> void:
	target_camera_pos = camera.position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			target_rot.y -= (event as InputEventMouseMotion).screen_relative.x * sensitivity.x
			target_rot.x -= (event as InputEventMouseMotion).screen_relative.y * sensitivity.y
			target_rot.x = clamp(target_rot.x, deg_to_rad(-90), deg_to_rad(90))


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_just_pressed("scroll_in"):
			if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
				target_camera_pos.z -= 1*zoom_sensitivity
				if target_camera_pos.z <= 0: target_camera_pos.z = 0
			elif camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
				target_camera_size -= 1*zoom_sensitivity
				if target_camera_size <= 0: target_camera_size = 0
		if Input.is_action_just_pressed("scroll_out"):
			if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
				target_camera_pos.z += 1*zoom_sensitivity
			elif camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
				target_camera_size += 1*zoom_sensitivity
	
	camera.position = lerp(camera.position, target_camera_pos, camera_lerp_speed*delta)
	camera.size = lerp(camera.size, target_camera_size, camera_lerp_speed*delta)
	rotation = lerp(rotation, target_rot, camera_lerp_speed*delta)
