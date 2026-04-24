extends Button

func _ready() -> void:
	pressed.connect(_on_button_pressed)

var camera: Camera3D = null

func _on_button_pressed() -> void:
	camera = get_window().get_camera_3d()
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL

func _physics_process(delta: float) -> void:
	if !is_node_ready() or !camera: return
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		text = "Perspective mode: Orthogonal"
	else:
		text = "Perspective mode: Perspective"
	
