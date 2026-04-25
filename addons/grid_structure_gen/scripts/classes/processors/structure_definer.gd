# structure_definer.gd
extends GridProcessorBaseType
class_name StructureDefiner
## INTENDED TO BE USED AS POST PROCESSOR
## 
## Keeps only the single "dominant" component and erases everything else.[br]
##
## Dominant component selection rules (in order):[br]
##   1. The component with the most cells.[br]
##   2. If tied in cell count → the one with the largest axis-aligned bounding box volume.[br]
##   3. If still tied → one is chosen at random.[br]
##[br]
## Usage:[codeblock]
##   pipeline.add_post_processor(StructureDefiner.new())

@export var debug: bool = false

func process_grid(grid: Dictionary) -> Dictionary:
	var components: Array = GridGraphUtils.find_components(grid, structure)
	
	if components.size() <= 1:
		# Nothing to do: 0 or 1 component
		return grid
	
	# Find the dominant component
	var max_size: int = components[0].size()  # already sorted largest-first
	
	# Collect all components tied at max_size
	var candidates: Array = []
	for component: Array in components:
		if component.size() == max_size:
			candidates.append(component)
		else:
			break  # sorted, no need to continue
	
	var dominant: Array
	
	if candidates.size() == 1:
		dominant = candidates[0]
	else:
		# Tie-break by bounding box volume
		var max_volume: int = -1
		var volume_winners: Array = []
		for candidate: Array in candidates:
			var vol: int = GridGraphUtils.bounding_box_volume(candidate)
			if vol > max_volume:
				max_volume = vol
				volume_winners = [candidate]
			elif vol == max_volume:
				volume_winners.append(candidate)
		
		if volume_winners.size() == 1:
			dominant = volume_winners[0]
		else:
			# Final tie-break: random
			dominant = volume_winners[randi() % volume_winners.size()]
	
	# Erase everything that isn't the dominant component
	var erased: int = 0
	for component: Array in components:
		if component == dominant:
			continue
		GridGraphUtils.erase_component(grid, component)
		erased += 1
	
	if debug: print("StructureDefiner: kept dominant component (%d cells), erased %d other(s)."% [dominant.size(), erased])
	
	return grid
