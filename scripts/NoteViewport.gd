extends Viewport

onready var base_height = 1080.0

var container_size := Vector2(1080, 1080)
var scale := Vector2(1, 1)
func set_render_scale(scale: Vector2):
	self.scale = scale
	size = container_size * scale
	$Center.position = size * 0.5
	$Center.scale = size/base_height

# Called when the node enters the scene tree for the first time.
func _ready():
	Settings.connect('subsampling_changed', self, 'set_render_scale')
	set_render_scale(Settings.subsampling)


onready var Square := $'../../'
onready var Root := $'/root'
onready var Main := $'/root/main'
func _on_Square_item_rect_changed() -> void:
	var winscale = Root.size.x/Main.rect_size.x
	container_size = Square.rect_size * winscale
	set_render_scale(scale)
