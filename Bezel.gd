tool
extends Node2D

# Draw the bezel for radial gamemode
var center := Vector2(0.0, 0.0)

func arc_point_list(center: Vector2, radius: float, angle_from:=0.0, angle_to:=360.0, points:=20) -> PoolVector2Array:
	var point_list = PoolVector2Array()
	for i in range(points):
		var angle = deg2rad(angle_from + i * (angle_to - angle_from) / (points-1))
#		point_list.push_back(center + Vector2(cos(angle), sin(angle)) * radius)
		point_list.push_back(center + polar2cartesian(radius, angle))
	return point_list

func _draw():
#	var bezel_colors := PoolColorArray([GameTheme.bezel_color])
	var bezel_colors := PoolColorArray([Color.red])
	var bezel_points: PoolVector2Array
	
	var screen_size = $"/root".get_visible_rect().size
	var screen_height = 1080 # min(screen_size.x, screen_size.y)
	
	var screen_height2 = screen_height/2.0

#	draw_rect(Rect2(-screen_height2, -screen_height2, -x_margin, screen_height), GameTheme.bezel_color)
#	draw_rect(Rect2(screen_height2, -screen_height2, x_margin, screen_height), GameTheme.bezel_color)

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

func _ready():
	$"/root".connect("size_changed", self, "update")