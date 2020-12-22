extends Viewport

export var SubsampleXControl = @'/root/main/InputHandler/SSXSlider'
export var SubsampleYControl = @'/root/main/InputHandler/SSYSlider'
onready var SSX = get_node(SubsampleXControl)
onready var SSY = get_node(SubsampleYControl)

func set_render_scale(scale: Vector2):
	var ws = OS.window_size
	var dim = min(ws.x, ws.y)
	size = Vector2(dim, dim) * scale
	$Center.position = size * 0.5
	$Center.scale = size/1080

func slider_slot(arg1):
	set_render_scale(Vector2(SSX.value, SSY.value))

# Called when the node enters the scene tree for the first time.
func _ready():
	SSX.connect('value_changed', self, 'slider_slot')
	SSY.connect('value_changed', self, 'slider_slot')
	slider_slot(1)
