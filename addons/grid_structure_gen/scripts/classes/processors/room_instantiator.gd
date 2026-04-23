# room_instantiator.gd
extends GridProcessorBaseType
class_name RoomInstantiator
## INTENDED TO BE USED AS PRE-PROCESSOR.
##
## Force-collapses specific cells to specific states before WFC runs.[br]
## This "plants" known rooms at fixed positions; WFC then fills the rest while respecting these forced placements.
##
## Usage:
## [codeblock]
## var inst := RoomInstantiator.new()
## inst.place(&"entrance", Vector3i(5, 0, 5))
## inst.place(&"boss_room", Vector3i(0, 0, 0))
## inst.place_rect(&"EMPTY", Vector3i(3,0,3), Vector3i(6,0,6))  # carve an empty area
## pipeline.add_pre_processor(inst)
## [/codeblock]

## Each entry must be of type: { "pos": Vector3i, "state": StringName }
@export var _placements: Array[Dictionary] = [{"pos":Vector3i.ZERO, "state":&""}]

## Force a single cell at [param pos] to be [param state_name].
## [param state_name] must be a key in Structure.structure_sections, or Structure.EMPTY_CELL.
func place(state_name: StringName, pos: Vector3i) -> void:
	_placements.append({ "pos": pos, "state": state_name })

## Force an entire rectangular volume to [param state_name].
func place_rect(state_name: StringName, from: Vector3i, to: Vector3i) -> void:
	for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
		for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			for z in range(mini(from.z, to.z), maxi(from.z, to.z) + 1):
				place(state_name, Vector3i(x, y, z))

func process_grid(grid: Dictionary) -> Dictionary:
	for entry: Dictionary in _placements:
		var pos: Vector3i = entry.pos
		var state: StringName = entry.state
		
		if not grid.has(pos):
			push_warning("RoomInstantiator: position %s is out of bounds. Skipped." % str(pos))
			continue
		
		if state != Structure.EMPTY_CELL and not structure.structure_sections.has(state):
			push_warning("RoomInstantiator: state '%s' not found in structure. Skipped." % state)
			continue
		
		var cell: StructureGenerator.Cell = grid[pos]
		var weight: float = cell.possible_states.get(state, 1.0)
		cell.is_collapsed = true
		cell.final_state = state
		cell.possible_states = { state: weight }
	
	return grid
