extends "res://main.gd"

# This script will draw all note events.
var running := false

var tex := preload("res://assets/spritesheet-4k.png")
var tex_judgement_text := preload("res://assets/text-4k.png")
var tex_slide_arrow := preload("res://assets/slide-arrow-4k.png")
var slide_trail_shadermaterial := preload("res://shaders/slidetrail.tres")

var snd_miss := preload("res://assets/miss.wav")
var snd_clap := preload("res://assets/softclap.wav")
var snd_count_in := snd_clap
var snd_judgement := {
	0: snd_clap,
	1: snd_clap,
	-1: snd_clap,
	2: snd_clap,
	-2: snd_clap,
	3: snd_miss,
	-3: snd_miss,
	"MISS": snd_miss
}
var db_judgement := {
	0: 0.0,
	1: -1.5,
	-1: -1.5,
	2: -3.0,
	-2: -3.0,
	3: -6.0,
	-3: -6.0,
	"MISS": 0.0
}
var pitch_judgement := {
	0: 1.0,
	-1: 1.0/0.75,
	1: 0.75,
	-2: 1.0/0.60,
	2: 0.60,
	-3: 1.5,
	3: 1.5,
	"MISS": 1.0
}

const SQRT2 := sqrt(2)
const DEG45 := deg2rad(45.0)
const DEG90 := deg2rad(90.0)
const DEG135 := deg2rad(135.0)

var time_zero_msec: int = 0
var time: float = 0.0
var t: float = 0.0  # Game time
var bpm: float = 120.0
var sync_offset_video: float = 0.0  # Time in seconds to the first beat
var sync_offset_audio: float = 0.0  # Time in seconds to the first beat

var active_notes := []
var all_notes := []
var next_note_to_load := 0
var active_judgement_texts := []
var scores := {}

var slide_trail_meshes := {}
var slide_trail_mesh_instances := {}

var noteline_array_image := Image.new()

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

# Text UVs
var text_UV_arrays := []
func make_text_UV(row: int, column: int) -> PoolVector2Array:
	return PoolVector2Array([Vector2(column/4.0, row/8.0), Vector2((column+1)/4.0, row/8.0), Vector2(column/4.0, (row+1)/8.0), Vector2((column+1)/4.0, (row+1)/8.0)])
func make_text_UVs():
	for row in 8:
		for column in 4:
			text_UV_arrays.append(make_text_UV(row, column))
enum TextStyle {STRAIGHT=0, ARC=1, ARC_EARLY=2, ARC_LATE=3}
enum TextWord {NICE=0, OK=4, NG=8, PERFECT=12, GREAT=16, GOOD=20, ALMOST=24, MISS=28}
const TextJudgement := {
	0: TextWord.PERFECT + TextStyle.ARC,
	1: TextWord.GREAT + TextStyle.ARC_LATE,
	-1: TextWord.GREAT + TextStyle.ARC_EARLY,
	2: TextWord.GOOD + TextStyle.ARC_LATE,
	-2: TextWord.GOOD + TextStyle.ARC_EARLY,
	3: TextWord.ALMOST + TextStyle.ARC_LATE,
	-3: TextWord.ALMOST + TextStyle.ARC_EARLY,
	"MISS": TextWord.MISS + TextStyle.ARC
}

func initialise_scores():
	scores = {}
	for type in [Note.NOTE_TAP, Note.NOTE_HOLD, Note.NOTE_SLIDE]:
		scores[type] = {}
		for key in TextJudgement:
			scores[type][key] = 0

func make_text_mesh(mesh: ArrayMesh, text_id: int, pos: Vector2, angle: float, alpha:=1.0, scale:=1.0):
	var r := GameTheme.judge_text_size2 * scale
	var vertex_array := PoolVector2Array([
		pos+polar2cartesian(r, angle+GameTheme.JUDGE_TEXT_ANG2), # TODO: fix this UV/vertex order mess
		pos+polar2cartesian(r, angle+GameTheme.JUDGE_TEXT_ANG1),
		pos+polar2cartesian(r, angle+GameTheme.JUDGE_TEXT_ANG4),
		pos+polar2cartesian(r, angle+GameTheme.JUDGE_TEXT_ANG3)
	])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_TEX_UV] = text_UV_arrays[text_id]
	arrays[Mesh.ARRAY_COLOR] = GameTheme.color_array_text(alpha)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)

func make_judgement_text(mesh: ArrayMesh, text_id: int, col: int, progress:=0.0):
	make_text_mesh(mesh, text_id,
		GameTheme.RADIAL_UNIT_VECTORS[col] * GameTheme.receptor_ring_radius * lerp(0.85, 0.85*0.75, progress),
		GameTheme.RADIAL_COL_ANGLES[col]-PI/2.0, lerp(1.0, 0.0, progress), lerp(1.0, 0.75, progress)
	)

# ----------------------------------------------------------------------------------------------------------------------------------------------------
# Helper functions to generate meshes from vertex arrays
func make_tap_mesh(mesh: ArrayMesh, note_center: Vector2, scale:=1.0, color_array:=GameTheme.COLOR_ARRAY_TAP):
	var dim = GameTheme.sprite_size2 * scale
	var vertex_array = PoolVector2Array([note_center + Vector2(-dim, -dim), note_center + Vector2(dim, -dim), note_center + Vector2(-dim, dim), note_center + Vector2(dim, dim)])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
#	arrays[Mesh.ARRAY_NORMAL] = NORMAL_ARRAY_4
	arrays[Mesh.ARRAY_TEX_UV] = UV_ARRAY_TAP
	arrays[Mesh.ARRAY_COLOR] = color_array
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)

func make_hold_mesh(mesh: ArrayMesh, note_center: Vector2, note_center_rel: Vector2, scale:=1.0, angle:=0.0, color_array = GameTheme.COLOR_ARRAY_HOLD):
	var dim = GameTheme.sprite_size2 * scale
	var dim2 = dim * SQRT2
	var a1 = angle - DEG45
	var a2 = angle + DEG45
	var a3 = angle - DEG90
	var a4 = angle + DEG90
	var a5 = angle - DEG135
	var a6 = angle + DEG135
	var vertex_array = PoolVector2Array([
		note_center + polar2cartesian(dim2, a1), note_center + polar2cartesian(dim2, a2),
		note_center + polar2cartesian(dim, a3), note_center + polar2cartesian(dim, a4),
		note_center_rel + polar2cartesian(dim, a3), note_center_rel + polar2cartesian(dim, a4),
		note_center_rel + polar2cartesian(dim2, a5), note_center_rel + polar2cartesian(dim2, a6)
		])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
#	arrays[Mesh.ARRAY_NORMAL] = NORMAL_ARRAY_8
	arrays[Mesh.ARRAY_TEX_UV] = UV_ARRAY_HOLD
	arrays[Mesh.ARRAY_COLOR] = color_array
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)

func make_star_mesh(mesh: ArrayMesh, note_center: Vector2, scale:=1.0, angle:=0.0, color_array:=GameTheme.COLOR_ARRAY_STAR):
	var dim = GameTheme.sprite_size2 * scale * SQRT2
	var a1 = angle - DEG45
	var a2 = angle + DEG45
	var a3 = angle - DEG135
	var a4 = angle + DEG135
	var vertex_array = PoolVector2Array([
		note_center + polar2cartesian(dim, a1), note_center + polar2cartesian(dim, a2),
		note_center + polar2cartesian(dim, a3), note_center + polar2cartesian(dim, a4)
		])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
#	arrays[Mesh.ARRAY_NORMAL] = NORMAL_ARRAY_4
	arrays[Mesh.ARRAY_TEX_UV] = UV_ARRAY_STAR
	arrays[Mesh.ARRAY_COLOR] = color_array
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)

#func make_arrow_mesh(mesh: ArrayMesh, vertex_array, color_array = GameTheme.COLOR_ARRAY_TAP):
#	var arrays = []
#	arrays.resize(Mesh.ARRAY_MAX)
#	arrays[Mesh.ARRAY_VERTEX] = vertex_array
##	arrays[Mesh.ARRAY_NORMAL] = NORMAL_ARRAY_4
#	arrays[Mesh.ARRAY_TEX_UV] = UV_ARRAY_ARROW
#	arrays[Mesh.ARRAY_COLOR] = color_array
#	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)


const slide_arrows_per_unit_length := 10
func make_slide_trail_mesh(note) -> ArrayMesh:
	# Generates a mesh centered around origin. Make sure the MeshInstance2D that draws this is centered on the screen.
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PoolVector2Array()
	var uvs := PoolVector2Array()
	var colors := PoolColorArray()
	var size := GameTheme.sprite_size2
	var color := Color(0.67, 0.67, 1.0)
	if note.double_hit:
		color = Color(1.0, 1.0, 0.35)

	# First we need to determine how many arrows to leave.
	var trail_length : int = int(floor(note.get_slide_length() * slide_arrows_per_unit_length))
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
			var angle : float = note.get_angle(0)
			var uv1o : Vector2 = polar2cartesian(size, angle)
			var uv2o : Vector2 = polar2cartesian(size, angle+PI/2.0)
			var uv3o : Vector2 = polar2cartesian(size, angle-PI/2.0)
			for i in trail_length:
				var offset : Vector2 = note.get_position((i+1)/float(trail_length))
				vertices[i*3] = offset + uv1o
				vertices[i*3+1] = offset + uv2o
				vertices[i*3+2] = offset + uv3o
		Note.SlideType.ARC_CW:
			for i in trail_length:
				var angle : float = note.get_angle((i+1)/float(trail_length))
				var offset : Vector2 = note.get_position((i+1)/float(trail_length))
				vertices[i*3] = offset + polar2cartesian(size, angle)
				vertices[i*3+1] = offset + polar2cartesian(size, angle+PI/2.0)
				vertices[i*3+2] = offset + polar2cartesian(size, angle-PI/2.0)
		Note.SlideType.ARC_ACW:
			for i in trail_length:
				var angle : float = note.get_angle((i+1)/float(trail_length))
				var offset : Vector2 = note.get_position((i+1)/float(trail_length))
				vertices[i*3] = offset + polar2cartesian(size, angle)
				vertices[i*3+1] = offset + polar2cartesian(size, angle+PI/2.0)
				vertices[i*3+2] = offset + polar2cartesian(size, angle-PI/2.0)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

#----------------------------------------------------------------------------------------------------------------------------------------------
func activate_note(note, judgement):
	active_judgement_texts.append({col=note.column, judgement=judgement, time=t})
	SFXPlayer.play(SFXPlayer.Type.NON_POSITIONAL, self, snd_judgement[judgement], db_judgement[judgement], pitch_judgement[judgement])
	scores[note.type][judgement] += 1

	note.time_activated = t
	match note.type:
		Note.NOTE_HOLD:
			note.is_held = true
		Note.NOTE_SLIDE:
			pass # Set up slide trail?
	return

func button_pressed(col):
	for note in active_notes:
		if note.column != col:
			continue
		if note.time_activated != INF:
			continue
		#var hit_delta = real_time(t - note.time_hit)  # Judgement times are in seconds not gametime
		var hit_delta = get_realtime_precise() - real_time(note.time_hit)  # Judgement times are in seconds not gametime
		if hit_delta >= 0.0:
			if hit_delta > Rules.JUDGEMENT_TIMES_POST[-1]:
				continue  # missed
			for i in Rules.JUDGEMENT_TIERS:
				if hit_delta <= Rules.JUDGEMENT_TIMES_POST[i]:
					activate_note(note, i)
					return
		else:
			if -hit_delta > Rules.JUDGEMENT_TIMES_PRE[-1]:
				continue  # too far away
			for i in Rules.JUDGEMENT_TIERS:
				if -hit_delta <= Rules.JUDGEMENT_TIMES_POST[i]:
					activate_note(note, -i)
					return

func touchbutton_pressed(col):
	button_pressed(col)

func check_hold_release(col):
	for note in active_notes:
		if note.column != col:
			continue
		if note.type == Note.NOTE_HOLD:
			if note.is_held == true:
				note.is_held = false
				pass

func button_released(col):
	# We only care about hold release.
	# For that particular case, we want both to be unheld.
	if $"/root/main/InputHandler".touchbuttons_pressed[col] == 0:
		check_hold_release(col)

func touchbutton_released(col):
	if $"/root/main/InputHandler".buttons_pressed[col] == 0:
		check_hold_release(col)

#----------------------------------------------------------------------------------------------------------------------------------------------
func _draw():
	var mesh := ArrayMesh.new()
	var noteline_data : Image = noteline_array_image.get_rect(Rect2(0, 0, 16, 16))
	noteline_data.lock()
	var i := 0
	var j := 0

	for note in active_notes:
		var position : float = (t+GameTheme.note_forecast_beats-note.time_hit)/GameTheme.note_forecast_beats
		var scale := 1.0
		noteline_data.set_pixel(i%16, i/16, Color(position, note.column, GameTheme.RADIAL_COL_ANGLES[note.column]))
		i += 1
		if position < GameTheme.INNER_NOTE_CIRCLE_RATIO:
			scale *= position/GameTheme.INNER_NOTE_CIRCLE_RATIO
			position = GameTheme.INNER_NOTE_CIRCLE_RATIO
		var note_center = (GameTheme.RADIAL_UNIT_VECTORS[note.column] * position * GameTheme.receptor_ring_radius)
		var color: PoolColorArray
		match note.type:
			Note.NOTE_TAP:
				if note.time_hit >= t:
					color = GameTheme.color_array_tap(1.0, note.double_hit)
				else:
					color = GameTheme.color_array_tap(clamp((note.time_death-t)/Note.DEATH_DELAY, 0.0, 1.0), note.double_hit)
				make_tap_mesh(mesh, note_center, scale, color)
			Note.NOTE_HOLD:
				color = GameTheme.COLOR_ARRAY_DOUBLE_8 if note.double_hit else GameTheme.COLOR_ARRAY_HOLD
				if note.is_held:
					color = GameTheme.COLOR_ARRAY_HOLD_HELD
				var position_rel : float = (t+GameTheme.note_forecast_beats-note.time_release)/GameTheme.note_forecast_beats
				if position_rel > 0:
					var note_rel_center := (GameTheme.RADIAL_UNIT_VECTORS[note.column] * position_rel * GameTheme.receptor_ring_radius)
					noteline_data.set_pixel(j%16, 15, Color(position_rel, note.column, GameTheme.RADIAL_COL_ANGLES[note.column]))
					j += 1
				if position_rel < GameTheme.INNER_NOTE_CIRCLE_RATIO:
					position_rel = GameTheme.INNER_NOTE_CIRCLE_RATIO
				var note_center_rel = (GameTheme.RADIAL_UNIT_VECTORS[note.column] * position_rel * GameTheme.receptor_ring_radius)
				make_hold_mesh(mesh, note_center, note_center_rel, scale, GameTheme.RADIAL_COL_ANGLES[note.column], color)
			Note.NOTE_SLIDE:
				color = GameTheme.COLOR_ARRAY_DOUBLE_4 if note.double_hit else GameTheme.COLOR_ARRAY_STAR
				var angle = fmod(t/note.duration, 1.0)*TAU
				make_star_mesh(mesh, note_center, scale, angle, color)
				var trail_alpha := 1.0
				if position < GameTheme.INNER_NOTE_CIRCLE_RATIO:
					trail_alpha = 0.0
				elif position < 1.0:
					trail_alpha = min(1.0, (position-GameTheme.INNER_NOTE_CIRCLE_RATIO)/(1-GameTheme.INNER_NOTE_CIRCLE_RATIO*2))
				else:
					var trail_progress : float = clamp((t - note.time_hit - GameTheme.SLIDE_DELAY)/(note.duration - GameTheme.SLIDE_DELAY), 0.0, 1.0)
					var star_pos : Vector2 = note.get_position(trail_progress)
					var star_angle : float = note.get_angle(trail_progress)
					make_star_mesh(mesh, star_pos, 1.33, star_angle, color)
#					slide_trail_mesh_instances[note.slide_id].material.set_shader_param("trail_progress", trail_progress)
					if t > note.time_release:
						trail_alpha = max(1 - (t - note.time_release)/Note.DEATH_DELAY, 0.0)
				slide_trail_mesh_instances[note.slide_id].material.set_shader_param("base_alpha", trail_alpha*0.88)

	noteline_data.unlock()
	var noteline_data_tex = ImageTexture.new()
	noteline_data_tex.create_from_image(noteline_data, 0)
	$notelines.set_texture(noteline_data_tex)

	$meshinstance.set_mesh(mesh)
#	draw_mesh(mesh, tex)

	var textmesh := ArrayMesh.new()
	for text in active_judgement_texts:
		make_judgement_text(textmesh, TextJudgement[text.judgement], text.col, (t-text.time)/GameTheme.judge_text_duration)
	$JudgeText.set_mesh(textmesh)

func _init():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	GameTheme.init_radial_values()
	make_text_UVs()
	initialise_scores()

func set_time(seconds: float):
	var msecs = OS.get_ticks_msec()
	time_zero_msec = msecs - (seconds * 1000)
	time = seconds
	t = game_time(time)

# Called when the node enters the scene tree for the first time.
func _ready():
	var rec_scale1 = (float(screen_height)/float(GameTheme.receptor_ring_radius))*0.5
	var uv_array_playfield := PoolVector2Array([Vector2(-1.0, -1.0)*rec_scale1, Vector2(-1.0, 1.0)*rec_scale1, Vector2(1.0, -1.0)*rec_scale1, Vector2(1.0, 1.0)*rec_scale1])
	var vertex_array_playfield := PoolVector2Array([
		Vector2(-screen_height/2.0, screen_height/2.0), Vector2(-screen_height/2.0, -screen_height/2.0),
		Vector2(screen_height/2.0, screen_height/2.0), Vector2(screen_height/2.0, -screen_height/2.0)])
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

	$"/root/main/InputHandler".connect("button_pressed", self, "button_pressed")
	$"/root/main/InputHandler".connect("touchbutton_pressed", self, "touchbutton_pressed")
	$"/root/main/InputHandler".connect("button_released", self, "button_released")
	$"/root/main/InputHandler".connect("touchbutton_released", self, "touchbutton_released")

func load_track(data: Dictionary, difficulty_idx: int):
	set_time(-3.0)
	active_notes = []
	all_notes = []
	next_note_to_load = 0
	all_notes = FileLoader.SRT.load_file(data.directory + "/" + data.chart_filelist[difficulty_idx])
	bpm = data.bpm_values[0]
	sync_offset_audio = data.audio_offsets[0]
	sync_offset_video = data.video_offsets[0]
	var audiostream = AudioStreamOGGVorbis.new()
#	var asb = load(data.directory + "/" + data.audio_filelist[0])
#	audiostream.set_data(asb.get_data())
	# Unbelievably stupid bug, infuriating workaround
	var oggfile = File.new()
	oggfile.open(data.directory + "/" + data.audio_filelist[0], File.READ)
	audiostream.set_data(oggfile.get_buffer(oggfile.get_len()))
	oggfile.close()
	var videostream = load(data.directory + "/" + data.video_filelist[0])

	$"/root/main/music".set_stream(audiostream)
	$"/root/main/video".set_stream(videostream)
	$"/root/main/video".update_aspect_ratio(data.video_dimensions[0]/data.video_dimensions[1])
#	all_notes = FileLoader.Test.stress_pattern()

	Note.process_note_list(all_notes)
	for note in all_notes:
		if note.type == Note.NOTE_SLIDE:
			slide_trail_meshes[note.slide_id] = make_slide_trail_mesh(note)

	$meshinstance.material.set_shader_param("star_color", GameTheme.COLOR_STAR)
	$meshinstance.material.set_shader_param("held_color", GameTheme.COLOR_HOLD_HELD)
	$meshinstance.material.set_shader_param("bps", bpm/60.0)
	$meshinstance.material.set_shader_param("screen_size", get_viewport().get_size())
	$meshinstance.set_texture(tex)


func intro_click():
	SFXPlayer.play(SFXPlayer.Type.NON_POSITIONAL, self, snd_count_in)

func get_realtime_precise() -> float:
	# Usually we only update the gametime once per process loop, but for input callbacks it's good to have msec precision
	return (OS.get_ticks_msec() - time_zero_msec)/1000.0

func game_time(realtime: float) -> float:
	return realtime * bpm / 60.0

func real_time(gametime: float) -> float:
	return gametime * 60.0 / bpm

func video_start_time() -> float:
	return -sync_offset_video

func audio_start_time() -> float:
	return -sync_offset_audio

# Called every frame. 'delta' is the elapsed time since the previous frame.
var timers_set := false
func _process(delta):
	if !running:
		return

	$meshinstance.material.set_shader_param("bps", bpm/60.0)
	$notelines.material.set_shader_param("bps", bpm/60.0)

	var t_old := game_time(time)
#	time += delta
	time = get_realtime_precise()
	t = game_time(time)

	if (not timers_set) and (t > -5.0):
		timers_set = true
		for i in [-4.0, -3.0, -2.0, -1.0]:
			var delay := real_time(i) - time
			var timer = Timer.new()
			timer.set_one_shot(false)
#			timer.set_timer_process_mode(Timer.TIMER_PROCESS_FIXED)
			timer.set_wait_time(delay)
			timer.connect("timeout", self, "intro_click")
			timer.start()
			add_child(timer)
			timer.connect("timeout", timer, "queue_free")

#	if (t_old < 0) and (t >= 0):
#		get_node("/root/main/video").play()
	var vt_delta := time - video_start_time()
	if (0.0 <= vt_delta) and (vt_delta < 1.0) and not get_node("/root/main/video").is_playing():
		get_node("/root/main/video").play()
		get_node("/root/main/video").set_stream_position(vt_delta)
	var at_delta := time - audio_start_time()
	if (0.0 <= at_delta) and (at_delta < 1.0) and not get_node("/root/main/music").is_playing():
#		get_node("/root/main/music").play()
#		get_node("/root/main/music").seek(at_delta)
		get_node("/root/main/music").play(at_delta)

	# Clean out expired notes
	var miss_time: float = Rules.JUDGEMENT_TIMES_POST[-1] * bpm/60.0
	for i in range(len(active_notes)-1, -1, -1):
		var note = active_notes[i]
		if note.time_death < t:
			if note.type == Note.NOTE_SLIDE:
				$SlideTrailHandler.remove_child(slide_trail_mesh_instances[note.slide_id])
				slide_trail_mesh_instances.erase(note.slide_id)
			active_notes.remove(i)
		elif note.time_activated == INF:
			if ((t-note.time_hit) > miss_time) and not note.missed:
				active_judgement_texts.append({col=note.column, judgement="MISS", time=t})
				scores[note.type]["MISS"] += 1
				note.missed = true
				SFXPlayer.play(SFXPlayer.Type.NON_POSITIONAL, self, snd_judgement["MISS"], db_judgement["MISS"])

	# Clean out expired judgement texts
	# By design they will always be in order so we can ignore anything past the first index
	while (len(active_judgement_texts) > 0) and ((t-active_judgement_texts[0].time) > GameTheme.judge_text_duration):
		active_judgement_texts.pop_front()

	# Add new notes as necessary
	while true:
		if next_note_to_load >= len(all_notes):
			# All notes have been loaded, maybe do something
			break
		if all_notes[next_note_to_load].time_hit > (t + GameTheme.note_forecast_beats):
			# Next chronological note isn't ready to load yet
			break
		# Next chronological note is ready to load, load it
		var note = all_notes[next_note_to_load]
		active_notes.push_back(note)
		if note.type == Note.NOTE_SLIDE:
			var meshi = MeshInstance2D.new()
			meshi.set_mesh(slide_trail_meshes[note.slide_id])
			meshi.set_material(slide_trail_shadermaterial.duplicate())
			meshi.material.set_shader_param("trail_progress", 0.0)
			meshi.set_texture(tex_slide_arrow)
			slide_trail_mesh_instances[note.slide_id] = meshi
			$SlideTrailHandler.add_child(meshi)

		next_note_to_load += 1

	# DEBUG: Reset after all notes are done
#	if (len(active_notes) < 1) and (next_note_to_load >= len(all_notes)) and (time > 10.0) and not get_node("/root/main/video").is_playing():
#		time = -10.0
#		next_note_to_load = 0

	# Redraw
	$meshinstance.material.set_shader_param("screen_size", get_viewport().get_size())
	update()
