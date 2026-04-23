extends Node3D



@export var test_structure: Structure = null
@export var structure_size: Vector3i = Vector3i(5,5,5)
@export var center_structure: bool = true

@export var generate_async: bool = true


var structure_origin: Node3D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if !structure_origin:
		structure_origin = Node3D.new()
		structure_origin.position = Vector3.ZERO
		add_child(structure_origin)
	if center_structure:
		structure_origin.global_position -= (Vector3(structure_size)*test_structure.grid_size)/2 - Vector3.ONE*test_structure.grid_size/2
		#print(structure_origin.global_position)
	
	_generate_structure()


func _generate_structure() -> void:
	if !structure_origin: return
	
	var generator: StructureGenerator = StructureGenerator.new(test_structure, structure_size)
	
	
	var modified_grid: Dictionary[Vector3i, StructureGenerator.Cell]
	if generate_async:
		WorkerThreadPool.add_task(generator.generate_async) # Asynchronous approach
		modified_grid = await generator.generation_finished
		_clear_children()
	else:
		modified_grid = generator.generate() # Synchronous approach
	
	# Insert post processing here <-
	var outcome: Node3D = generator._build_3d_structure(modified_grid)
	if outcome:
		structure_origin.add_child(outcome)
	else:
		print("Generazione fallita")


func _clear_children() -> void:
	var child_nodes: Array[Node] = structure_origin.get_children()
	for child:Node in child_nodes:
		child.queue_free()

func _on_regenerate_button_pressed() -> void:
	%Re_Generate_button.disabled = true
	await _generate_structure()
	%Re_Generate_button.disabled = false
