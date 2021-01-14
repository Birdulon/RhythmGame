extends Viewport

onready var base_height = ProjectSettings.get_setting('display/window/size/height')

func set_render_scale(scale: Vector2):
	var ws = OS.window_size
	var dim = min(ws.x, ws.y)
	size = Vector2(dim, dim) * scale
	$Center.position = size * 0.5
	$Center.scale = size/base_height

# Called when the node enters the scene tree for the first time.
func _ready():
	Settings.connect('subsampling_changed', self, 'set_render_scale')
	set_render_scale(Settings.subsampling)
