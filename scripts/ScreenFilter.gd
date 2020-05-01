extends Node2D

func _draw():
	var screen_size = $"/root".get_visible_rect().size
	var screen_height = max(screen_size.x, screen_size.y)
	draw_rect(Rect2(-screen_height/2, -screen_height/2, screen_height, screen_height), GameTheme.screen_filter)

func _ready():
	GameTheme.connect("screen_filter_changed", self, "update")
