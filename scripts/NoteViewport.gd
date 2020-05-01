extends Viewport

func set_render_scale(scale: Vector2):
	size = Vector2(1080, 1080) * scale
	$Center.position = size * 0.5
	$Center.scale = scale

func slider_slot(arg1):
	set_render_scale(Vector2($"/root/main/InputHandler/SSXSlider".value, $"/root/main/InputHandler/SSYSlider".value))

# Called when the node enters the scene tree for the first time.
func _ready():
#	set_render_scale(Vector2(0.5, 1.0))
	$"/root/main/InputHandler/SSXSlider".connect("value_changed", self, "slider_slot")
	$"/root/main/InputHandler/SSYSlider".connect("value_changed", self, "slider_slot")
	slider_slot(1)
