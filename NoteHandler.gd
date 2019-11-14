extends "res://main.gd"

# This script will draw all note events.

var tex := preload("res://assets/spritesheet-1024.png")
var tex_slide_arrow := preload("res://assets/slide-arrow-512.png")
var slide_trail_shadermaterial := preload("res://shaders/slidetrail.tres")

# Constants for the overall notefield
var RADIAL_COL_ANGLES := PoolRealArray()  # ideally const
var RADIAL_UNIT_VECTORS := PoolVector2Array()  # ideally const

# ------------------------------------------------------
# Ring segments is only for CPU drawing, superceded for now.
# ------------------------------------------------------
#const RING_LINE_SEGMENTS_PER_COLUMN := 12
#var RING_LINE_SEGMENTS_VECTORS := PoolVector2Array()
#const ring_segs := Rules.COLS * RING_LINE_SEGMENTS_PER_COLUMN
#const ring_seg_angle := 360.0/ring_segs
#var ring_line_segments_alphas = PoolRealArray()
#var ring_line_segments_widths = PoolRealArray()
func init_radial_values():
	for i in range(Rules.COLS):
		var angle = deg2rad(fmod(Rules.FIRST_COLUMN_ANGLE_DEG + (i * Rules.COLS_ANGLE_DEG), 360.0))
		RADIAL_COL_ANGLES.push_back(angle)
		RADIAL_UNIT_VECTORS.push_back(Vector2(cos(angle), sin(angle)))
#	for i in range(ring_segs):
#		var angle = deg2rad(Rules.FIRST_COLUMN_ANGLE_DEG + (i * ring_seg_angle))
#		RING_LINE_SEGMENTS_VECTORS.push_back(Vector2(cos(angle), sin(angle)))
#	for i in range(ring_segs/4):
#		var alpha := 1.0 - (i/float(ring_segs/4))
#		ring_line_segments_alphas.push_back(alpha)
#		ring_line_segments_widths.push_back(lerp(alpha, 1.0, 0.5))

const SQRT2 := sqrt(2)
const DEG45 := deg2rad(45.0)
const DEG90 := deg2rad(90.0)
const DEG135 := deg2rad(135.0)

var time := 0.0
var t := 0.0
var bpm := 120.0
var sync_offset_video := 0.0  # Time in seconds to the first beat
var sync_offset_audio := 0.0  # Time in seconds to the first beat
var active_notes := []
var all_notes := []
var next_note_to_load := 0
var slide_trail_meshes := {}
var slide_trail_mesh_instances := {}

# UV vertex arrays for our sprites
# tap/star/arrow are 4-vertex 2-triangle simple squares
# hold is 8-vertex 6-triangle to enable stretching in the middle
const UV_ARRAY_TAP := PoolVector2Array([Vector2(0, 0.5), Vector2(0.5, 0.5), Vector2(0, 1), Vector2(0.5, 1)])
const UV_ARRAY_HOLD := PoolVector2Array([
	Vector2(0.5, 0.5), Vector2(1, 0.5), Vector2(0.5, 0.75), Vector2(1, 0.75),
	Vector2(0.5, 0.75), Vector2(1, 0.75), Vector2(0.5, 1), Vector2(1, 1)
	])
const UV_ARRAY_STAR := PoolVector2Array([Vector2(0.5, 0), Vector2(1, 0), Vector2(0.5, 0.5), Vector2(1, 0.5)])
const UV_ARRAY_ARROW := PoolVector2Array([Vector2(0, 0), Vector2(0.5, 0), Vector2(0, 0.5), Vector2(0.5, 0.5)])
# Slide trail arrow. Single tri.
const UV_ARRAY_SLIDE_ARROW := PoolVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)])
const UV_ARRAY_SLIDE_ARROW2 := PoolVector2Array([Vector2(1, 1), Vector2(0, 1), Vector2(1, 0)])

# Normal vertex arrays for our sprites. Might be unnecessary?
const DEFAULT_NORMAL := Vector3(0, 0, 1)
var NORMAL_ARRAY_4 := PoolVector3Array([DEFAULT_NORMAL, DEFAULT_NORMAL, DEFAULT_NORMAL, DEFAULT_NORMAL])
var NORMAL_ARRAY_8 := PoolVector3Array([
	DEFAULT_NORMAL, DEFAULT_NORMAL, DEFAULT_NORMAL, DEFAULT_NORMAL,
	DEFAULT_NORMAL, DEFAULT_NORMAL, DEFAULT_NORMAL, DEFAULT_NORMAL
	])

# ----------------------------------------------------------------------------------------------------------------------------------------------------
# Helper functions to generate meshes from vertex arrays
func make_tap_mesh(mesh: ArrayMesh, vertex_array, color_array = theme.COLOR_ARRAY_TAP):
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
#	arrays[Mesh.ARRAY_NORMAL] = NORMAL_ARRAY_4
	arrays[Mesh.ARRAY_TEX_UV] = UV_ARRAY_TAP
	arrays[Mesh.ARRAY_COLOR] = color_array
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)

func make_hold_mesh(mesh: ArrayMesh, vertex_array, color_array = theme.COLOR_ARRAY_HOLD):
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
#	arrays[Mesh.ARRAY_NORMAL] = NORMAL_ARRAY_8
	arrays[Mesh.ARRAY_TEX_UV] = UV_ARRAY_HOLD
	arrays[Mesh.ARRAY_COLOR] = color_array
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)

func make_star_mesh(mesh: ArrayMesh, vertex_array, color_array = theme.COLOR_ARRAY_STAR):
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
#	arrays[Mesh.ARRAY_NORMAL] = NORMAL_ARRAY_4
	arrays[Mesh.ARRAY_TEX_UV] = UV_ARRAY_STAR
	arrays[Mesh.ARRAY_COLOR] = color_array
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)

func make_arrow_mesh(mesh: ArrayMesh, vertex_array, color_array = theme.COLOR_ARRAY_TAP):
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
#	arrays[Mesh.ARRAY_NORMAL] = NORMAL_ARRAY_4
	arrays[Mesh.ARRAY_TEX_UV] = UV_ARRAY_ARROW
	arrays[Mesh.ARRAY_COLOR] = color_array
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)


const slide_arrows_per_unit_length := 10
func make_slide_trail_mesh(note: Dictionary) -> ArrayMesh:
	# Generates a mesh centered around origin. Make sure the MeshInstance2D that draws this is centered on the screen.
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PoolVector2Array()
	var uvs := PoolVector2Array()
	var colors := PoolColorArray()
	var size := theme.sprite_size2
	var color := Color(0.67, 0.67, 1.0)
	if note.double_hit:
		color = Color(1.0, 1.0, 0.35)

	# First we need to determine how many arrows to leave.
	var unit_length: float
	var trail_length: int
	match note.slide_type:
		Note.SlideType.CHORD:
			unit_length = 2*abs(sin((RADIAL_COL_ANGLES[note.column_release] - RADIAL_COL_ANGLES[note.column])/2))
		Note.SlideType.ARC_CW:
			unit_length = fposmod(RADIAL_COL_ANGLES[note.column_release] - RADIAL_COL_ANGLES[note.column], TAU)
		Note.SlideType.ARC_ACW:
			unit_length = fposmod(RADIAL_COL_ANGLES[note.column] - RADIAL_COL_ANGLES[note.column_release], TAU)
	trail_length = int(floor(unit_length * slide_arrows_per_unit_length))
	vertices.resize(3*trail_length)
#	uvs.resize(3*trail_length)
	colors.resize(3*trail_length)
	for i in trail_length:
		uvs.append_array(UV_ARRAY_SLIDE_ARROW if i%3 else UV_ARRAY_SLIDE_ARROW2)
		for j in 3:
#			uvs[i*3+j] = UV_ARRAY_SLIDE_ARROW[j] if i%2 else UV_ARRAY_SLIDE_ARROW2[j]
			colors[i*3+j] = Color(color.r, color.g, color.b, (1.0+float(i))/float(trail_length))

	match note.slide_type:
		Note.SlideType.CHORD:
			var start : Vector2 = RADIAL_UNIT_VECTORS[note.column] * theme.receptor_ring_radius
			var end : Vector2 = RADIAL_UNIT_VECTORS[note.column_release] * theme.receptor_ring_radius
			var angle : float = (end-start).angle()
			var uv1o : Vector2 = polar2cartesian(size, angle)
			var uv2o : Vector2 = polar2cartesian(size, angle+PI/2.0)
			var uv3o : Vector2 = polar2cartesian(size, angle-PI/2.0)
			for i in trail_length:
				var offset : Vector2 = lerp(start, end, i/float(trail_length))
				vertices[i*3] = offset + uv1o
				vertices[i*3+1] = offset + uv2o
				vertices[i*3+2] = offset + uv3o
		Note.SlideType.ARC_CW:
			var start_a : float = RADIAL_COL_ANGLES[note.column]
			var end_a : float = RADIAL_COL_ANGLES[note.column_release]
			if end_a < start_a:
				end_a += TAU
			for i in trail_length:
				var circle_angle : float = lerp(start_a, end_a, (i+1)/float(trail_length))
				var angle : float = circle_angle + PI/2.0
				var offset : Vector2 = polar2cartesian(theme.receptor_ring_radius, circle_angle)
				vertices[i*3] = offset + polar2cartesian(size, angle)
				vertices[i*3+1] = offset + polar2cartesian(size, angle+PI/2.0)
				vertices[i*3+2] = offset + polar2cartesian(size, angle-PI/2.0)
		Note.SlideType.ARC_ACW:
			var start_a : float = RADIAL_COL_ANGLES[note.column]
			var end_a : float = RADIAL_COL_ANGLES[note.column_release]
			if end_a > start_a:
				end_a -= TAU
			for i in trail_length:
				var circle_angle : float = lerp(start_a, end_a, (i+1)/float(trail_length))
				var angle : float = circle_angle - PI/2.0
				var offset : Vector2 = polar2cartesian(theme.receptor_ring_radius, circle_angle)
				vertices[i*3] = offset + polar2cartesian(size, angle)
				vertices[i*3+1] = offset + polar2cartesian(size, angle+PI/2.0)
				vertices[i*3+2] = offset + polar2cartesian(size, angle-PI/2.0)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh



func make_tap_note(mesh: ArrayMesh, column: int, position: float, scale := 1.0, color_array := theme.COLOR_ARRAY_TAP) -> ArrayMesh:
	if position < theme.INNER_NOTE_CIRCLE_RATIO:
		scale *= position/theme.INNER_NOTE_CIRCLE_RATIO
		position = theme.INNER_NOTE_CIRCLE_RATIO
	var note_center = screen_center + (RADIAL_UNIT_VECTORS[column] * position * theme.receptor_ring_radius)
	var dim = theme.sprite_size2 * scale
	var vertices = PoolVector2Array([note_center + Vector2(-dim, -dim), note_center + Vector2(dim, -dim), note_center + Vector2(-dim, dim), note_center + Vector2(dim, dim)])
	make_tap_mesh(mesh, vertices, color_array)
	return mesh

func make_hold_note(mesh: ArrayMesh, column: int, position1: float, position2: float, scale := 1.0, color_array = theme.COLOR_ARRAY_HOLD) -> ArrayMesh:
	if position1 < theme.INNER_NOTE_CIRCLE_RATIO:
		scale *= position1/theme.INNER_NOTE_CIRCLE_RATIO
		position1 = theme.INNER_NOTE_CIRCLE_RATIO
	if position2 < theme.INNER_NOTE_CIRCLE_RATIO:
		position2 = theme.INNER_NOTE_CIRCLE_RATIO
	var note_center1 = screen_center + (RADIAL_UNIT_VECTORS[column] * position1 * theme.receptor_ring_radius)
	var note_center2 = screen_center + (RADIAL_UNIT_VECTORS[column] * position2 * theme.receptor_ring_radius)
	var dim = theme.sprite_size2 * scale
	var dim2 = dim * SQRT2
	var angle = RADIAL_COL_ANGLES[column]
	var a1 = angle - DEG45
	var a2 = angle + DEG45
	var a3 = angle - DEG90
	var a4 = angle + DEG90
	var a5 = angle - DEG135
	var a6 = angle + DEG135
	var vertices = PoolVector2Array([
		note_center1 + dim2*Vector2(cos(a1), sin(a1)), note_center1 + dim2*Vector2(cos(a2), sin(a2)),
		note_center1 + dim*Vector2(cos(a3), sin(a3)), note_center1 + dim*Vector2(cos(a4), sin(a4)),
		note_center2 + dim*Vector2(cos(a3), sin(a3)), note_center2 + dim*Vector2(cos(a4), sin(a4)),
		note_center2 + dim2*Vector2(cos(a5), sin(a5)), note_center2 + dim2*Vector2(cos(a6), sin(a6))
		])
	make_hold_mesh(mesh, vertices, color_array)
	return mesh

func make_slide_note(mesh: ArrayMesh, column: int, position: float, speed := 1.0, scale := 1.0, color_array := theme.COLOR_ARRAY_STAR) -> ArrayMesh:
	if position < theme.INNER_NOTE_CIRCLE_RATIO:
		scale *= position/theme.INNER_NOTE_CIRCLE_RATIO
		position = theme.INNER_NOTE_CIRCLE_RATIO
	var note_center = screen_center + (RADIAL_UNIT_VECTORS[column] * position * theme.receptor_ring_radius)
	var dim = theme.sprite_size2 * scale * SQRT2
	var angle = fmod(t*speed, 1.0)*TAU
	var a1 = angle - DEG45
	var a2 = angle + DEG45
	var a3 = angle - DEG135
	var a4 = angle + DEG135
	var vertices = PoolVector2Array([
		note_center + dim*Vector2(cos(a1), sin(a1)), note_center + dim*Vector2(cos(a2), sin(a2)),
		note_center + dim*Vector2(cos(a3), sin(a3)), note_center + dim*Vector2(cos(a4), sin(a4))
		])
	make_star_mesh(mesh, vertices, color_array)
	return mesh


#----------------------------------------------------------------------------------------------------------------------------------------------

func _init():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	init_radial_values()

func _draw():
	var mesh := ArrayMesh.new()
#	var dots := PoolVector2Array()
#	var dots_dict := {}

	var noteline_data : Image = noteline_array_image.get_rect(Rect2(0, 0, 16, 16))
	noteline_data.lock()
	var i := 0
	var j := 0

	for note in active_notes:
		var position : float = (t+theme.note_forecast_beats-note.time_hit)/theme.note_forecast_beats
		noteline_data.set_pixel(i%16, i/16, Color(position, note.column, RADIAL_COL_ANGLES[note.column]))
		i += 1
		match note.type:
			Note.NOTE_TAP:
				var color = theme.COLOR_ARRAY_DOUBLE_4 if note.double_hit else theme.COLOR_ARRAY_TAP
				make_tap_note(mesh, note.column, position, 1, color)
			Note.NOTE_HOLD:
				var color = theme.COLOR_ARRAY_DOUBLE_8 if note.double_hit else theme.COLOR_ARRAY_HOLD
				var position_rel : float = (t+theme.note_forecast_beats-note.time_release)/theme.note_forecast_beats
				if position_rel > 0:
					var note_rel_center := screen_center + (RADIAL_UNIT_VECTORS[note.column] * position_rel * theme.receptor_ring_radius)
					noteline_data.set_pixel(j%16, 15, Color(position_rel, note.column, RADIAL_COL_ANGLES[note.column]))
					j += 1
				make_hold_note(mesh, note.column, position, position_rel, 1.0, theme.COLOR_ARRAY_HOLD_HELD)
			Note.NOTE_SLIDE:
				var color = theme.COLOR_ARRAY_DOUBLE_4 if note.double_hit else theme.COLOR_ARRAY_STAR
				make_slide_note(mesh, note.column, position, 1.0, color)
				var trail_alpha := 1.0
				if position < theme.INNER_NOTE_CIRCLE_RATIO:
					trail_alpha = 0.0
				elif position < 1.0:
					trail_alpha = min(1.0, (position-theme.INNER_NOTE_CIRCLE_RATIO)/(1-theme.INNER_NOTE_CIRCLE_RATIO*2))
				else:
					var trail_progress : float = clamp((t - note.time_hit - theme.SLIDE_DELAY)/(note.duration - theme.SLIDE_DELAY), 0.0, 1.0)
					slide_trail_mesh_instances[note.slide_id].material.set_shader_param("trail_progress", trail_progress)
					if t > note.time_release:
						trail_alpha = max(1 - (t - note.time_release)/Note.DEATH_DELAY, 0.0)
				slide_trail_mesh_instances[note.slide_id].material.set_shader_param("base_alpha", trail_alpha*0.88)

	noteline_data.unlock()
	var noteline_data_tex = ImageTexture.new()
	noteline_data_tex.create_from_image(noteline_data, 0)
	$notelines.set_texture(noteline_data_tex)

	$meshinstance.set_mesh(mesh)
#	draw_mesh(mesh, tex)

var noteline_array_image := Image.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	t = 0.0
	time = -2.0
	bpm = 120.0
	active_notes = []
	all_notes = []
	next_note_to_load = 0

	$meshinstance.material.set_shader_param("star_color", theme.COLOR_STAR)
	$meshinstance.material.set_shader_param("held_color", theme.COLOR_HOLD_HELD)
	$meshinstance.material.set_shader_param("bps", bpm/60.0)
	$meshinstance.material.set_shader_param("screen_size", get_viewport().get_size())
	$meshinstance.set_texture(tex)

	var rec_scale1 = (float(screen_height)/float(theme.receptor_ring_radius))*0.5
	var uv_array_playfield := PoolVector2Array([Vector2(-1.0, -1.0)*rec_scale1, Vector2(-1.0, 1.0)*rec_scale1, Vector2(1.0, -1.0)*rec_scale1, Vector2(1.0, 1.0)*rec_scale1])
	var vertex_array_playfield := PoolVector2Array([
		Vector2(x_margin, screen_height), Vector2(x_margin, 0.0),
		Vector2(x_margin+screen_height, screen_height), Vector2(x_margin+screen_height, 0.0)])
	var mesh_playfield := ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array_playfield
	arrays[Mesh.ARRAY_NORMAL] = NORMAL_ARRAY_4
	arrays[Mesh.ARRAY_TEX_UV] = uv_array_playfield
	mesh_playfield.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	$notelines.set_mesh(mesh_playfield)
	$notelines.material.set_shader_param("bps", bpm/60.0)

	noteline_array_image.create(16, 16, false, Image.FORMAT_RGBF)
	noteline_array_image.fill(Color(0.0, 0.0, 0.0))
	# Format: first 15 rows are for hit events, last row is for releases only (no ring glow)

	all_notes = FileLoader.SRT.load_file("res://songs/199_cirno_master.srt")
	bpm = 175.0
	sync_offset_audio = 0.553
	sync_offset_video = 0.553
#	all_notes = FileLoader.Test.stress_pattern()

	Note.process_note_list(all_notes)
	for note in all_notes:
		if note.type == Note.NOTE_SLIDE:
			slide_trail_meshes[note.slide_id] = make_slide_trail_mesh(note)

func game_time(realtime: float) -> float:
	return time * bpm / 60.0

func video_start_time() -> float:
	# We give a 4 beat delay until the first note of the chart. Should have a sound for each beat.
	var four_beats := 4.0 * 60.0/bpm
	return four_beats - sync_offset_video

func audio_start_time() -> float:
	var four_beats := 4.0 * 60.0/bpm
	return four_beats - sync_offset_audio

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$meshinstance.material.set_shader_param("bps", bpm/60.0)
	$notelines.material.set_shader_param("bps", bpm/60.0)

	var t_old := game_time(time)
	time += delta
	t = game_time(time)

#	if (t_old < 0) and (t >= 0):
#		get_node("/root/main/video").play()
	var vt_delta := time - video_start_time()
	if (vt_delta >= 0.0) and not get_node("/root/main/video").is_playing():
		get_node("/root/main/video").play()
		get_node("/root/main/video").set_stream_position(vt_delta)

	# Clean out expired notes
	for i in range(len(active_notes)-1, -1, -1):
		var note = active_notes[i]
		if note.time_death < t:
			if note.type == Note.NOTE_SLIDE:
				$SlideTrailHandler.remove_child(slide_trail_mesh_instances[note.slide_id])
				slide_trail_mesh_instances.erase(note.slide_id)
			active_notes.remove(i)

	# Add new notes as necessary
	while true:
		if next_note_to_load >= len(all_notes):
			# All notes have been loaded, maybe do something
			break
		if all_notes[next_note_to_load].time_hit > (t + theme.note_forecast_beats):
			# Next chronological note isn't ready to load yet
			break
		# Next chronological note is ready to load, load it
		var note = all_notes[next_note_to_load]
		active_notes.push_back(note)
		if note.type == Note.NOTE_SLIDE:
			var meshi = MeshInstance2D.new()
			meshi.set_mesh(slide_trail_meshes[note.slide_id])
#			meshi.set_position(screen_center)
			meshi.set_material(slide_trail_shadermaterial.duplicate())
			meshi.material.set_shader_param("trail_progress", 0.0)
			meshi.set_texture(tex_slide_arrow)
			slide_trail_mesh_instances[note.slide_id] = meshi
			$SlideTrailHandler.add_child(meshi)

		next_note_to_load += 1

	# DEBUG: Reset after all notes are done
	if (len(active_notes) < 1) and (next_note_to_load >= len(all_notes)) and (time > 10.0) and not get_node("/root/main/video").is_playing():
		time = -2.0
		next_note_to_load = 0

	# Redraw
	$meshinstance.material.set_shader_param("screen_size", get_viewport().get_size())
	update()
