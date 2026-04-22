# structure_generator.gd
extends RefCounted
class_name StructureGenerator



## The resource of the structure needed to be generated
var structure: Structure
## How many cells there are for any given direction (X, Y, and Z)
var grid_bounds: Vector3i
## The available options for every single cell (starts from superposition)
var wave: Dictionary[Vector3i, Array]
## The compaitbility table used by the wave function collapse
var compatibility_table: Dictionary[String, Dictionary]
## The array containing every segment id (the analogous of [code]structure.structure_sections.keys()[/code])
var all_segment_ids: Array[StringName]
## Wether the generator should ignore all the cells with an open border towards the border (bugged right now, DO NOT use)
var border_constraint: bool = false


func _init(p_structure: Structure, p_bounds: Vector3i) -> void:
	grid_bounds = p_bounds
	structure = p_structure

func setup() -> void:
	all_segment_ids = structure.structure_sections.keys()
	all_segment_ids.append(Structure.EMPTY_CELL)
	
	compatibility_table = structure._build_compatibility_table()
	
	_initialize_wave()


func _initialize_wave() -> void:
	wave.clear()
	var x_bounds: Array = range(grid_bounds.x)
	var y_bounds: Array = range(grid_bounds.y)
	var z_bounds: Array = range(grid_bounds.z)
	for x in x_bounds:
		for y in y_bounds:
			for z in z_bounds:
				# Each cell starts from every possible combination
				wave[Vector3i(x, y, z)] = all_segment_ids.duplicate()

func instantiate_in_world(parent: Node3D) -> void:
	for cell: Vector3i in wave:
		var options: Array = wave[cell]
		
		# Salta celle vuote o non collassate correttamente
		if options.size() != 1:
			push_warning("Cella %s non collassata correttamente" % cell)
			continue
		
		var seg_id: StringName = options[0]
		var segment: StructureSegment = structure.structure_sections.get(seg_id)
		
		if segment == null or segment.segment_scene == null:
			continue
		
		# Calcola la posizione nel mondo 3D
		var world_pos: Vector3 = Vector3(
			cell.x * structure.grid_size,
			cell.y * structure.grid_size,
			cell.z * structure.grid_size
		)
		
		var instance = segment.segment_scene.instantiate() as Node3D
		instance.position = world_pos
		parent.add_child(instance)

#region WFC
# ---- OBSERVE ----

func observe() -> Vector3i:
	var min_entropy := INF
	var candidates: Array[Vector3i] = []
	
	for cell: Vector3i in wave:
		var count := wave[cell].size()
		if count <= 1:
			continue
		if count < min_entropy:
			min_entropy = count
			candidates = [cell]
		elif count == min_entropy:
			candidates.append(cell)
	
	var chosen: Vector3i = candidates.pick_random()
	_collapse(chosen)
	return chosen

func observe_adjacent() -> Vector3i:
	var min_entropy := INF
	var candidates: Array[Vector3i] = []
	
	# Considera solo le celle sul "fronte" della struttura
	var frontier := _get_frontier()
	
	# Se il fronte è vuoto la struttura non può crescere oltre
	if frontier.is_empty():
		return Vector3i(-1, -1, -1)  # segnale di stop
	
	for cell in frontier:
		var count := wave[cell].size()
		if count <= 1:
			continue
		if count < min_entropy:
			min_entropy = count
			candidates = [cell]
		elif count == min_entropy:
			candidates.append(cell)
	
	if candidates.is_empty():
		return Vector3i(-1, -1, -1)
	
	var chosen := candidates.pick_random()
	_collapse(chosen)
	return chosen


func _get_frontier() -> Array[Vector3i]:
	var frontier: Array[Vector3i] = []
	for cell: Vector3i in wave:
		if wave[cell].size() != 1:
			continue
		if wave[cell][0] == Structure.EMPTY_CELL:
			continue
		# Questa cella è collassata con un segmento reale
		# I suoi vicini non collassati sono il fronte
		for dir in Structure.DIRECTIONS:
			var neighbor := cell + Structure.DIRECTIONS[dir]
			if not _in_bounds(neighbor):
				continue
			if wave[neighbor].size() > 1:
				frontier.append(neighbor)
	return frontier


func _collapse(cell: Vector3i) -> void:
	var options: Array = wave[cell]
	var chosen := _weighted_pick(options)
	wave[cell] = [chosen]


func _weighted_pick(options: Array) -> StringName:
	var total_weight := 0.0
	var weights: Array[float] = []

	for seg_id: StringName in options:
		var w := 1.0
		if seg_id != Structure.EMPTY_CELL:
			w = structure.structure_sections[seg_id].spawn_weight
		weights.append(w)
		total_weight += w

	var r := randf() * total_weight
	var cumulative := 0.0
	for i in range(options.size()):
		cumulative += weights[i]
		if r <= cumulative:
			return options[i]

	return options[-1]



# ---- PROPAGATE ----

func propagate(start: Vector3i) -> bool:
	var queue: Array[Vector3i] = [start]
	var in_queue: Dictionary[Vector3i, bool] = { start: true }
	
	while queue.size() > 0:
		var current: Vector3i = queue.pop_front()
		in_queue.erase(current)
		
		for dir: StringName in Structure.DIRECTIONS:
			var neighbor: Vector3i = current + Structure.DIRECTIONS[dir]
			
			if not _in_bounds(neighbor):
				continue
			if wave[neighbor].size() <= 1:
				continue
			
			# Calcola quali opzioni sono ancora supportate in neighbor
			var supported := _compute_supported(current, dir)
			
			# Rimuovi da neighbor tutto ciò che non è supportato
			var before := wave[neighbor].size()
			wave[neighbor] = wave[neighbor].filter(
				func(opt): return opt in supported
			)
			var after := wave[neighbor].size()
			
			if after == 0:
				return false  # contraddizione
			
			# Se abbiamo rimosso qualcosa, neighbor deve propagare ai suoi vicini
			if after < before and not in_queue.has(neighbor):
				queue.append(neighbor)
				in_queue[neighbor] = true
	
	return true


func _compute_supported(current: Vector3i, dir: StringName) -> Array:
	# Raccoglie tutti i segmenti compatibili nella direzione dir
	# guardando le opzioni ancora disponibili in current
	var supported: Dictionary[StringName, bool] = {}
	for seg_id: StringName in wave[current]:
		for compatible: StringName in compatibility_table[seg_id][dir]:
			supported[compatible] = true
	return supported.keys()


func _in_bounds(cell: Vector3i) -> bool:
	return (
		cell.x >= 0 and cell.x < grid_bounds.x and
		cell.y >= 0 and cell.y < grid_bounds.y and
		cell.z >= 0 and cell.z < grid_bounds.z
	)

func _apply_border_constraints() -> void:
	for cell: Vector3i in wave:
		for dir: StringName in Structure.DIRECTIONS:
			var neighbor := cell + Structure.DIRECTIONS[dir]
			if _in_bounds(neighbor):
				continue
			# Questa faccia è sul bordo: rimuovi tutto ciò che non è compatibile con EMPTY
			wave[cell] = wave[cell].filter(func(seg_id):
				return (Structure.EMPTY_CELL in compatibility_table[seg_id][dir])
			)


# ---- MAIN LOOP ----
func generate(max_attempts: int = 1000) -> bool:
	for attempt in range(max_attempts):
		setup()
		
		if border_constraint:
			_apply_border_constraints()
		
		var contradiction := false
		
		#var max_cycles: int = 1000
		#var current_cycle: int = 0
		while (not _all_collapsed()):
			var chosen := observe()
			if not propagate(chosen):
				contradiction = true
				break
			#current_cycle += 1
			#print(current_cycle)
		
		if not contradiction:
			return true
		
		push_warning("WFC: Attempt %d failed, retrying..." % (attempt + 1))
	
	push_error("WFC: Failed after %d tentativi. Constraints are too strict." % max_attempts)
	return false


func _all_collapsed() -> bool:
	for cell in wave:
		if wave[cell].size() > 1:
			return false
	return true
#endregion WFC
