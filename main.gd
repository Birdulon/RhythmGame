extends Node2D

# member variables
var screen_height := 1080
var x_margin := 0.0
var y_margin := 0.0
var screen_center := Vector2(1920/2, screen_height/2)

func resize():
	var screen_size = $"/root".get_visible_rect().size
	screen_center = screen_size*0.5
	position = screen_center
	
	screen_height = screen_size.y
	x_margin = max((screen_size.x - screen_size.y)/2.0, 0.0)
	y_margin = max((screen_size.y - screen_size.x)/2.0, 0.0)

func _ready():
	$"/root".connect("size_changed", self, "resize")
	resize()

