extends RichTextLabel

## How often should the label update
@export var update_interval: float = 0.333
## FPS color gradient
@export var color_gradient: Gradient = null
## How maby samples should it keep
@export var max_samples: int = 650

var timer: float = 0.0
var frame_times: Array[float] = []

func _process(delta: float) -> void:
	frame_times.append(delta)
	
	if frame_times.size() > max_samples:
		frame_times.pop_front()
	
	timer += delta
	if timer >= update_interval:
		timer -= update_interval
		update_fps_display()

func update_fps_display() -> void:
	if frame_times.is_empty():
		return
	var current_fps = Engine.get_frames_per_second()
	
	var sorted_times = frame_times.duplicate()
	sorted_times.sort()
	sorted_times.reverse()
	
	var sum: float = 0.0
	for time in frame_times:
		sum += time
	var avg_fps = 1.0 / (sum / frame_times.size())
	
	var low_1_count = max(1, int(sorted_times.size() * 0.01))
	var low_01_count = max(1, int(sorted_times.size() * 0.001))
	
	var low_1_fps = 1.0 / (get_average(sorted_times.slice(0, low_1_count)))
	var low_01_fps = 1.0 / (get_average(sorted_times.slice(0, low_01_count)))
	
	var color: Color = sample_color(current_fps)
	
	clear()
	push_color(color)
	add_text("FPS: %d\n" % current_fps)
	add_text("AVG: %d\n" % avg_fps)
	add_text("1%% Low: %d\n" % low_1_fps)
	add_text("0.1%% Low: %d" % low_01_fps)
	pop()

func sample_color(fps: float) -> Color:
	var final_color: Color = Color.WHITE
	if color_gradient:
		var refresh_rate = DisplayServer.screen_get_refresh_rate()
		if refresh_rate <= 0: refresh_rate = 60.0
		var t = clamp(fps / refresh_rate, 0.0, 1.0)
		final_color = color_gradient.sample(t)
	return final_color

func get_average(values: Array) -> float:
	var s = 0.0
	for v in values:
		s += v
	return s / values.size()
