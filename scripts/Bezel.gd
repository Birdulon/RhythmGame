tool
extends Control

# Draw the bezel for radial gamemode
var center := Vector2(0.0, 0.0)

func arc_point_list(center: Vector2, radius: float, angle_from:=0.0, angle_to:=360.0, points:=20) -> PoolVector2Array:
	var point_list = PoolVector2Array()
	for i in range(points):
		var angle = deg2rad(angle_from + i * (angle_to - angle_from) / (points-1))
		point_list.push_back(center + polar2cartesian(radius, angle))
	return point_list

func _draw():
	center = rect_size*0.5
	var bezel_colors := PoolColorArray([GameTheme.bezel_color])
	var bezel_points: PoolVector2Array
	var dim = rect_size.x
	var dim2 = center.x

	bezel_points = arc_point_list(center, dim2, 0, -90)
	bezel_points.push_back(Vector2(dim, 0))
	draw_polygon(bezel_points, bezel_colors)

	bezel_points = arc_point_list(center, dim2, -90, -180)
	bezel_points.push_back(Vector2(0, 0))
	draw_polygon(bezel_points, bezel_colors)

	bezel_points = arc_point_list(center, dim2, -180, -270)
	bezel_points.push_back(Vector2(0, dim))
	draw_polygon(bezel_points, bezel_colors)

	bezel_points = arc_point_list(center, dim2, -270, -360)
	bezel_points.push_back(Vector2(dim, dim))
	draw_polygon(bezel_points, bezel_colors)

func _ready():
	$"/root".connect("size_changed", self, "update")
