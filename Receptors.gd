extends "res://main.gd"

var ring_px := 4
var receptor_px := 24
var shadow_px := 5
var shadow_color := Color.black
var center := Vector2(0.0, 0.0)

func _draw():
	# Screen filter
	draw_rect(Rect2(-screen_height/2, -screen_height/2, screen_height, screen_height), theme.screen_filter)

	# Receptor ring
	var receptor_circle := arc_point_list(center, theme.receptor_ring_radius, 0.0, 360.0, 360)
	var receptor_centers := arc_point_list(center, theme.receptor_ring_radius, Rules.FIRST_COLUMN_ANGLE_DEG, Rules.FIRST_COLUMN_ANGLE_DEG+360.0-Rules.COLS_ANGLE_DEG, Rules.COLS)

	# Shadows
	for i in range(len(receptor_circle)-1):
		draw_line(receptor_circle[i], receptor_circle[i+1], shadow_color, ring_px + shadow_px, true)
	for i in range(len(receptor_centers)):
		draw_circle(receptor_centers[i], (receptor_px + shadow_px)/2, shadow_color)

	# Foregrounds
	for i in range(len(receptor_circle)-1):
		draw_line(receptor_circle[i], receptor_circle[i+1], theme.receptor_color, ring_px, true)
	for i in range(len(receptor_centers)):
		draw_circle(receptor_centers[i], receptor_px/2, theme.receptor_color)

