# graph_joiner.gd
extends GridProcessorBaseType
class_name GraphJoiner
## INTENDED TO BE USED AS POST-PROCESSOR
##
## It Tries to physically connect disconnected solid components by carving a path of solid cells through empty space.[br]
##[br]
## Algorithm used for join attempt:[br]
##   1. Find the two largest components.[br]
##   2. Pick the closest pair of endpoint cells within [member max_path_length] Manhattan distance.[br]
##   3. Run A* through EMPTY cells only, capped at [member max_path_length] steps.[br]
##   4. Fill the path (including endpoints) with [member connector_state].[br]
##   5. Repeat for the next pair if step 3-4 fails (up to [member max_endpoint_pairs] tries).[br]
##   6. Repeat the whole thing [member join_count] times.[br]
##[br]
## Usage:[br]
## [codeblock]
## pipeline.add_post_processor(GraphJoiner.new(2))                     # join 2 pairs, default max length
## pipeline.add_post_processor(GraphJoiner.new(1, &"corridor", 10, 8)) # max corridor length of 8 cells
## [/codeblock]

## How many times to attempt joining two components.
@export var join_count: int = 1
## The state name to use for the carved path cells.
@export var connector_state: StringName = &""
## Max endpoint pairs to try per join before giving up on that component pair.
@export var max_endpoint_pairs: int = 5
## Maximum allowed path length in cells (Manhattan distance pre-filter + A* g-score cap).
## Pairs whose straight-line Manhattan distance already exceeds this are skipped entirely.
## Set to 0 to disable the limit.
@export var max_path_length: int = 10
@export var debug: bool = false

func _init(_join_count: int = 1,_connector_state: StringName = &"",_max_endpoint_pairs: int = 5,_max_path_length: int = 1) -> void:
	join_count = _join_count
	connector_state = _connector_state
	max_endpoint_pairs = _max_endpoint_pairs
	max_path_length = _max_path_length

func process_grid(grid: Dictionary) -> Dictionary:
	# Resolve connector state: if not provided, use the first available non-EMPTY state
	var conn_state: StringName = connector_state
	if conn_state == &"" or (conn_state != Structure.EMPTY_CELL and not structure.structure_sections.has(conn_state)):
		if structure.structure_sections.is_empty():
			push_error("GraphJoiner: no states defined in structure. Cannot join.")
			return grid
		conn_state = structure.structure_sections.keys()[0]
	
	for _i in range(join_count):
		var components: Array = GridGraphUtils.find_components(grid)
		if components.size() < 2:
			if debug: print("GraphJoiner: only one component left, stopping early.")
			break
		
		var comp_a: Array = components[0]
		var comp_b: Array = components[1]
		
		if not _try_join(grid, comp_a, comp_b, conn_state):
			if debug: print("GraphJoiner: could not find a valid path between the two largest components.")
	
	return grid

## Tries up to max_endpoint_pairs closest pairs (within max_path_length), runs A* on each.
func _try_join(grid: Dictionary, comp_a: Array, comp_b: Array, conn_state: StringName) -> bool:
	var pairs: Array = []
	for pos_a: Vector3i in comp_a:
		for pos_b: Vector3i in comp_b:
			var diff: Vector3i = pos_b - pos_a
			var manhattan: int = absi(diff.x) + absi(diff.y) + absi(diff.z)
			# Pre-filter: skip pairs whose straight-line distance already exceeds the limit
			if max_path_length > 0 and manhattan > max_path_length:
				continue
			var dist_sq: int = diff.x*diff.x + diff.y*diff.y + diff.z*diff.z
			pairs.append([dist_sq, pos_a, pos_b])
	
	if pairs.is_empty():
		if debug: print("GraphJoiner: no endpoint pairs within max_path_length=%d. Skipping." % max_path_length)
		return false
	
	pairs.sort_custom(func(a, b): return a[0] < b[0])
	
	var attempts: int = mini(max_endpoint_pairs, pairs.size())
	for i in range(attempts):
		var pos_a: Vector3i = pairs[i][1]
		var pos_b: Vector3i = pairs[i][2]
		var path: Array = _astar(grid, pos_a, pos_b)
		if not path.is_empty():
			_carve_path(grid, path, conn_state)
			if debug: print("GraphJoiner: connected %s -> %s (%d cells carved)." % [str(pos_a), str(pos_b), path.size()])
			return true
	
	return false

## A* through the grid. Only traverses empty (non-solid) intermediate cells.
## Aborts any path whose g-score exceeds max_path_length.
func _astar(grid: Dictionary, start: Vector3i, goal: Vector3i) -> Array:
	var open_set: Array = [[_heuristic(start, goal), 0, start]]
	var g_score: Dictionary = { start: 0 }
	var came_from: Dictionary = {}
	
	while not open_set.is_empty():
		var best_idx: int = 0
		for i in range(1, open_set.size()):
			if open_set[i][0] < open_set[best_idx][0]:
				best_idx = i
		var current_entry: Array = open_set[best_idx]
		open_set.remove_at(best_idx)
		
		var current: Vector3i = current_entry[2]
		
		if current == goal:
			return _reconstruct_path(came_from, current)
		
		var g: int = g_score.get(current, 999999)
		
		for offset: Vector3i in GridGraphUtils.DIR_OFFSETS:
			var neighbor: Vector3i = current + offset
			if not grid.has(neighbor):
				continue # out of bounds = impassable
			
			# Intermediate cells must be empty. Only the goal (solid) is the exception.
			var neighbor_cell: StructureGenerator.Cell = grid[neighbor]
			if neighbor != goal and GridGraphUtils.is_solid(neighbor_cell):
				continue
			
			var tentative_g: int = g + 1
			
			# Cap: don't explore paths longer than max_path_length
			if max_path_length > 0 and tentative_g > max_path_length:
				continue
			
			if tentative_g < g_score.get(neighbor, 999999):
				g_score[neighbor] = tentative_g
				came_from[neighbor] = current
				var f: int = tentative_g + _heuristic(neighbor, goal)
				open_set.append([f, tentative_g, neighbor])
	
	return []  # no path found within the length limit

func _heuristic(a: Vector3i, b: Vector3i) -> int:
	var d: Vector3i = (b - a).abs()
	return d.x + d.y + d.z

func _reconstruct_path(came_from: Dictionary, current: Vector3i) -> Array:
	var path: Array = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path

## Fills all cells in the path with conn_state (endpoints included).
func _carve_path(grid: Dictionary, path: Array, conn_state: StringName) -> void:
	for pos: Vector3i in path:
		if not grid.has(pos):
			continue
		var cell: StructureGenerator.Cell = grid[pos]
		cell.is_collapsed = true
		cell.final_state = conn_state
		cell.possible_states = { conn_state: 1.0 }
