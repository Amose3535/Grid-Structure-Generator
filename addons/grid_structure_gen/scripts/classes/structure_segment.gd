# structure_segment.gd
extends Resource
class_name StructureSegment
## The necessary data of the segment of a structure.

## This is what will get instanced at the position of the cell whose corresponding segment is this one.
@export var segment_scene: PackedScene = null

@export_group("Generation criteria")
## The chances that this segment is chosen as seed for the WFC. (if it's seto to 0, then it will never be chosen as starting tile)
@export var seed_weight: float = 1.0
@export_subgroup("Directional Segments")
## What could get instanced in the -Z axis (forward)
@export var forward: Dictionary[StringName, float] = {}
## What could get instanced in the +Z axis (backward)
@export var backward: Dictionary[StringName, float] = {}
## What could get instanced in the -X axis (left)
@export var left: Dictionary[StringName, float] = {}
## What could get instanced in the +X axis (right)
@export var right: Dictionary[StringName, float] = {}
## What could get instanced in the -Y axis (down)
@export var down: Dictionary[StringName, float] = {}
## What could get instanced in the +Y axis (up)
@export var up: Dictionary[StringName, float] = {}
