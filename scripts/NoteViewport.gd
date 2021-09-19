extends Viewport

export var SquarePath := @'../../'
onready var Square := get_node(SquarePath)
onready var Root := $'/root'
onready var base_height = 1080.0

var container_size := Vector2(1080, 1080)
var scale := Vector2(1, 1)
func set_render_scale(scale: Vector2):
	self.scale = scale
	size = container_size * scale
	$Center.position = size * 0.5
	$Center.scale = size/base_height

func update_size() -> void:
	var winscale = min(Root.size.x, Root.size.y)/base_height
	container_size = Square.rect_size * winscale
	set_render_scale(scale)

# Called when the node enters the scene tree for the first time.
func _ready():
	Settings.connect('subsampling_changed', self, 'set_render_scale')
	Square.connect('item_rect_changed', self, 'update_size')
	Root.connect('size_changed', self, 'update_size')
	scale = Settings.subsampling
	update_size()
