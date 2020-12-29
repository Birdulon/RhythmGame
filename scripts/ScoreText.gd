extends Node2D

var score = ""
var score_sub = ""

var TitleFont := preload("res://assets/MenuTitleFont.tres")
var ScoreFont := preload("res://assets/MenuScoreFont.tres")

func draw_string_centered(font, position, string, color := Color.white):
	draw_string(font, Vector2(position.x - font.get_string_size(string).x/2.0, position.y + font.get_ascent()), string, color)

func _draw():
	if score:
		draw_string_centered(ScoreFont, Vector2(0, 0), score)
	if score_sub:
		draw_string_centered(TitleFont, Vector2(0, 128), score_sub)
