extends Control

export var ViewportPath := @'../NoteHandler/Viewport'
onready var Viewport := get_node(ViewportPath)

func _draw():
	draw_texture_rect(Viewport.get_texture(), Rect2(Vector2.ZERO, rect_size), false)
#	texture = Viewport.get_texture()
