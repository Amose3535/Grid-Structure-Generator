# structure_pipeline.gd
extends RefCounted
class_name StructurePipeline
## Orchestrates GridProcessors around WFC generation.
##
## Usage:[codeblock]
##   var pipeline := StructurePipeline.new(my_structure, Vector3i(10, 3, 10))
##   pipeline.add_pre_processor(RoomInstantiator.new())
##   pipeline.add_post_processor(RoomCuller.new(5))
##   pipeline.add_post_processor(GraphJoiner.new(2))
##   pipeline.add_post_processor(StructureDefiner.new())
##   var run_mode: RunMode = RunMode.FULL
##   var node: Node3D = await pipeline.run(run_mode)
##   if node:
##       add_child(node)
## [/codeblock]

## Emitted when the full pipeline finishes. Carries the final Node3D, or null on failure.
signal pipeline_finished(result_node: Node3D)

## How should the pipeline run
enum RunMode {
	FULL, ## In full mode, the pipeline returns the nodes pregenerated
	GRID, ## In grid mode, the pipeline returns only the grid. It requires manual generation
}

var _structure: Structure
var _bounds: Vector3i
var _pre_processors: Array[GridProcessorBaseType] = []
var _post_processors: Array[GridProcessorBaseType] = []

func _init(structure: Structure, bounds: Vector3i) -> void:
	_structure = structure
	_bounds = bounds

## Add a processor to run BEFORE the WFC algorithm.
func add_pre_processor(processor: GridProcessorBaseType) -> void:
	_inject_context(processor)
	_pre_processors.append(processor)

## Add a processor to run AFTER the WFC algorithm.
func add_post_processor(processor: GridProcessorBaseType) -> void:
	_inject_context(processor)
	_post_processors.append(processor)

func _inject_context(processor: GridProcessorBaseType) -> void:
	processor.structure = _structure
	processor.grid_bounds = _bounds

## Runs the FULL pipeline. Returns the final Node3D, or null on failure.
## Always call with await.[br]
## NOTE: When run_mode isn't set correctly (invalid enum, or int), it will return the grid, NOT the node!
func run(run_mode: RunMode = RunMode.FULL) -> Variant:
	# Step 1) build the WFC generator
	var generator := StructureGenerator.new(_structure, _bounds)
	var current_grid: Dictionary = generator.grid
	
	# Step 2) pre-processors
	for processor: GridProcessorBaseType in _pre_processors:
		current_grid = await _run_one(processor, current_grid)
		if current_grid.is_empty():
			push_error("StructurePipeline: pre-processor '%s' aborted the pipeline."% processor.get_script().resource_path)
			pipeline_finished.emit(null)
			return null
	
	# Step 3) WFC generation (async, on worker thread)
	generator.grid = current_grid
	
	WorkerThreadPool.add_task(generator.generate_async)
	current_grid = await generator.generation_finished
	
	if current_grid.is_empty():
		push_error("StructurePipeline: WFC generation failed (contradiction or max backtracks).")
		pipeline_finished.emit(null)
		return null
	
	# Step 4) post-processors
	for processor: GridProcessorBaseType in _post_processors:
		current_grid = await _run_one(processor, current_grid)
		if current_grid.is_empty():
			push_error("StructurePipeline: post-processor '%s' aborted the pipeline."% processor.get_script().resource_path)
			pipeline_finished.emit(null)
			return null
	
	# Step 5) Return corresponding request.
	match run_mode:
		RunMode.FULL:
			var result_node: Node3D = generator._build_3d_structure(current_grid)
			pipeline_finished.emit(result_node)
			return result_node
		
		RunMode.GRID:
			return current_grid
		
		_:
			return current_grid



## Runs a single processor and awaits its signal, regardless of sync/async.
func _run_one(processor: GridProcessorBaseType, grid: Dictionary) -> Dictionary:
	processor.run(grid)
	return await processor.processing_finished
