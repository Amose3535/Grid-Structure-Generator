extends Button

func _ready() -> void:
	pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	var camera: Camera3D = get_window().get_camera_3d()
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		text = "Perspective mode: Perspective"
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		text = "Perspective mode: Orthogonal"
