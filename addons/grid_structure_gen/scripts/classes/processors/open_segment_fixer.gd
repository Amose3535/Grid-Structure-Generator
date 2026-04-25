# open_segment_fixer.gd
extends GridProcessorBaseType
class_name OpenSegmentFixer
## INTENDED FOR POST-PROCESSOR USE OLY.
##
## It works by finding solid cells whose actual connections (based on solid neighborsin the grid) don't match the connection profile of their assigned segment, and replacesthem with a segment whose profile matches the real connectivity.[br]
##[br]
## "Open face" = the segment's directional dictionary contains at least one non-EMPTY state.[br]
## "Connected face" = the neighbor in that direction is a solid cell in the grid.[br]

@export var debug: bool = false

## Precomputed map of type: connection_profile -> Array of candidate state names.[br]
## NOTE: connection_profile is a bitmask: bit 0=forward, 1=backward, 2=left, 3=right, 4=up, 5=down
var _profile_to_states: Dictionary = {}

const DIR_OFFSETS := {
	&"forward":  Vector3i(0, 0, -1),
	&"backward": Vector3i(0, 0,  1),
	&"left":     Vector3i(-1, 0, 0),
	&"right":    Vector3i(1, 0,  0),
	&"up":       Vector3i(0, 1,  0),
	&"down":     Vector3i(0, -1, 0),
}
const DIR_BITS := {
	&"forward": 0, &"backward": 1,
	&"left": 2,   &"right": 3,
	&"up": 4,     &"down": 5,
}

func process_grid(grid: Dictionary) -> Dictionary:
	_build_profile_map()
	
	var changed: bool = true
	while changed:
		changed = false
		for pos: Vector3i in grid:
			var cell: StructureGenerator.Cell = grid[pos]
			if not GridGraphUtils.is_solid(cell):
				continue
			
			var real_profile: int = _get_real_profile(grid, pos)
			var current_profile: int = _get_segment_profile(cell.final_state)
			
			if real_profile == current_profile:
				continue
			
			var candidates: Array = _profile_to_states.get(real_profile, [])
			if candidates.is_empty():
				if debug:
					push_warning("OpenSegmentFixer: no segment matches profile %s at %s. Leaving as-is." \
						% [_profile_to_string(real_profile), str(pos)])
				continue
			
			var chosen: StringName = _pick_weighted(candidates)
			cell.final_state = chosen
			cell.possible_states = { chosen: 1.0 }
			changed = true
			if debug:
				print("OpenSegmentFixer: %s → %s at %s" % [cell.final_state, chosen, str(pos)])
	
	return grid

# Builds _profile_to_states once before the main loop, so we don't recompute per-cell.
func _build_profile_map() -> void:
	_profile_to_states.clear()
	for state_name: StringName in structure.structure_sections:
		var profile: int = _get_segment_profile(state_name)
		if not _profile_to_states.has(profile):
			_profile_to_states[profile] = []
		_profile_to_states[profile].append(state_name)

# Returns the bitmask of OPEN faces for a given segment state.
# A face is "open" if its dictionary has at least one non-EMPTY state.
func _get_segment_profile(state_name: StringName) -> int:
	if not structure.structure_sections.has(state_name):
		return 0
	var segment: StructureSegment = structure.structure_sections[state_name]
	var profile: int = 0
	for dir: StringName in DIR_BITS:
		var connections: Dictionary = segment.get(dir)
		var is_open: bool = false
		for neighbor_state: StringName in connections:
			if neighbor_state != Structure.EMPTY_CELL:
				is_open = true
				break
		if is_open:
			profile |= (1 << DIR_BITS[dir])
	return profile

## Returns the bitmask of CONNECTED faces based on actual solid neighbors in the grid.
func _get_real_profile(grid: Dictionary, pos: Vector3i) -> int:
	var profile: int = 0
	var cell: StructureGenerator.Cell = grid[pos]
	for dir: StringName in DIR_OFFSETS:
		var offset: Vector3i = DIR_OFFSETS[dir]
		var neighbor_pos: Vector3i = pos + offset
		if not grid.has(neighbor_pos):
			continue
		var neighbor_cell: StructureGenerator.Cell = grid[neighbor_pos]
		if GridGraphUtils.are_logically_connected(structure, cell, neighbor_cell, offset):
			profile |= (1 << DIR_BITS[dir])
	return profile

# Picks a random state from candidates (uniform — you could add weights if needed).
func _pick_weighted(candidates: Array) -> StringName:
	return candidates[randi() % candidates.size()]

# Debug helper: prints a profile bitmask as human-readable face names.
func _profile_to_string(profile: int) -> String:
	var open_faces: Array[String] = []
	for dir: StringName in DIR_BITS:
		if profile & (1 << DIR_BITS[dir]):
			open_faces.append(dir)
	return "[%s]" % ", ".join(open_faces) if not open_faces.is_empty() else "[isolated]"
