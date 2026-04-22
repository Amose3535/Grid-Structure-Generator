extends Node3D

@export var sensibility: Vector2 = Vector2(0.02,0.02)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotation.y -= (event as InputEventMouseMotion).screen_relative.x * sensibility.x
			rotation.x -= (event as InputEventMouseMotion).screen_relative.y * sensibility.y
			rotation.x = clamp(rotation.x, deg_to_rad(-90), deg_to_rad(90))


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	
