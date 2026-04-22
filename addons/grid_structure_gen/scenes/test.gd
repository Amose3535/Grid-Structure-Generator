extends Node3D



@export var test_structure: Structure = null
@export var structure_size: Vector3i = Vector3i(5,5,5)
@export var center_structure: bool = true

@export var structure_origin: Node3D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if !structure_origin:
		structure_origin = Node3D.new()
		add_child(structure_origin)
	if center_structure:
		structure_origin.global_position -= (Vector3(structure_size)*test_structure.grid_size)/2 - Vector3.ONE*test_structure.grid_size/2
		print(structure_origin.global_position)
	var generator: StructureGenerator = StructureGenerator.new(test_structure, structure_size)
	if generator.generate():
		generator.instantiate_in_world(structure_origin)
	else:
		print("Generazione fallita")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
