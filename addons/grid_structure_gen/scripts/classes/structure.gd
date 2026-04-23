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
