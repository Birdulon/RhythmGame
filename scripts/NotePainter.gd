extends Node2D

onready var Viewport := get_node(@'../Viewport')

func _draw():
	draw_texture_rect(Viewport.get_texture(), Rect2(-540, -540, 1080, 1080), false)
