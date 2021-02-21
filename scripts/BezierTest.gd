tool
extends Control

# This is for playing around with weird control point curves in-editor.
# Some slide types are a bit difficult to reason about.

const ORBIT_INNER_RADIUS = sin(deg2rad(22.5))  # ~0.38
const ORBIT_KAPPA = (sqrt(2)-1) * 4.0 / 3.0  # This is the length of control points along a tangent to approximate a circle (multiply by desired radius)

export(float, -360, 360, 7.5) var angle_entry = -22.5  # degrees
export(float, -360, 360, 7.5) var angle_exit = 112.5  # degrees
var inner_radius = ORBIT_INNER_RADIUS
export(float, 5.0, 120.0) var max_arc_angle := 45.0
export(bool) var show_points := true
export(bool) var show_handles := true
export(bool) var flip_direction := false
var sideorbit_center := Vector2.ZERO

var curve2d := Curve2D.new()

func _draw() -> void:
#	draw_circle(rect_size * 0.5, inner_radius * GameTheme.receptor_ring_radius, Color.darkgreen)
	var points = curve2d.get_baked_points()
	if len(points) < 2:
		return
	draw_set_transform(rect_size * 0.5, 0, Vector2.ONE * GameTheme.receptor_ring_radius)
	draw_circle(sideorbit_center, inner_radius, Color.darkgreen)
	draw_multiline(points, Color.white)

	var l = curve2d.get_point_count()
	var c_points = []
	var handles_in = []
	var handles_out = []
	for i in l:
		var p = curve2d.get_point_position(i)
		c_points.append(p)
		handles_in.append(curve2d.get_point_in(i) + p)
		handles_out.append(curve2d.get_point_out(i) + p)
	if show_handles:
		for i in l:
			draw_circle(handles_in[i], 0.01, Color.burlywood)
			draw_circle(handles_out[i], 0.01, Color.cadetblue)
	if show_points:
		for i in l:
			draw_circle(c_points[i], 0.012, Color.blanchedalmond)

func _process(delta: float) -> void:
	curve2d.clear_points()
	curve2d.bake_interval = 0.01
	var rad_in = deg2rad(angle_entry)
	var rad_out = deg2rad(angle_exit)
	curve2d.add_point(polar2cartesian(1.0, rad_in))
	Note.curve2d_make_sideorbit(curve2d, rad_in, rad_out, flip_direction)
	curve2d.add_point(polar2cartesian(1.0, rad_out))
	sideorbit_center = polar2cartesian(inner_radius, rad_in-PI*0.5*(-1 if flip_direction else 1))
	update()

#func curve2d_make_sideorbit(curve2d: Curve2D, rad_in: float, rad_out: float, ccw: bool, rad_max_arc:=PI*0.25, kappa:=ORBIT_KAPPA, inner_radius:=ORBIT_INNER_RADIUS):
#	var d_sign := -1 if ccw else 1
#
#	sideorbit_center = polar2cartesian(inner_radius, rad_in-PI*0.5*d_sign)
#
#	var rad_orbit_in := rad_in + PI*0.5*d_sign
#	var orbcenter_to_out := polar2cartesian(1.0, rad_out) - sideorbit_center
#	var rad_orbit_out := orbcenter_to_out.angle() - acos(inner_radius/orbcenter_to_out.length())*d_sign
#	var pos_orbit_out := sideorbit_center + polar2cartesian(inner_radius, rad_orbit_out)
#
#	var rad_2 = rad_in + PI
#	var rad_2t = rad_2+PI*0.5*d_sign
#	var rad_3 = rad_out-PI*3/8*d_sign
#	var rad_3t = rad_3-PI*0.5*d_sign
#
#	var a_diff = wrapf((rad_orbit_out-rad_orbit_in)*d_sign, 0.0001, TAU+0.0001)
#	var n = ceil(a_diff/rad_max_arc)
#	var ad = a_diff/n
#	var k = kappa*inner_radius*(2*ad/PI)  # Not geometrically correct scaling but reasonable for now
#
##	curve2d.add_point(polar2cartesian(1.0, rad_in))
#	curve2d.add_point(Vector2.ZERO, Vector2.ZERO, polar2cartesian(k, rad_2))
#	for i in range(1, n):
#		var ang = rad_orbit_in + i*ad*d_sign
#		curve2d.add_point(sideorbit_center + polar2cartesian(inner_radius, ang), polar2cartesian(k, ang-PI/2*d_sign), polar2cartesian(k, ang+PI/2*d_sign))
#
#	curve2d.add_point(pos_orbit_out, polar2cartesian(k, rad_orbit_out-PI*0.5*d_sign))
##	curve2d.add_point(polar2cartesian(1.0, rad_out))
