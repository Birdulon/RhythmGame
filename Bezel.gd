extends "res://main.gd"

# Draw the bezel for radial gamemode
var center := Vector2(0.0, 0.0)

func _draw():
	var bezel_colors := PoolColorArray([GameTheme.bezel_color])
	var bezel_points: PoolVector2Array
	var screen_height2 := screen_height/2.0

	draw_rect(Rect2(-screen_height2, -screen_height2, -x_margin, screen_height), GameTheme.bezel_color)
	draw_rect(Rect2(screen_height2, -screen_height2, x_margin, screen_height), GameTheme.bezel_color)

	bezel_points = arc_point_list(center, screen_height2, 0, -90)
	bezel_points.push_back(Vector2(screen_height2, -screen_height2))
	draw_polygon(bezel_points, bezel_colors)

	bezel_points = arc_point_list(center, screen_height2, -90, -180)
	bezel_points.push_back(Vector2(-screen_height2, -screen_height2))
	draw_polygon(bezel_points, bezel_colors)

	bezel_points = arc_point_list(center, screen_height2, -180, -270)
	bezel_points.push_back(Vector2(-screen_height2, screen_height2))
	draw_polygon(bezel_points, bezel_colors)

	bezel_points = arc_point_list(center, screen_height2, -270, -360)
	bezel_points.push_back(Vector2(screen_height2, screen_height2))
	draw_polygon(bezel_points, bezel_colors)
