# grid_processor_base_type.gd
extends Resource
class_name GridProcessorBaseType
## Base class for all GridProcessors.[br]
## A GridProcessor receives a grid (Dictionary[Vector3i, StructureGenerator.Cell]), modifies it, and signals completion via [signal processing_finished].
##
## To create a SYNC processor:  override [method process_grid].[br]
## To create an ASYNC processor: override [method is_async] (return true) and [method process_grid_async] (must emit processing_finished).[br]
## The pipeline calls [method run], you never call it manually!

## Emitted when processing is done. The pipeline awaits this signal.
signal processing_finished(result_grid: Dictionary)

## Set automatically by the pipeline before run() is called.
var structure: Structure
## Set automatically by the pipeline before run() is called.
var grid_bounds: Vector3i

## Override and return true if your processor uses WorkerThreadPool or other async work.
func is_async() -> bool:
	return false

## Override this for synchronous processors.[br]
## Receives the current grid, returns the modified grid.[br]
## Return an empty Dictionary {} to signal a fatal failure and abort the pipeline.
func process_grid(_grid: Dictionary) -> Dictionary:
	push_error("%s: process_grid() not implemented." % get_script().resource_path)
	return _grid

## Override this for asynchronous processors.[br]
## Must emit processing_finished(result_grid) when done.
func process_grid_async(_grid: Dictionary) -> void:
	push_error("%s: process_grid_async() not implemented." % get_script().resource_path)
	emit_signal.call_deferred("processing_finished", _grid)

## Called by the pipeline. [b]DO NOT OVERRIDE![/b]
func run(grid: Dictionary) -> void:
	if is_async():
		process_grid_async(grid)
	else:
		var result: Dictionary = process_grid(grid)
		emit_signal.call_deferred("processing_finished", result)
