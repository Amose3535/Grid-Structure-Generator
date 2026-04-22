# structure.gd
extends Resource
class_name Structure
## The file containing the fundamental data of the structure
##
## This file contains:[br]
## * Grid size.[br]
## * All the rooms of the structure.[br]

## The StringName of the default "Empty cell"
const EMPTY_CELL : StringName = &"EMPTY"

## The StringName of the FORWARD direction (-Z)
const FORWARD : StringName = &"forward"
## The StringName of the BACKWARD direction (+Z)
const BACKWARD : StringName = &"backward"
## The StringName of the LEFT direction (-X)
const LEFT : StringName = &"left"
## The StringName of the RIGHT direction (+X)
const RIGHT : StringName = &"right"
## The StringName of the UP direction (+Y)
const UP : StringName = &"up"
## The StringName of the DOWN direction (-Y)
const DOWN : StringName = &"down"


## Constant containing all relative directions in the grid
const DIRECTIONS: Dictionary[StringName, Vector3i] = {
	FORWARD:  Vector3i(0, 0, -1),
	BACKWARD: Vector3i(0, 0,  1),
	LEFT:     Vector3i(-1, 0, 0),
	RIGHT:    Vector3i(1,  0, 0),
	UP:       Vector3i(0,  1, 0),
	DOWN:     Vector3i(0, -1, 0),
}

## Constant containing all opposite directions, given any sinle one
const OPPOSITE: Dictionary[StringName,StringName] = {
	FORWARD: BACKWARD,
	BACKWARD: FORWARD,
	LEFT: RIGHT,
	RIGHT: LEFT,
	UP: DOWN,
	DOWN: UP,
}

## This will define the size of the cells of the grid. The grid is a cubic lattice whose fundamental cells are of size [code]Vector3(grid_size, grid_size, grid_size)[/code]
@export var grid_size: float = 1

## Dictionary of type StringName : StructureSegment. It generates a map of all segments to their respective official IDs
@export var structure_sections: Dictionary[StringName, StructureSegment] = {}


## This generates the compatibility table for the WFC in the case where the user didn't specify all room's possible connections.[br]
## Example:
##[code]
##var compat_table: Dictionary[String, Dictionary] = _build_compatibility_table()
##var compatible_segments: Array[StringName] = compat_table[segment][direction]
##[/code]
func _build_compatibility_table() -> Dictionary[String, Dictionary]:
	var table: Dictionary[String, Dictionary] = {}
	
	# Initialize an empty array for every face of the segment which corresponds to seg_id
	for seg_id: StringName in structure_sections:
		table[seg_id] = {
			FORWARD: [],
			BACKWARD: [],
			LEFT: [],
			RIGHT: [],
			UP: [],
			DOWN: []
		}
	
	for seg_id: StringName in structure_sections:
		var seg: StructureSegment = structure_sections[seg_id]
		# For every face of the current segment, register the forward and "backward" face
		_register_face(table, seg_id, seg.forward,  FORWARD,  BACKWARD)
		_register_face(table, seg_id, seg.backward, BACKWARD, FORWARD)
		_register_face(table, seg_id, seg.left,     LEFT,     RIGHT)
		_register_face(table, seg_id, seg.right,    RIGHT,    LEFT)
		_register_face(table, seg_id, seg.up,       UP,       DOWN)
		_register_face(table, seg_id, seg.down,     DOWN,     UP)
	
	_add_empty_to_table(table)
	
	return table


## Helper function employed by build_table, used to write 
func _register_face(table: Dictionary, seg_id: StringName, face_dict: Dictionary, dir: StringName, opposite: StringName) -> void:
	# How this works (i've been going crazy):
	# Iterate within the neighbors compatible with the that specific face
		# If the neighbor id is not declared in the structure_sections, skip this one: it's invalid.
		# If the neighbor id is not contained in that section with that face, add it
		# Then do the opposite: If the current segment id is not contained in the neigboring section at the opposite face, add it (useful to prevent user errors).
	
	for neighbor_id: StringName in face_dict:
		if not structure_sections.has(neighbor_id):
			push_warning("Segment '%s' referenced by '%s' doesn't exist in this structure: Skipping." % [neighbor_id, seg_id])
			continue
		
		# If the neighbor id is not contained in that section with that face, add it
		if not neighbor_id in table[seg_id][dir]:
			table[seg_id][dir].append(neighbor_id)
		
		# Then do the opposite: If the current segment id is not contained in the neigboring section at the opposite face, add it (useful to prevent user errors).
		if not seg_id in table[neighbor_id][opposite]:
			table[neighbor_id][opposite].append(seg_id)

## Adds the "EMPTY" field as a possible connection in every cell's face 
func _add_empty_to_table(table: Dictionary[String, Dictionary]) -> void:
	# EMPTY can be everywhere there's no explicit constraints
	# Every segment with an empty face can be compatible with EMPTY slot
	table[Structure.EMPTY_CELL] = {
		FORWARD: [], BACKWARD: [],
		LEFT: [], RIGHT: [],
		UP: [], DOWN: []
	}
	
	for seg_id in structure_sections:
		var seg: StructureSegment = structure_sections[seg_id]
		for dir in DIRECTIONS:
			var face_dict = _get_face(seg, dir)
			if face_dict.is_empty():
				# This face is closed (wall or dead end: EMPTY is compatible)
				table[seg_id][dir].append(Structure.EMPTY_CELL)
				table[Structure.EMPTY_CELL][OPPOSITE[dir]].append(seg_id)

## Returns the dictionary of the compatible segments given a direction and a segment.
static func _get_face(seg: StructureSegment, dir: StringName) -> Dictionary:
	match dir:
		FORWARD:  return seg.forward
		BACKWARD: return seg.backward
		LEFT:     return seg.left
		RIGHT:    return seg.right
		UP:       return seg.up
		DOWN:     return seg.down
	return {}
