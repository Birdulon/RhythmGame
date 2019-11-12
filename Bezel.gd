extends "res://main.gd"

# Draw the bezel for radial gamemode

func _draw():
	var bezel_color := Color.black
	var bezel_colors := PoolColorArray([bezel_color])
	var bezel_points: PoolVector2Array

	draw_rect(Rect2(0, 0, x_margin, screen_height), bezel_color)
	draw_rect(Rect2(1920-x_margin, 0, x_margin, screen_height), bezel_color)

	bezel_points = arc_point_list(screen_center, screen_height/2, 0, -90)
	bezel_points.push_back(Vector2(1920-x_margin, 0))
	draw_polygon(bezel_points, bezel_colors)

	bezel_points = arc_point_list(screen_center, screen_height/2, -90, -180)
	bezel_points.push_back(Vector2(x_margin, 0))
	draw_polygon(bezel_points, bezel_colors)

	bezel_points = arc_point_list(screen_center, screen_height/2, -180, -270)
	bezel_points.push_back(Vector2(x_margin, screen_height))
	draw_polygon(bezel_points, bezel_colors)

	bezel_points = arc_point_list(screen_center, screen_height/2, -270, -360)
	bezel_points.push_back(Vector2(1920-x_margin, screen_height))
	draw_polygon(bezel_points, bezel_colors)
