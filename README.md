# WFC Structure generator

## What is it
This is a powerful and highly customizable system to generate structures within a 3D grid.
Suitable for stuff like: Office interiors, city roadmap generator, etc etc.

## Installation
1. Clone / Download the repository, then copy the file addons/grid_structure_gen into your project's addon's folder.
2. Enable the addon in the extensions tab of the project settings
3. See: How to use

## How to use
WARNING: This is a HIGHLY COMPLEX system so BEFORE installing it, if you're planning to make use of its full toolset, make sure you're fully comfortable with the concepts of WFC (Wave Function Collapse).
IF you aren't going to make use of the full tileset, you might be file with just editing the default StructureSegment scenes.
NOTE: The system is designed to backtrack and retry when conradictions are met in a cell, but sometimes it can fully fail. If this happens, double check your tileset and ry to tweak/remove/add values. This exhibits very complex behavior and obviously is not 100% predictable as sometimes it can generate without issues, others it could give contradictions, so make sure to thouroghly test your setup before calling it a day.
NOTE 2: The addon is thoroughly documented so, when in doubt, most of the times there's a docstring explaining what that specific thing does. To see what an @export does, hover over it in the editor. For further info, open up the in-editor Documentation and search for the specific class you're dubious about (defualt godot keybind: F1).

Depending on the need, This plugin can be used in two main ways:
  * Wave Function Collapse algorithm ONLY
  * Pre-Processing + Wave Function Collapse + Post-Processing
It can also be set up to either automatically generate the structure's root node, or to have it produce the data grid ONLY.

### Quickstart instructions:
```gdscript
# First create the pipeline for the generator
var pipeline := StructurePipeline.new(my_structure, Vector3i(10, 3, 10))

# Then, add (or not, if not needed) pre-processors and post-processors to achieve the desired effect.
# (ATTENTION: Processors are executed IN ORDER, meaning that changing the order, could change the produced result!)
# You can implement your own starting from GridProcessorBaseType or use right away some of the ones i implemented.
pipeline.add_pre_processor(RoomInstantiator.new())
pipeline.add_post_processor(RoomCuller.new(5))
pipeline.add_post_processor(GraphJoiner.new(2))
pipeline.add_post_processor(StructureDefiner.new())

# Select the running mode
# FULL: runs the full pipeline and produces the structure root node
# GRID: does the same but returns the grid data structure instead of the structure root node
#
# When no mode is specified in run(), FULL gets run automatically, if an invalid input is given it will default to GRID instead.
var run_mode: RunMode = RunMode.FULL

# Run the pipeline
# NOTE: The pipeline is ASYNC. Meaning that slow generation of the structure WILL NOT block the main thread.
# However due to this, you must use await to stop execution until the coroutine has finished
var node: Node3D = await pipeline.run(run_mode)
if node:
    add_child(node)
```

When in doubt of how to use something refer to these main locations:
1. Test scene (example of generation and actual use case)
2. Documentation (In depth description)
3. Inspector (For the export parameters, if applicable)
