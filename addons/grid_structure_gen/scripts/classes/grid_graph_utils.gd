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

## Returns true if a cell is considered a "solid" (non-empty, collapsed) tile.
static func is_solid(cell: StructureGenerator.Cell) -> bool:
	return cell.is_collapsed and cell.final_state != Structure.EMPTY_CELL and cell.final_state != &""

## Finds all connected components (graphs) of solid cells.[br]
## Returns an Array of Arrays, where each inner Array contains the Vector3i positions of the cells in that component, sorted largest-first.
static func find_components(grid: Dictionary) -> Array:
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
			for offset: Vector3i in DIR_OFFSETS:
				var neighbor_pos: Vector3i = current + offset
				if visited.has(neighbor_pos):
					continue
				if not grid.has(neighbor_pos):
					continue
				var neighbor: StructureGenerator.Cell = grid[neighbor_pos]
				if not is_solid(neighbor):
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

## Erases all cells in the given component from the grid (sets them to EMPTY, uncollapsed).
static func erase_component(grid: Dictionary, component: Array) -> void:
	for pos: Vector3i in component:
		if not grid.has(pos):
			continue
		var cell: StructureGenerator.Cell = grid[pos]
		cell.is_collapsed = true
		cell.final_state = Structure.EMPTY_CELL
		cell.possible_states = { Structure.EMPTY_CELL: 1.0 }
