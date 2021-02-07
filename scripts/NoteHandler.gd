extends Control

var screen_height := 1080

# This script will draw all note events.
signal finished_song(song_key, score_data)
signal combo_changed(value)
var running := false
var song_key = ''

onready var MusicPlayer := SoundPlayer.music_player
onready var VideoPlayer := Video.video

onready var Painter = $'../Painter'
onready var SlideTrailHandler = $'Viewport/Center/SlideTrailHandler'
onready var JudgeText = $'Viewport/Center/JudgeText'
onready var notelines = $'Viewport/Center/notelines'
onready var meshinstance = $'Viewport/Center/meshinstance'
onready var lbl_combo = $lbl_combo

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

var active_slide_trails := []
var slide_trail_meshes := {}
var slide_trail_mesh_instances := {}

var noteline_array_image := Image.new()

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
	'MISS': TextWord.MISS + TextStyle.ARC
}
const TextJudgementStraight := {
	0: TextWord.PERFECT + TextStyle.STRAIGHT,
	1: TextWord.GREAT + TextStyle.STRAIGHT,
	-1: TextWord.GREAT + TextStyle.STRAIGHT,
	2: TextWord.GOOD + TextStyle.STRAIGHT,
	-2: TextWord.GOOD + TextStyle.STRAIGHT,
	3: TextWord.ALMOST + TextStyle.STRAIGHT,
	-3: TextWord.ALMOST + TextStyle.STRAIGHT,
	'MISS': TextWord.MISS + TextStyle.STRAIGHT
}

var current_combo := 0
func increment_combo():
	current_combo += 1
	emit_signal('combo_changed', current_combo)  # Make text or something?
func end_combo(no_reset := false):
	scores['max_combo'] = max(current_combo, scores.get('max_combo', 0))
	if not no_reset:  # A bit hacky, but we want the ability to cash in the max combo without resetting the counter for... playlist reasons?
		current_combo = 0
		emit_signal('combo_changed', 0)  # Womp womp effect somewhere?

func initialise_scores():
	scores = {}
	for type in [Note.NOTE_TAP, Note.NOTE_HOLD, Note.NOTE_STAR]:
		scores[type] = {}
		for key in TextJudgement:
			scores[type][key] = 0
	# Release types
	for type in [Note.NOTE_HOLD, Note.NOTE_SLIDE]:
		scores[Note.RELEASE_SCORE_TYPES[type]] = {}
		for key in TextJudgement:
			scores[Note.RELEASE_SCORE_TYPES[type]][key] = 0
	scores['max_combo'] = 0
	current_combo = 0

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
	arrays[Mesh.ARRAY_TEX_UV] = GameTheme.UV_ARRAY_TAP
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
	arrays[Mesh.ARRAY_TEX_UV] = GameTheme.UV_ARRAY_HOLD
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
	arrays[Mesh.ARRAY_TEX_UV] = GameTheme.UV_ARRAY_STAR
	arrays[Mesh.ARRAY_COLOR] = color_array
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)

#func make_arrow_mesh(mesh: ArrayMesh, vertex_array, color_array = GameTheme.COLOR_ARRAY_TAP):
#	var arrays = []
#	arrays.resize(Mesh.ARRAY_MAX)
#	arrays[Mesh.ARRAY_VERTEX] = vertex_array
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
	var size := GameTheme.sprite_size2 * sqrt(2)
	var color := GameTheme.COLOR_DOUBLE_SLIDE if note.double_hit else GameTheme.COLOR_SLIDE

	match note.get_points():
		[var positions, var angles]:
			var trail_length : int = len(positions)
			vertices.resize(3*trail_length)
			uvs.resize(3*trail_length)
			colors.resize(3*trail_length)
			for i in trail_length:
				var u = GameTheme.UV_ARRAY_SLIDE_ARROW if i%3 else GameTheme.UV_ARRAY_SLIDE_ARROW2
				for j in 3:
					uvs[i*3+j] = u[j]
					colors[i*3+j] = Color(color.r, color.g, color.b, (1.0+float(i))/float(trail_length))
				var angle : float = angles[i]
				var offset : Vector2 = positions[i] * GameTheme.receptor_ring_radius
				vertices[i*3] = offset
				vertices[i*3+1] = offset + polar2cartesian(size, angle+PI*0.75)
				vertices[i*3+2] = offset + polar2cartesian(size, angle-PI*0.75)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

#----------------------------------------------------------------------------------------------------------------------------------------------
func make_judgement_column(judgement, column: int):
	active_judgement_texts.append({col=column, judgement=judgement, time=t})
	SoundPlayer.play(SoundPlayer.Type.NON_POSITIONAL, self, GameTheme.snd_judgement[judgement], GameTheme.db_judgement[judgement], GameTheme.pitch_judgement[judgement])

func make_judgement_pos(judgement, pos: Vector2):
	# Positional judgement text not yet implemented, will do if touches are ever added
	#active_judgement_texts.append({judgement=judgement, time=t})
	SoundPlayer.play(SoundPlayer.Type.NON_POSITIONAL, self, GameTheme.snd_judgement[judgement], GameTheme.db_judgement[judgement], GameTheme.pitch_judgement[judgement])


func activate_note(note, judgement):
	make_judgement_column(judgement, note.column)
	scores[note.type][judgement] += 1

	note.time_activated = t
	match note.type:
		Note.NOTE_HOLD:
			note.is_held = true

	if abs(judgement) < 3:
		increment_combo()  # For now, only hits count toward building and maintaining combo. Releases and slides do not.
	else:
		end_combo()

func activate_note_release(note, judgement):
	# Only for Hold, Slide
	scores[Note.RELEASE_SCORE_TYPES[note.type]][judgement] += 1

	match note.type:
		Note.NOTE_HOLD:
			note.is_held = false
			note.time_released = t
			make_judgement_column(judgement, note.column)
			active_judgement_texts.append({col=note.column, judgement=judgement, time=t})
		Note.NOTE_SLIDE:
			make_judgement_column(judgement, note.column_release)
		Note.NOTE_TOUCH_HOLD:
			pass

func button_pressed(col):
	for note in active_notes:
		if (not note.hittable) or (note.column != col) or (note.time_activated != INF) or note.missed:
			continue
		var hit_delta = get_realtime_precise() - real_time(note.time_hit)  # Judgement times are in seconds not gametime
		if hit_delta >= 0.0:
			if hit_delta > Rules.JUDGEMENT_TIMES_POST[-1]:
				continue  # missed, don't consume input
			for i in Rules.JUDGEMENT_TIERS:
				if hit_delta <= Rules.JUDGEMENT_TIMES_POST[i]:
					activate_note(note, i)
					return  # Consume input because one press shouldn't trigger two notes
		else:
			if -hit_delta > Rules.JUDGEMENT_TIMES_PRE[-1]:
				continue  # too far away, don't consume input
			for i in Rules.JUDGEMENT_TIERS:
				if -hit_delta <= Rules.JUDGEMENT_TIMES_PRE[i]:
					activate_note(note, -i)
					return


func do_hold_release(note):
	var hit_delta = get_realtime_precise() - real_time(note.time_release)  # Judgement times are in seconds not gametime
	if hit_delta >= 0.0:
		for i in Rules.JUDGEMENT_TIERS-1:
			if hit_delta <= Rules.JUDGEMENT_TIMES_RELEASE_POST[i]:
				activate_note_release(note, i)
				return
		activate_note_release(note, Rules.JUDGEMENT_TIERS-1)  # No 'miss' for releasing, only worst judgement.
		return
	else:
		for i in Rules.JUDGEMENT_TIERS-1:
			if -hit_delta <= Rules.JUDGEMENT_TIMES_RELEASE_PRE[i]:
				activate_note_release(note, -i)
				return
		activate_note_release(note, -(Rules.JUDGEMENT_TIERS-1))  # No 'miss' for releasing, only worst judgement.
		return

func do_slide_release(note):
	var hit_delta = get_realtime_precise() - real_time(note.time_release)  # Judgement times are in seconds not gametime
	if hit_delta >= 0.0:
		for i in Rules.JUDGEMENT_TIERS:
			if hit_delta <= Rules.JUDGEMENT_TIMES_SLIDE_POST[i]:
				activate_note_release(note, i)
				return
	else:
		for i in Rules.JUDGEMENT_TIERS:
			if -hit_delta <= Rules.JUDGEMENT_TIMES_SLIDE_PRE[i]:
				activate_note_release(note, -i)
				return

func check_hold_release(col):
	for note in active_notes:
		if note.column != col:
			continue
		if note.type == Note.NOTE_HOLD:
			if note.is_held == true:
				do_hold_release(note)  # Separate function since there's no need to 'consume' releases

#----------------------------------------------------------------------------------------------------------------------------------------------
const arr_div := Vector3(2.0, float(Rules.COLS), TAU)
func _draw():
	var mesh := ArrayMesh.new()
	var noteline_data : Image = noteline_array_image.get_rect(Rect2(0, 0, 16, 16))
	noteline_data.lock()
	var i := 0
	var j := 0

	for note in active_notes:
		var position : float = (t+GameTheme.note_forecast_beats-note.time_hit)/GameTheme.note_forecast_beats
		var scale := 1.0

		if note.hittable:
			noteline_data.set_pixel(
				i%16, i/16, Color(
					position/arr_div.x,
					float(note.column)/arr_div.y,
					GameTheme.RADIAL_COL_ANGLES[note.column]/arr_div.z
				)
			)
			i += 1

		if position < GameTheme.INNER_NOTE_CIRCLE_RATIO:
			scale *= position/GameTheme.INNER_NOTE_CIRCLE_RATIO
			position = GameTheme.INNER_NOTE_CIRCLE_RATIO

		var note_center = (GameTheme.RADIAL_UNIT_VECTORS[note.column] * position * GameTheme.receptor_ring_radius)
		var color: PoolColorArray
		match note.type:
			Note.NOTE_TAP:
				color = GameTheme.color_array_tap(clamp((note.time_death-t)/Note.DEATH_DELAY, 0.0, 1.0), note.double_hit)
				make_tap_mesh(mesh, note_center, scale, color)
			Note.NOTE_STAR:
				color = GameTheme.color_array_star(clamp((note.time_death-t)/Note.DEATH_DELAY, 0.0, 1.0), note.double_hit)
				var angle = fmod(t/note.duration, 1.0)*TAU
				make_star_mesh(mesh, note_center, scale, angle, color)
			Note.NOTE_HOLD:
				if note.is_held:
					position = (t+GameTheme.note_forecast_beats-note.time_release)/GameTheme.note_forecast_beats
					color = GameTheme.COLOR_ARRAY_HOLD_HELD
					note_center = GameTheme.RADIAL_UNIT_VECTORS[note.column] * GameTheme.receptor_ring_radius * max(position, 1.0)
				elif position > 1.0:
					color = GameTheme.COLOR_ARRAY_DOUBLE_MISS_8 if note.double_hit else GameTheme.COLOR_ARRAY_HOLD_MISS
					if note.time_released != INF:
						position = (t+GameTheme.note_forecast_beats-note.time_released)/GameTheme.note_forecast_beats
						note_center = GameTheme.RADIAL_UNIT_VECTORS[note.column] * GameTheme.receptor_ring_radius * position
				else:
					color = GameTheme.COLOR_ARRAY_DOUBLE_8 if note.double_hit else GameTheme.COLOR_ARRAY_HOLD
				var position_rel : float = (t+GameTheme.note_forecast_beats-note.time_release)/GameTheme.note_forecast_beats
				if position_rel > 0:
					var note_rel_center := (GameTheme.RADIAL_UNIT_VECTORS[note.column] * position_rel * GameTheme.receptor_ring_radius)
					noteline_data.set_pixel(
						j%16, 15, Color(
							position_rel/arr_div.x,
							float(note.column)/arr_div.y,
							GameTheme.RADIAL_COL_ANGLES[note.column]/arr_div.z
						)
					)
					j += 1
				if position_rel < GameTheme.INNER_NOTE_CIRCLE_RATIO:
					position_rel = GameTheme.INNER_NOTE_CIRCLE_RATIO
				var note_center_rel = (GameTheme.RADIAL_UNIT_VECTORS[note.column] * position_rel * GameTheme.receptor_ring_radius)
				make_hold_mesh(mesh, note_center, note_center_rel, scale, GameTheme.RADIAL_COL_ANGLES[note.column], color)
			Note.NOTE_SLIDE:
				var trail_alpha := 1.0
				if position < GameTheme.INNER_NOTE_CIRCLE_RATIO:
					trail_alpha = 0.0
				elif position < 1.0:
					trail_alpha = min(1.0, (position-GameTheme.INNER_NOTE_CIRCLE_RATIO)/(1-GameTheme.INNER_NOTE_CIRCLE_RATIO*2))
				else:
					var trail_progress : float = clamp((t - note.time_hit - GameTheme.SLIDE_DELAY)/(note.duration - GameTheme.SLIDE_DELAY), 0.0, 1.0)
					var star_pos : Vector2 = note.get_position(trail_progress) * GameTheme.receptor_ring_radius
					var star_angle : float = note.get_angle(trail_progress)
					make_star_mesh(mesh, star_pos, 1.33, star_angle)
					if note.progress != INF:
						slide_trail_mesh_instances[note.slide_id].material.set_shader_param('trail_progress', note.progress)
					if t > note.time_release:
						trail_alpha = max(1 - (t - note.time_release)/Note.DEATH_DELAY, 0.0)
				slide_trail_mesh_instances[note.slide_id].material.set_shader_param('base_alpha', trail_alpha*GameTheme.slide_trail_alpha)

	noteline_data.unlock()
	var noteline_data_tex := ImageTexture.new()
	noteline_data_tex.create_from_image(noteline_data, 0)
	notelines.set_texture(noteline_data_tex)

	meshinstance.set_mesh(mesh)

	var textmesh := ArrayMesh.new()
	for text in active_judgement_texts:
		make_judgement_text(textmesh, TextJudgement[text.judgement], text.col, (t-text.time)/GameTheme.judge_text_duration)
	JudgeText.set_mesh(textmesh)


func _input(event):
	var pos
	if event is InputEventScreenTouch:
		if event.pressed:
			pos = event.position - get_global_transform_with_canvas().get_origin()
		else:
			return
	elif event is InputEventScreenDrag:
		pos = event.position - get_global_transform_with_canvas().get_origin()
	else:
		return

	pos /= rect_size*0.5  # Normalize to unit circle
	pos -= Vector2(1.0, 1.0)  # Normalize to center
	pos *= GameTheme.receptor_ring_radius_normalized_inv  # Normalize to receptor ring as slides are
	for i in range(len(active_slide_trails)-1, -1, -1):  # Iterate backwards as we are potentially deleting entries
		var note = active_slide_trails[i]
		var center = note.get_position(note.progress)
		var center2 = note.get_position(min(note.progress+0.06, 1.0))
		if ((pos - center).length_squared() < Rules.SLIDE_RADIUS2) or ((pos - center2).length_squared() < Rules.SLIDE_RADIUS2):
			note.progress += 0.09
			if note.progress >= 1.0:
				do_slide_release(note)
				active_slide_trails.remove(i)


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

func make_noteline_mesh(vertices := 32) -> ArrayMesh:
	assert(vertices > 3)
	var rec_scale1 = (float(screen_height)/float(GameTheme.receptor_ring_radius))*0.5
	var uv_array_playfield := PoolVector2Array([Vector2(0.0, 0.0)])
	var vertex_array_playfield := PoolVector2Array([Vector2(0.0, 0.0)])

	var angle_increment = TAU/float(vertices)
	# Outer polygon side-length = inner side-length / sin(inside angle/2)
	# inside angle for a polygon is pi-tau/n. We already precalculated tau/n for other purposes.
	var r = 0.5 * screen_height/sin((PI-angle_increment)/2)
	var UV_r = rec_scale1/sin((PI-angle_increment)/2)
	for i in vertices+1:
		var angle = i * angle_increment
		uv_array_playfield.append(polar2cartesian(UV_r, -angle))
		vertex_array_playfield.append(polar2cartesian(r, angle))

	var mesh_playfield := ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array_playfield
	arrays[Mesh.ARRAY_TEX_UV] = uv_array_playfield
	mesh_playfield.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_FAN, arrays)
	return mesh_playfield

# Called when the node enters the scene tree for the first time.
func _ready():
	notelines.set_mesh(make_noteline_mesh())
	notelines.material.set_shader_param('bps', bpm/60.0)
	notelines.material.set_shader_param('array_postmul', arr_div)

	noteline_array_image.create(16, 16, false, Image.FORMAT_RGBF)
	noteline_array_image.fill(Color(0.0, 0.0, 0.0))
	# Format: first 15 rows are for hit events, last row is for releases only (no ring glow)

	meshinstance.material.set_shader_param('star_color', GameTheme.COLOR_STAR)
	meshinstance.material.set_shader_param('held_color', GameTheme.COLOR_HOLD_HELD)
	meshinstance.material.set_shader_param('bps', bpm/60.0)
	meshinstance.material.set_shader_param('screen_size', get_viewport().get_size())
	meshinstance.set_texture(GameTheme.tex_notes)

func load_track(song_key: String, difficulty_key: String):
	self.song_key = song_key
	set_time(-3.0)
	active_notes = []
	next_note_to_load = 0
	all_notes = []
	var data = Library.all_songs[song_key]
	var chart = Library.get_song_charts(song_key)[difficulty_key]
	for note in chart[1]:
		all_notes.append(Note.copy_note(note))
	bpm = data.BPM
	GameTheme.note_forecast_beats = 2.0 if (bpm < 180) else 3.0  # Hack to make high-BPM playable until proper settings
	sync_offset_audio = data.audio_offsets[0]
	sync_offset_video = data.video_offsets[0]
	var videostream = FileLoader.load_video('songs/' + data.filepath.rstrip('/') + '/' + data.video_filelist[0])
	MusicPlayer.set_stream(FileLoader.load_ogg('songs/' + data.filepath.rstrip('/') + '/' + data.audio_filelist[0]))
	VideoPlayer.set_stream(videostream)
#	all_notes = FileLoader.Test.stress_pattern()

	Note.process_note_list(all_notes, false)
	for note in all_notes:
		if note.type == Note.NOTE_SLIDE:
			slide_trail_meshes[note.slide_id] = make_slide_trail_mesh(note)

	initialise_scores()  # Remove old score

func stop():
	MusicPlayer.stop()
	VideoPlayer.stop()
#	running = false
	next_note_to_load = 10000000  # Hacky but whatever

func intro_click():
	SoundPlayer.play(SoundPlayer.Type.NON_POSITIONAL, self, GameTheme.snd_count_in)

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

	meshinstance.material.set_shader_param('bps', bpm/60.0)
	notelines.material.set_shader_param('bps', bpm/60.0)

	var t_old := game_time(time)
#	time += delta
	time = get_realtime_precise()
	t = game_time(time)

	if (not timers_set) and (t > -5.0):
		timers_set = true
		for i in [-4.0, -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0]:
			var delay := real_time(i) - time
			var timer = Timer.new()
			add_child(timer)
			timer.set_one_shot(false)
#			timer.set_timer_process_mode(Timer.TIMER_PROCESS_FIXED)
			timer.set_wait_time(delay)
			timer.connect('timeout', self, 'intro_click')
			timer.start()
			timer.connect('timeout', timer, 'queue_free')

	var vt_delta := time - video_start_time()
	if (0.0 <= vt_delta) and (vt_delta < 3.0) and not VideoPlayer.is_playing():
		VideoPlayer.play()
		VideoPlayer.set_stream_position(vt_delta)
	var at_delta := time - audio_start_time()
	if (0.0 <= at_delta) and (at_delta < 3.0) and not MusicPlayer.is_playing():
#		MusicPlayer.play()
#		MusicPlayer.seek(at_delta)
		MusicPlayer.play(at_delta)

	# Clean out expired notes
	var miss_time: float = Rules.JUDGEMENT_TIMES_POST[-1] * bpm/60.0
	for i in range(len(active_notes)-1, -1, -1):  # Iterate backwards as we're potentially removing things from the array
		var note = active_notes[i]
		if note.time_death < t:  # Delete notes
			match note.type:
				Note.NOTE_HOLD:
					if note.is_held:  # Held too long
						scores[Note.RELEASE_SCORE_TYPES[Note.NOTE_HOLD]][3] += 1
						make_judgement_column(3, note.column)
				Note.NOTE_SLIDE:
					SlideTrailHandler.remove_child(slide_trail_mesh_instances[note.slide_id])
					slide_trail_mesh_instances.erase(note.slide_id)
					var idx = active_slide_trails.find(note)
					if idx > -1:
						active_slide_trails.remove(idx)
						make_judgement_column('MISS', note.column_release)
						scores[Note.NOTE_SLIDE]['MISS'] += 1
						note.missed_slide = true
			active_notes.remove(i)
		elif not note.hittable:
			if note.type == Note.NOTE_SLIDE:
				if (t >= note.time_hit) and (note.time_activated == INF):
					active_slide_trails.append(note)
					note.progress = 0.0
					note.time_activated = t
		elif note.time_activated == INF:  # Check if notes have been missed
			if ((t-note.time_hit) > miss_time) and not note.missed:
				note.missed = true
				end_combo()
				make_judgement_column('MISS', note.column)
				scores[note.type]['MISS'] += 1
				if Note.RELEASE_SCORE_TYPES.has(note.type):
					scores[Note.RELEASE_SCORE_TYPES[note.type]]['MISS'] += 1

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
			meshi.set_material(GameTheme.slide_trail_shadermaterial.duplicate())
			meshi.material.set_shader_param('trail_progress', 0.0)
			meshi.set_texture(GameTheme.tex_slide_arrow)
			slide_trail_mesh_instances[note.slide_id] = meshi
			SlideTrailHandler.add_child(meshi)

		next_note_to_load += 1

	if (
		next_note_to_load >= len(all_notes)
		and not VideoPlayer.is_playing()
		and not MusicPlayer.is_playing()
		and active_notes.empty()
		and active_judgement_texts.empty()
		and slide_trail_mesh_instances.empty()
	):
		self.running = false
		self.timers_set = false
		end_combo(true)
		emit_signal('finished_song', song_key, scores)

	# Redraw
	meshinstance.material.set_shader_param('screen_size', get_viewport().get_size())
	update()
	Painter.update()


func _on_InputHandler_column_pressed(column) -> void:
	button_pressed(column)

func _on_InputHandler_column_released(column) -> void:
	check_hold_release(column)
