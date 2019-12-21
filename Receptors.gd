#tool
extends MeshInstance2D

var ring_px := 4  # Analogous to diameter
var receptor_px := 24  # Diameter
var shadow_px := 8  # Outer edge, analogous to radius
var shadow_color := Color.black
var center := Vector2(0.0, 0.0)

func make_ring_mesh(inner_vertices: int, thickness: float, radius: float, skew:=0.5, repeat_start:=true):
	# This makes a trianglestrip around the ring, consisting of chords on the inside and tangents on the outside.
	# The goal is to exchange some fragment and vertex processing load:
	# - a full quad of the ring would be the maximum fragment load and minimum vertex load
	# - a complex mesh closely following the outline of the ring would minimize discarded fragments at the cost of increased vertex processing
	# - the ideal workload ratio is probably different for each GPU and also depends on other things our program is doing
	assert(inner_vertices >= 3)
	assert(thickness > 0.0)
	assert(radius > 0.0)
	# While values of 3 and 4 are mathematically possible, they result in half of the trianglestrip being degenerate for thin lines.
	# Only values of 5 and above should be used practically.
	var vertices = inner_vertices * 2
	# For simplicity's sake, the width of the ring will be the full thickness at the receptor points.
	# For high vertex counts a slightly more optimal mesh could be constructed based on the thickness at each arc of the ring and where it would be intersected by the outer tangent.
	# Essentially, we will be making an inner polygon and an outer polygon.
	var angle_increment = TAU/float(inner_vertices)
	var angle_outer_offset = skew*angle_increment
	var r1 = radius - thickness*0.5
	# Outer polygon side-length = inner side-length / sin(inside angle/2)
	# inside angle for a polygon is pi-tau/n. We already precalculated tau/n for other purposes.
	var r2 = (radius + thickness*0.5)/sin((PI-angle_increment)/2)
	var UV_r1 = r1/radius
	var UV_r2 = r2/radius

	var vertex_list = PoolVector2Array()
	var UV_list = PoolVector2Array()
	var inner_list = PoolVector2Array()
	var outer_list = PoolVector2Array()
	for i in inner_vertices:
		var angle_i = i * angle_increment
		var angle_o = angle_i + angle_outer_offset
		vertex_list.push_back(polar2cartesian(r1, angle_i))
		vertex_list.push_back(polar2cartesian(r2, angle_o))
		inner_list.push_back(vertex_list[-2])
		outer_list.push_back(vertex_list[-1])
		UV_list.push_back(polar2cartesian(UV_r1, angle_i))
		UV_list.push_back(polar2cartesian(UV_r2, angle_o))
	if repeat_start:
		vertex_list.push_back(vertex_list[0])
		vertex_list.push_back(vertex_list[1])
		inner_list.push_back(vertex_list[0])
		outer_list.push_back(vertex_list[1])
		UV_list.push_back(UV_list[0])
		UV_list.push_back(UV_list[1])
	return [vertex_list, inner_list, outer_list, UV_list]

func triangle_area(a: Vector2, b: Vector2, c: Vector2) -> float:
	return 0.5 * abs((a.x-c.x)*(b.y-a.y) - (a.x-b.x)*(c.y-a.y))

func inscribe_polygon_area(r: float, sides: int) -> float:
	return 0.5 * sides * r * r * sin(TAU/sides)
func circumscribe_polygon_area(r: float, sides: int) -> float:
	return sides * r * r * tan(PI/sides)

func arc_point_list(center: Vector2, radius: float, angle_from:=0.0, angle_to:=360.0, points:=90) -> PoolVector2Array:
	var point_list = PoolVector2Array()
	for i in range(points):
		var angle = deg2rad(angle_from + i * (angle_to - angle_from) / (points-1))
		point_list.push_back(center + polar2cartesian(radius, angle))
	return point_list

func draw_old(circles:=true, shadows:=true):	# Receptor ring
	var receptor_circle := arc_point_list(center, GameTheme.receptor_ring_radius, 0.0, 360.0, 360)
	var receptor_centers := arc_point_list(center, GameTheme.receptor_ring_radius, Rules.FIRST_COLUMN_ANGLE_DEG, Rules.FIRST_COLUMN_ANGLE_DEG+360.0-Rules.COLS_ANGLE_DEG, Rules.COLS)

	if shadows:
		draw_polyline(receptor_circle, shadow_color, ring_px + shadow_px/2, true)
		if circles:
			for i in range(len(receptor_centers)):
				draw_circle(receptor_centers[i], receptor_px/2 + shadow_px, shadow_color)

	draw_polyline(receptor_circle, GameTheme.receptor_color, ring_px, true)
	if circles:
		for i in range(len(receptor_centers)):
			draw_circle(receptor_centers[i], receptor_px/2, GameTheme.receptor_color)

func draw_tris():
	var dbg_color = Color(1.0, 0.0, 0.0, 1.0)
	draw_polyline(ring_vertices[0], dbg_color)
	draw_polyline(ring_vertices[1], dbg_color)
	draw_polyline(ring_vertices[2], dbg_color)

var ring_vertices
func update_ring_mesh():
	var mesh_v = $"../InputHandler/VerticesSlider".value
	var skew = $"../InputHandler/SkewSlider".value
	var ring_thickness = receptor_px + shadow_px*2
	ring_vertices = make_ring_mesh(mesh_v, ring_thickness, GameTheme.receptor_ring_radius, skew)
	var temp_mesh = ArrayMesh.new()
	var mesh_arrays = []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = ring_vertices[0]
	mesh_arrays[Mesh.ARRAY_TEX_UV] = ring_vertices[3]
#	mesh_arrays[Mesh.ARRAY_COLOR] = colors
	temp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, mesh_arrays)
	mesh = temp_mesh


func _draw():
#	draw_old(true, true)
#	draw_tris()
	var mesh_v = $"../InputHandler/VerticesSlider".value
	var skew = $"../InputHandler/SkewSlider".value
	var ring_thickness = receptor_px + shadow_px*2
	var estimated_area = circumscribe_polygon_area(GameTheme.receptor_ring_radius+ring_thickness*0.5, mesh_v) - inscribe_polygon_area(GameTheme.receptor_ring_radius-ring_thickness*0.5, mesh_v)
	var ideal_ring_area = PI * (pow(GameTheme.receptor_ring_radius+receptor_px/2+shadow_px, 2) - pow(GameTheme.receptor_ring_radius-receptor_px/2-shadow_px, 2))

#	var l = len(ring_vertices)
#	for i in l:
#		estimated_area += triangle_area(ring_vertices[i], ring_vertices[(i+1)%l], ring_vertices[(i+2)%l])
	var quad_area = 4*pow(GameTheme.receptor_ring_radius+receptor_px/2+shadow_px, 2)
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	$"/root/main/InputHandler".text = "Vertices: %d*2     Skew: %.3f\nArea: %.0f\n(%.0f%% ideal ring)\n(%.0f%% quad)\nFPS: %.0f"%[mesh_v, skew, estimated_area, 100.0*estimated_area/ideal_ring_area, 100.0*estimated_area/quad_area, fps]

	material.set_shader_param("dot_radius", 0.5*receptor_px/GameTheme.receptor_ring_radius)
	material.set_shader_param("line_thickness", 0.5*ring_px/GameTheme.receptor_ring_radius)
	material.set_shader_param("shadow_thickness", shadow_px/GameTheme.receptor_ring_radius)
	material.set_shader_param("shadow_thickness_taper", -0.75)
	material.set_shader_param("px", 0.5/GameTheme.receptor_ring_radius)

func update_ring_mesh_1arg(arg1):
	# Hack because signals can't discard arguments when connected to smaller slots :(
	update_ring_mesh()

func _ready():
	var receptor_array_image := Image.new()
	receptor_array_image.create(8, 8, false, Image.FORMAT_RH)
	receptor_array_image.lock()
	for i in Rules.COLS:
		receptor_array_image.set_pixel(i%8, i/8, Color(GameTheme.RADIAL_COL_ANGLES[i], 0.0, 0.0))
	receptor_array_image.unlock()
	var receptor_data_tex = ImageTexture.new()
	receptor_data_tex.create_from_image(receptor_array_image, 0)
	set_texture(receptor_data_tex)
	material.set_shader_param("num_receptors", Rules.COLS)

	update_ring_mesh()
	$"../InputHandler/VerticesSlider".connect("value_changed", self, "update_ring_mesh_1arg")
	$"../InputHandler/SkewSlider".connect("value_changed", self, "update_ring_mesh_1arg")
	$"/root".connect("size_changed", self, "update")

func _process(delta):
	if not Engine.editor_hint:
		update()