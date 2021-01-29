extends Control

onready var Viewport := get_node(@'../NoteHandler/Viewport')

func _draw():
	draw_texture_rect(Viewport.get_texture(), Rect2(Vector2.ZERO, rect_size), false)
#	texture = Viewport.get_texture()
