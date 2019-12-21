extends Node2D

func _draw():
	draw_texture_rect($"../Viewport".get_texture(), Rect2(-540, -540, 1080, 1080), false)
