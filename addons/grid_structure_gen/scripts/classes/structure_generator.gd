# structure_generator.gd
extends RefCounted
class_name StructureGenerator

## Signal emitted when generate_async finishes generating the logical structure
signal generation_finished(result_grid: Dictionary[Vector3i, Cell])

## The resource of the structure needed to be generated
var structure: Structure
## How many cells there are for any given direction (X, Y, and Z)
var grid_bounds: Vector3i
## Direction mapping
const DIR_VECTORS : Dictionary[Vector3i, StringName]= {
	Vector3i(0, 0, -1): Structure.FORWARD,
	Vector3i(0, 0, 1): Structure.BACKWARD,
	Vector3i(-1, 0, 0): Structure.LEFT,
	Vector3i(1, 0, 0): Structure.RIGHT,
	Vector3i(0, 1, 0): Structure.UP,
	Vector3i(0, -1, 0): Structure.DOWN
}

const OPPOSITE_DIRS = {
	Structure.FORWARD: Structure.BACKWARD,
	Structure.BACKWARD: Structure.FORWARD,
	Structure.LEFT: Structure.RIGHT,
	Structure.RIGHT: Structure.LEFT,
	Structure.UP: Structure.DOWN,
	Structure.DOWN: Structure.UP
}

## Logic grid that maps Vector3i to the cells
var grid: Dictionary[Vector3i, Cell] = {}

## Pre-computed matrix of all the rules
## FORMAT: rules[stato_A][direzione] = { stato_B: peso }
var rules: Dictionary[StringName,Dictionary] = {}

##M in-Heap for entropy tracking.[br]
## Stores [entropy, cell_pos] so we can always get the lowest entropy cell in O(log n).
var _entropy_heap: Array = []

## Internal cell class
class Cell:
	var position: Vector3i
	var possible_states: Dictionary[StringName, float]
	var is_collapsed: bool = false
	var final_state: StringName = &""
	
	func get_entropy() -> int:
		return possible_states.size()


func _init(_structure: Structure, _bounds: Vector3i):
	structure = _structure
	grid_bounds = _bounds
	_build_rules()
	_initialize_grid()


func _build_rules():
	var all_states: Array[StringName] = structure.structure_sections.keys().duplicate()
	all_states.append(structure.EMPTY_CELL)
	
	for state: StringName in all_states:
		rules[state] = {}
		for dir in DIR_VECTORS.values():
			rules[state][dir] = {}
			
	for state in structure.structure_sections.keys():
		var segment: StructureSegment = structure.structure_sections[state]
		for dir in DIR_VECTORS.values():
			var connections = segment.get(dir)
			if connections == null or connections.is_empty():
				rules[state][dir][structure.EMPTY_CELL] = 1.0
			else:
				for neighbor in connections:
					rules[state][dir][neighbor] = connections[neighbor]
					
	for dir:StringName in DIR_VECTORS.values():
		rules[structure.EMPTY_CELL][dir][structure.EMPTY_CELL] = 1.0
		
	for state_A in all_states:
		for dir in rules[state_A]:
			var opposite_dir = OPPOSITE_DIRS[dir]
			for state_B in rules[state_A][dir]:
				var weight = rules[state_A][dir][state_B]
				if not rules[state_B][opposite_dir].has(state_A):
					rules[state_B][opposite_dir][state_A] = weight

func _initialize_grid():
	var all_states: Dictionary[StringName, float] = {}
	for key:StringName in structure.structure_sections.keys():
		all_states[key] = 1.0
	all_states[structure.EMPTY_CELL] = 1.0
	
	for x:int in range(grid_bounds.x):
		for y:int in range(grid_bounds.y):
			for z:int in range(grid_bounds.z):
				var pos: Vector3i = Vector3i(x, y, z)
				var cell: Cell = Cell.new()
				cell.position = pos
				cell.possible_states = all_states.duplicate()
				grid[pos] = cell
	
	# Build the initial heap with all cells
	_rebuild_entropy_heap()


#region Min-Heap
func _rebuild_entropy_heap() -> void:
	_entropy_heap.clear()
	for pos in grid:
		var cell: Cell = grid[pos]
		if not cell.is_collapsed:
			_heap_push([cell.get_entropy(), pos])

func _heap_push(item: Array) -> void:
	_entropy_heap.push_back(item)
	var i: int = _entropy_heap.size() - 1
	while i > 0:
		var parent: int = (i - 1) / 2
		if _entropy_heap[parent][0] > _entropy_heap[i][0]:
			var tmp = _entropy_heap[parent]
			_entropy_heap[parent] = _entropy_heap[i]
			_entropy_heap[i] = tmp
			i = parent
		else:
			break

func _heap_pop() -> Array:
	if _entropy_heap.is_empty():
		return []
	var top = _entropy_heap[0]
	var last = _entropy_heap.pop_back()
	if not _entropy_heap.is_empty():
		_entropy_heap[0] = last
		var i: int = 0
		while true:
			var smallest: int = i
			var l: int = 2 * i + 1
			var r: int = 2 * i + 2
			if l < _entropy_heap.size() and _entropy_heap[l][0] < _entropy_heap[smallest][0]:
				smallest = l
			if r < _entropy_heap.size() and _entropy_heap[r][0] < _entropy_heap[smallest][0]:
				smallest = r
			if smallest == i:
				break
			var tmp = _entropy_heap[smallest]
			_entropy_heap[smallest] = _entropy_heap[i]
			_entropy_heap[i] = tmp
			i = smallest
	return top
#endregion Min-Heap


## Get lowest entropy uncollapsed cell using the heap. Stale entries (already collapsed or outdated entropy) are skipped lazily.
func _get_lowest_entropy_cell() -> Cell:
	while not _entropy_heap.is_empty():
		var top: Array = _heap_pop()
		var pos: Vector3i = top[1]
		if not grid.has(pos):
			continue
		var cell: Cell = grid[pos]
		# Skip stale entries: collapsed or entropy changed since insertion
		if cell.is_collapsed:
			continue
		if cell.get_entropy() != top[0]:
			# Re-insert with the current entropy and keep looking
			_heap_push([cell.get_entropy(), pos])
			continue
		return cell
	return null


## Restores all states that were removed during a propagation step.
func _undo_diff(removed_states: Array) -> void:
	for entry in removed_states:
		var cell: Cell = grid[entry.pos]
		cell.possible_states[entry.state] = entry.weight
		# If the cell was left with 0 states it may have been marked; unmark it
		if cell.is_collapsed and cell.get_entropy() > 1:
			cell.is_collapsed = false
			cell.final_state = &""


func _collapse_cell(cell: Cell, provided_state: StringName) -> void:
	cell.is_collapsed = true
	cell.final_state = provided_state
	cell.possible_states = { provided_state: cell.possible_states[provided_state] }


## _propagate records every removal as a diff entry,and uses a Dictionary-based visited set (instead of Array.has())
func _propagate(start_cell: Cell, removed_states: Array) -> void:
	var stack: Array[Cell] = [start_cell]
	# Dictionary as O(1) visited set instead of Array.has() O(n)
	var in_stack: Dictionary = { start_cell.position: true }
	
	while not stack.is_empty():
		var current_cell: Cell = stack.pop_back()
		in_stack.erase(current_cell.position)
		
		for dir_vec: Vector3i in DIR_VECTORS:
			var neighbor_pos: Vector3i = current_cell.position + dir_vec
			if not grid.has(neighbor_pos):
				continue
				
			var neighbor: Cell = grid[neighbor_pos]
			if neighbor.is_collapsed:
				continue
				
			var dir_name: StringName = DIR_VECTORS[dir_vec]
			var possible_neighbor_states_now: Dictionary = _get_valid_neighbors_for_states(
				current_cell.possible_states.keys(), dir_name
			)
			
			var changed: bool = false
			for state in neighbor.possible_states.keys().duplicate():
				if not possible_neighbor_states_now.has(state):
					# OPT 1: Record the removal in the diff before erasing
					removed_states.append({
						"pos": neighbor_pos,
						"state": state,
						"weight": neighbor.possible_states[state]
					})
					neighbor.possible_states.erase(state)
					changed = true
			
			if changed:
				# Push updated entropy into heap
				_heap_push([neighbor.get_entropy(), neighbor_pos])
				if not in_stack.has(neighbor_pos):
					in_stack[neighbor_pos] = true
					stack.append(neighbor)


func _get_valid_neighbors_for_states(current_states: Array[StringName], dir_name: String) -> Dictionary:
	var valid_states: Dictionary = {}
	for state: StringName in current_states:
		var allowed_neighbors: Dictionary = rules[state][dir_name]
		for neighbor: StringName in allowed_neighbors:
			if valid_states.has(neighbor):
				valid_states[neighbor] = max(valid_states[neighbor], allowed_neighbors[neighbor])
			else:
				valid_states[neighbor] = allowed_neighbors[neighbor]
	return valid_states


func _get_weighted_random_state(states: Dictionary[StringName,float]) -> StringName:
	var total_weight: float = 0.0
	for weight: float in states.values():
		total_weight += weight
		
	var roll: float = randf() * total_weight
	var current_weight: float = 0.0
	
	for state: StringName in states:
		current_weight += states[state]
		if roll <= current_weight:
			return state
	
	return states.keys()[0]


func _place_seed_tile() -> void:
	var start_pos: Vector3i = Vector3i(grid_bounds.x / 2, 0, grid_bounds.z / 2)
	if not grid.has(start_pos):
		return
	
	var start_cell: Cell = grid[start_pos]
	var total_seed_weight: float = 0.0
	var available_seeds: Dictionary = {}
	
	for state_name in structure.structure_sections.keys():
		var segment: StructureSegment = structure.structure_sections[state_name]
		if segment.seed_weight > 0.0:
			available_seeds[state_name] = segment.seed_weight
			total_seed_weight += segment.seed_weight
	
	if total_seed_weight <= 0.0:
		return
	
	var roll = randf() * total_seed_weight
	var current_weight: float = 0.0
	var chosen_seed: StringName = &""
	
	for state_name in available_seeds:
		current_weight += available_seeds[state_name]
		if roll <= current_weight:
			chosen_seed = state_name
			break
	
	start_cell.is_collapsed = true
	start_cell.final_state = chosen_seed
	start_cell.possible_states = { chosen_seed: 1.0 }
	
	var dummy_removed: Array = []
	_propagate(start_cell, dummy_removed)
	# Seed propagation changes are not tracked for backtracking (seed is fixed)

## Generates the grid structure.[br]It records the states that were removed during each propagation step. When a contradiction is found, it undoes it simply by putting them back. 
func generate() -> Dictionary:
	_place_seed_tile()
	
	# Each history entry: { cell_pos, chosen_state, removed_states }
	# removed_states: Array of { pos: Vector3i, state: StringName, weight: float }
	var history: Array = []
	var max_backtracks: int = 10000
	var backtracks_done: int = 0
	
	# Generation iterative notation of recursive implementation for WFC
	while true:
		var cell_to_collapse: Cell = _get_lowest_entropy_cell()
		
		if cell_to_collapse == null:
			break
		
		#region CONTRADICTION
		if cell_to_collapse.get_entropy() == 0:
			push_error("WFC Contradiction at: %s. BACKTRACKING!" % str(cell_to_collapse.position))
			backtracks_done += 1
			if backtracks_done > max_backtracks:
				push_error("Max backtracks reached!")
				return {}
			
			var backtracked: bool = false
			
			while history.size() > 0:
				var last_step: Dictionary = history.pop_back()
				
				# Undo only the changes from this step
				_undo_diff(last_step.removed_states)
				
				# Uncollapse the cell that was collapsed in this step
				var past_cell: Cell = grid[last_step.cell_pos]
				past_cell.is_collapsed = false
				past_cell.final_state = &""
				# The undo restored all its states; now ban the bad choice
				past_cell.possible_states.erase(last_step.chosen_state)
				
				if past_cell.get_entropy() > 0:
					var new_choice: StringName = _get_weighted_random_state(past_cell.possible_states)
					var removed: Array = []
					
					past_cell.is_collapsed = true
					past_cell.final_state = new_choice
					past_cell.possible_states = { new_choice: past_cell.possible_states[new_choice] }
					
					_propagate(past_cell, removed)
					history.push_back({
						"cell_pos": past_cell.position,
						"chosen_state": new_choice,
						"removed_states": removed
					})
					# Re-push the past_cell into the heap after state change
					_heap_push([past_cell.get_entropy(), past_cell.position])
					backtracked = true
					break
			
			if not backtracked:
				push_error("Fallimento totale: nessuna configurazione valida rimasta.")
				return {}
			
			continue
		#endregion CONTRADICTION
		
		#region Normal collapse
		var chosen_state: StringName = _get_weighted_random_state(cell_to_collapse.possible_states)
		var removed: Array = []
		
		_collapse_cell(cell_to_collapse, chosen_state)
		_propagate(cell_to_collapse, removed)
		
		history.push_back({
			"cell_pos": cell_to_collapse.position,
			"chosen_state": chosen_state,
			"removed_states": removed
		})
		#region Normal collapse
	
	return grid

## If you plan on using multithreading, CALL THIS function instead of generate()
func generate_async() -> void:
	var grid_result: Dictionary = generate()
	emit_signal.call_deferred("generation_finished", grid_result)


## This function generates the 3D scene given each cell.
func _build_3d_structure(from_grid: Dictionary[Vector3i, Cell] = grid) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "GeneratedStructure"
	var offset: float = structure.grid_size
	
	for pos:Vector3i in from_grid:
		var cell: Cell = from_grid[pos]
		if cell.final_state != structure.EMPTY_CELL and cell.final_state != &"":
			var segment_data = structure.structure_sections[cell.final_state]
			if segment_data.segment_scene:
				var instance: Node = segment_data.segment_scene.instantiate()
				root.add_child(instance)
				instance.position = Vector3(pos.x * offset, pos.y * offset, pos.z * offset)
				
	return root
