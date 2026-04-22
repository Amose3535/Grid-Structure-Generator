# structure_segment.gd
extends Resource
class_name StructureSegment
## The necessary data of the segment of a structure.

## This is what will get instanced at the position of the cell whose corresponding segment is this one.
@export var segment_scene: PackedScene = null

@export_group("Generation criteria")
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
## Global WFC span weight. This indicates how frequent is this room as a starting point.
@export var spawn_weight: float = 1.0
