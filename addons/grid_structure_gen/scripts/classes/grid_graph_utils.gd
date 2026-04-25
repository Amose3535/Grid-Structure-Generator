# grid_graph_utils.gd
extends RefCounted
class_name GridGraphUtils
## Static helpers for graph operations on a WFC Cell grid.
##
## Used internally by RoomCuller, GraphJoiner, and StructureDefiner.

const DIR_OFFSETS: Array[Vector3i] = [
	Vector3i(0, 0, -1),  # forward
	Vector3i(0, 0,  1),  # backward
	Vector3i(-1, 0, 0),  # left
	Vector3i( 1, 0, 0),  # right
	Vector3i(0,  1, 0),  # up
	Vector3i(0, -1, 0),  # down
]

## Maps each direction offset to the StringName used in StructureSegment exports.
const DIR_OFFSET_TO_NAME: Dictionary = {
	Vector3i(0, 0, -1): &"forward",
	Vector3i(0, 0,  1): &"backward",
	Vector3i(-1, 0, 0): &"left",
	Vector3i( 1, 0, 0): &"right",
	Vector3i(0,  1, 0): &"up",
	Vector3i(0, -1, 0): &"down",
}

## Returns true if a cell is considered a "solid" (non-empty, collapsed) tile.
static func is_solid(cell: StructureGenerator.Cell) -> bool:
	return cell.is_collapsed and cell.final_state != Structure.EMPTY_CELL and cell.final_state != &""

## Returns true if segment [param from_state] has at least one non-EMPTY connection
## on [param dir_name] (i.e. the face is logically open toward that direction).
static func is_face_open(structure: Structure, from_state: StringName, dir_name: StringName) -> bool:
	if not structure.structure_sections.has(from_state):
		return false
	var segment: StructureSegment = structure.structure_sections[from_state]
	var connections: Dictionary = segment.get(dir_name)
	for neighbor_state: StringName in connections:
		if neighbor_state != Structure.EMPTY_CELL:
			return true
	return false

## Returns true if cell A at [param pos_a] and cell B at [param pos_b] are logically
## connected: both must be solid, A's face toward B must be open, and B's face toward A
## must be open. [param offset] is the Vector3i from A to B.
static func are_logically_connected(structure: Structure, cell_a: StructureGenerator.Cell, cell_b: StructureGenerator.Cell, offset: Vector3i) -> bool:
	if not is_solid(cell_a) or not is_solid(cell_b):
		return false
	var dir_a_to_b: StringName = DIR_OFFSET_TO_NAME[offset]
	var dir_b_to_a: StringName = DIR_OFFSET_TO_NAME[-offset]
	return is_face_open(structure, cell_a.final_state, dir_a_to_b) \
		and is_face_open(structure, cell_b.final_state, dir_b_to_a)

## Finds all connected components (graphs) of solid cells.[br]
## Two adjacent solid cells belong to the same component only if both face each other
## with at least one non-EMPTY connection in their respective StructureSegment dictionaries.[br]
## Returns an Array of Arrays of Vector3i positions, sorted largest-first.
static func find_components(grid: Dictionary, structure: Structure) -> Array:
	var visited: Dictionary = {}
	var components: Array = []
	
	for pos: Vector3i in grid:
		if visited.has(pos):
			continue
		var cell: StructureGenerator.Cell = grid[pos]
		if not is_solid(cell):
			continue
		
		# BFS from this solid cell
		var component: Array[Vector3i] = []
		var queue: Array[Vector3i] = [pos]
		visited[pos] = true
		
		while not queue.is_empty():
			var current: Vector3i = queue.pop_front()
			component.append(current)
			var current_cell: StructureGenerator.Cell = grid[current]
			
			for offset: Vector3i in DIR_OFFSETS:
				var neighbor_pos: Vector3i = current + offset
				if visited.has(neighbor_pos):
					continue
				if not grid.has(neighbor_pos):
					continue
				var neighbor_cell: StructureGenerator.Cell = grid[neighbor_pos]
				# Logical connectivity check: both faces must be open toward each other
				if not are_logically_connected(structure, current_cell, neighbor_cell, offset):
					continue
				visited[neighbor_pos] = true
				queue.append(neighbor_pos)
		
		components.append(component)
	
	# Sort largest component first
	components.sort_custom(func(a, b): return a.size() > b.size())
	return components

## Returns the axis-aligned bounding box volume (x*y*z) of a set of positions.
static func bounding_box_volume(positions: Array) -> int:
	if positions.is_empty():
		return 0
	var min_p: Vector3i = positions[0]
	var max_p: Vector3i = positions[0]
	for pos: Vector3i in positions:
		min_p.x = mini(min_p.x, pos.x)
		min_p.y = mini(min_p.y, pos.y)
		min_p.z = mini(min_p.z, pos.z)
		max_p.x = maxi(max_p.x, pos.x)
		max_p.y = maxi(max_p.y, pos.y)
		max_p.z = maxi(max_p.z, pos.z)
	var size: Vector3i = max_p - min_p + Vector3i.ONE
	return size.x * size.y * size.z

## Erases all cells in the given component from the grid (sets them to EMPTY, collapsed).
static func erase_component(grid: Dictionary, component: Array) -> void:
	for pos: Vector3i in component:
		if not grid.has(pos):
			continue
		var cell: StructureGenerator.Cell = grid[pos]
		cell.is_collapsed = true
		cell.final_state = Structure.EMPTY_CELL
		cell.possible_states = { Structure.EMPTY_CELL: 1.0 }
