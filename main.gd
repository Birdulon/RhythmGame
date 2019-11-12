extends Node2D

# member variables
var screen_height := 1080
var x_margin := (1920 - screen_height)/2
var screen_center := Vector2(1920/2, screen_height/2)

func arc_point_list(center: Vector2, radius: float, angle_from:=0.0, angle_to:=360.0, points:=90) -> PoolVector2Array:
	var point_list = PoolVector2Array()
	for i in range(points):
		var angle = deg2rad(angle_from + i * (angle_to - angle_from) / (points-1))
#		point_list.push_back(center + Vector2(cos(angle), sin(angle)) * radius)
		point_list.push_back(center + polar2cartesian(radius, angle))
	return point_list

# Called when the node enters the scene tree for the first time.
#func _ready():
#	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass



