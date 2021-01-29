extends Node2D

var TitleFont := preload("res://assets/MenuTitleFont.tres").duplicate()
var ScoreFont := preload("res://assets/MenuScoreFont.tres").duplicate()

var score = ""
var score_sub = ""

var f_scale := 1.0 setget set_f_scale
func set_f_scale(value: float) -> void:
	f_scale = value
	TitleFont.size = int(round(32*f_scale))
	TitleFont.outline_size = int(max(round(2*f_scale), 1))
	ScoreFont.size = int(round(96*f_scale))
	ScoreFont.outline_size = int(max(round(2*f_scale), 1))

func draw_string_centered(font, position, string, color := Color.white):
	draw_string(font, Vector2(position.x - font.get_string_size(string).x/2.0, position.y + font.get_ascent()), string, color)

func _draw():
	if score:
		draw_string_centered(ScoreFont, Vector2(0, 0)*f_scale, score)
	if score_sub:
		draw_string_centered(TitleFont, Vector2(0, 128)*f_scale, score_sub)
