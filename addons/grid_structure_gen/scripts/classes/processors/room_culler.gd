# room_culler.gd
extends GridProcessorBaseType
class_name RoomCuller
## INTENDED TO BE USED AS POST-PROCESSOR
##
## It removes all connected components (graphs of solid cells) that are smaller than [member min_size].
## Useful for cleaning up isolated 1-2 tile fragments left by WFC.
##
## Usage: [codeblock]
## pipeline.add_post_processor(RoomCuller.new(5))   # remove components < 5 cells
## [/codeblock]

## Minimum number of solid cells a component must have to survive.
@export var min_size: int = 4
@export var debug: bool = false

func _init(minimum_size: int = 4) -> void:
	min_size = minimum_size

## Function used to process the grid
func process_grid(grid: Dictionary) -> Dictionary:
	var components: Array = GridGraphUtils.find_components(grid)
	var culled: int = 0
	
	for component: Array in components:
		if component.size() < min_size:
			GridGraphUtils.erase_component(grid, component)
			culled += 1
	
	if culled > 0:
		if debug: print("RoomCuller: removed %d component(s) smaller than %d cells." % [culled, min_size])
	
	return grid
