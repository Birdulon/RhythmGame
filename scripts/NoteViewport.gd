extends Viewport

func set_render_scale(scale: Vector2):
	var ws = OS.window_size
	var dim = min(ws.x, ws.y)
	size = Vector2(dim, dim) * scale
	$Center.position = size * 0.5
	$Center.scale = size/1080

func slider_slot(arg1):
	set_render_scale(Vector2($"/root/main/InputHandler/SSXSlider".value, $"/root/main/InputHandler/SSYSlider".value))

# Called when the node enters the scene tree for the first time.
func _ready():
	$"/root/main/InputHandler/SSXSlider".connect("value_changed", self, "slider_slot")
	$"/root/main/InputHandler/SSYSlider".connect("value_changed", self, "slider_slot")
	slider_slot(1)
