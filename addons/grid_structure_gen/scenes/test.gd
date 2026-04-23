extends Node3D



@export var test_structure: Structure = null
@export var structure_size: Vector3i = Vector3i(5,5,5)
@export var pre_processors: Array[GridProcessorBaseType] = []
@export var post_processors: Array[GridProcessorBaseType] = []
@export var generate_async: bool = true
@export var center_structure: bool = true


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
	
	var node: Node3D = null
	
	if generate_async:
		var pipeline: StructurePipeline = StructurePipeline.new(test_structure, structure_size)
		for pre_processor:GridProcessorBaseType in pre_processors:
			pipeline.add_pre_processor(pre_processor)
		for post_processor:GridProcessorBaseType in post_processors:
			pipeline.add_post_processor(post_processor)
		node = await pipeline.run()
	else:
		var pipeline: StructurePipeline = StructurePipeline.new(test_structure, structure_size)
		node = await pipeline.run(false)
	
	if node:
		_clear_children()
		structure_origin.add_child(node)
	else:
		push_error("Generation failed :(")


func _clear_children() -> void:
	var child_nodes: Array[Node] = structure_origin.get_children()
	for child:Node in child_nodes:
		child.queue_free()

func _on_regenerate_button_pressed() -> void:
	%Re_Generate_button.disabled = true
	await _generate_structure()
	%Re_Generate_button.disabled = false
