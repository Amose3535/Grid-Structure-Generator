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

## Pre-computed matrix of all the rules[br]
## FORMAT: rules[stato_A][direzione] = { stato_B: peso } (=> Dictionary[StringName, Dictionary[StringName, Dictionary[StringName, float]]])
var rules: Dictionary[StringName,Dictionary] = {}

## Internal cell class
class Cell:
	## The relative position in the structure coordinates
	var position: Vector3i
	## 
	var possible_states: Dictionary[StringName, float] # StringName : float (weight)
	var is_collapsed: bool = false
	var final_state: StringName = &""
	
	func get_entropy() -> int:
		return possible_states.size()


func _init(_structure: Structure, _bounds: Vector3i):
	structure = _structure
	grid_bounds = _bounds
	_build_rules() # Pre-compute logical connections before building the grid
	_initialize_grid()

func _build_rules():
	var all_states: Array[StringName] = structure.structure_sections.keys().duplicate()
	all_states.append(structure.EMPTY_CELL)
	
	# Create empty structure
	for state: StringName in all_states:
		rules[state] = {}
		for dir in DIR_VECTORS.values():
			rules[state][dir] = {}
			
	# Populate rules based on segments.
	for state in structure.structure_sections.keys():
		var segment: StructureSegment = structure.structure_sections[state]
		for dir in DIR_VECTORS.values():
			var connections = segment.get(dir)
			
			# IF nothing is defined, by assumption, it should connect to EMPTY
			if connections == null or connections.is_empty():
				rules[state][dir][structure.EMPTY_CELL] = 1.0
			else:
				for neighbor in connections:
					rules[state][dir][neighbor] = connections[neighbor]
					
	# Ruleset for EMPTY cells: EMPTY always connects to EMPTY (IMPORTANT TO PREVENT ERRORS!!!!!!)
	for dir:StringName in DIR_VECTORS.values():
		rules[structure.EMPTY_CELL][dir][structure.EMPTY_CELL] = 1.0
		
	# Automatically force symmetry: If A wants B on its side, then  be should want A on the opposite side too (even if the user didn't define it) to prevent errors
	for state_A in all_states:
		for dir in rules[state_A]:
			var opposite_dir = OPPOSITE_DIRS[dir]
			for state_B in rules[state_A][dir]:
				var weight = rules[state_A][dir][state_B]
				
				if not rules[state_B][opposite_dir].has(state_A):
					rules[state_B][opposite_dir][state_A] = weight

func _initialize_grid():
	# Make a dictionary with all states and their initial weights (assume 1.0 if not specified otherwise)
	var all_states: Dictionary[StringName, float] = {}
	for key:StringName in structure.structure_sections.keys():
		all_states[key] = 1.0
	all_states[structure.EMPTY_CELL] = 1.0 # EMPTY is a valid state too
	
	for x:int in range(grid_bounds.x):
		for y:int in range(grid_bounds.y):
			for z:int in range(grid_bounds.z):
				var pos: Vector3i = Vector3i(x, y, z)
				var cell: Cell = Cell.new()
				cell.position = pos
				cell.possible_states = all_states.duplicate()
				grid[pos] = cell

## Function responsible for the WFC argorithm
func generate() -> Dictionary[Vector3i,Cell]:
	while true:
		var cell_to_collapse: Cell = _get_lowest_entropy_cell()
		
		# If there are no more cells to collapse, then it's done and the generation should stop
		if cell_to_collapse == null:
			break
			
		# If entropy == 0, there's a contradiction.
		# NOTE: Should backtrack but who cares am i right fellas?.
		if cell_to_collapse.get_entropy() == 0:
			push_error("WFC Contradiction at: ", cell_to_collapse.position)
			return {}
			
		_collapse_cell(cell_to_collapse)
		_propagate(cell_to_collapse)
		
	return grid

## If you plan on using multithreading, CALL THIS function instead of generate() as that one won't emit the necessary signal
func generate_async() -> void:
	# Wraps generate function
	var grid_result: Dictionary[Vector3i,Cell] = generate() 
	
	# Emit signal containing the necessary grid result
	emit_signal.call_deferred("generation_finished", grid_result)




## Function responsible for WFC logic
func _get_lowest_entropy_cell() -> Cell:
	var min_entropy: int = 999999
	var best_cells: Array[Cell] = []
	
	for pos:Vector3i in grid:
		var cell: Cell = grid[pos]
		if not cell.is_collapsed:
			var entropy: int = cell.get_entropy()
			if entropy < min_entropy:
				min_entropy = entropy
				best_cells = [cell]
			elif entropy == min_entropy:
				best_cells.append(cell)
				
	if best_cells.is_empty():
		return null
		
	# Choose random cell within the ones with minimum entropy
	return best_cells.pick_random()

func _collapse_cell(cell: Cell):
	var chosen_state: StringName = _get_weighted_random_state(cell.possible_states)
	cell.is_collapsed = true
	cell.final_state = chosen_state
	# Remove every other state other than the chosen one
	cell.possible_states = { chosen_state: cell.possible_states[chosen_state] }

func _propagate(start_cell: Cell):
	var stack: Array[Cell] = [start_cell]
	
	while not stack.is_empty():
		var current_cell: Cell = stack.pop_back()
		
		for dir_vec: Vector3i in DIR_VECTORS:
			var neighbor_pos: Vector3i = current_cell.position + dir_vec
			
			# Chech if the neighbor is within the grid
			if not grid.has(neighbor_pos):
				continue
				
			var neighbor: Cell = grid[neighbor_pos]
			if neighbor.is_collapsed:
				continue
				
			var dir_name: StringName = DIR_VECTORS[dir_vec]
			var possible_neighbor_states_now: Dictionary = _get_valid_neighbors_for_states(current_cell.possible_states.keys(), dir_name)
			
			var changed = false
			# Chech the neghbor' states: If they aren't allowed by the current cell, delete them
			for state in neighbor.possible_states.keys().duplicate():
				if not possible_neighbor_states_now.has(state):
					neighbor.possible_states.erase(state)
					changed = true
					
			# If the neighbor has changed its posible states, it must propagate
			if changed and not stack.has(neighbor):
				stack.append(neighbor)

## Helps propagate to find the valid neighbor states
func _get_valid_neighbors_for_states(current_states: Array[StringName], dir_name: String) -> Dictionary:
	var valid_states: Dictionary = {}
	
	for state: StringName in current_states:
		# Pick allowed neighbors from the rule matrix
		var allowed_neighbors: Dictionary = (rules[state][dir_name])
		
		for neighbor:StringName in allowed_neighbors:
			# If more than one states allow for this neighbor, preserve the weight (picking from the highest one of the two)
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
	
	return states.keys()[0] # Fallback

## This function generates the 3D scene given each cell. It can accept a modified grid (given its a valid one)
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
				# Place instance with consideraiton of the grid
				instance.position = Vector3(pos.x * offset, pos.y * offset, pos.z * offset)
				
	return root
