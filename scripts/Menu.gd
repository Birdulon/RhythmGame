#tool
#extends Node2D
extends Control

export var NoteHandlerPath := @'../Center/NoteHandler'
export var ReceptorsPath := @'../Center/Receptors'
onready var NoteHandler := get_node(NoteHandlerPath)
onready var Receptors := get_node(ReceptorsPath)
onready var ScoreText := $ScoreText
onready var PVMusic := SoundPlayer.music_player_pv

var f_scale := 1.0 setget set_f_scale
func set_f_scale(value: float) -> void:
	f_scale = value
	TitleFont.size = int(round(32*f_scale))
	TitleFont.outline_size = int(max(round(2*f_scale), 1))
	GenreFont.size = int(round(48*f_scale))
	GenreFont.outline_size = int(max(round(2*f_scale), 1))
	DiffNumFont.size = int(round(36*f_scale))
	DiffNumFont.outline_size = int(max(round(1*f_scale), 1))
	ScoreText.set_f_scale(f_scale)
func update_scale() -> void:
	self.f_scale = rect_size.x/1080

var genres = {}

enum ChartDifficulty {EASY, BASIC, ADV, EXPERT, MASTER}
enum MenuMode {SONG_SELECT, CHART_SELECT, OPTIONS, GAMEPLAY, SCORE_SCREEN}

var menu_mode = MenuMode.SONG_SELECT
var menu_mode_prev = MenuMode.SONG_SELECT
var menu_mode_prev_fade_timer := 0.0
var menu_mode_prev_fade_timer_duration := 0.25
var currently_playing := false

var selected_genre: int = 0
var selected_genre_vis: int = 0
var selected_genre_delta: float = 0.0  # For floaty display scrolling
var target_song_idx: float = 0.0 setget set_target_song_idx
var target_song_delta: float = 0.0  # For floaty display scrolling
var selected_song_idx: int setget , get_song_idx
var selected_song_key: String setget , get_song_key
var selected_difficulty = ChartDifficulty.ADV

func set_target_song_idx(index):
	target_song_delta -= index - target_song_idx
	target_song_idx = index

func get_song_idx() -> int:
	return int(round(self.target_song_idx + target_song_delta))

func get_song_key() -> String:
	var songslist = genres[genres.keys()[selected_genre]]
	return songslist[int(round(self.target_song_idx)) % len(songslist)]

var scorescreen_song_key := ''
var scorescreen_score_data := {}
var scorescreen_datetime := {}
var scorescreen_saved := false

var touch_rects = []

var TitleFont: DynamicFont = preload('res://assets/MenuTitleFont.tres').duplicate()
var GenreFont: DynamicFont = preload('res://assets/MenuGenreFont.tres').duplicate()
var DiffNumFont: DynamicFont = preload('res://assets/MenuDiffNumberFont.tres').duplicate()
var ScoreFont: DynamicFont = preload('res://assets/MenuScoreFont.tres').duplicate()
var snd_interact := preload('res://assets/softclap.wav')
var snd_error := preload('res://assets/miss.wav')

export var ease_curve: Curve


class lerp_array extends Resource:
	var array
	func _init(array: Array):
		self.array = array

	func value(index: float):
		# Only >= 0 for now, but should be fine since it's an arraylike anyway
		var i := min(int(floor(index)), len(array)-2)  # Somewhat hacky - if we pass len(array)-1 as index, it will return lerp(a[-2], a[-1], 1) == a[-1]
		var f := min(index - i, 1.0)
		return lerp(array[i], array[i+1], f)

	func len():
		return len(array)


func get_rect_center(rect: Rect2) -> Vector2:
	return rect.position + rect.size*0.5

func scan_library():
	var results = FileLoader.scan_library()
	genres = results.genres

func save_score() -> int:
	var data = {'score_data': scorescreen_score_data, 'song_key': scorescreen_song_key}
	var dt = scorescreen_datetime
	var filename = 'scores/%04d%02d%02dT%02d%02d%02d.json'%[dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	match FileLoader.save_json(filename, data):
		OK:
			scorescreen_saved = true
			return OK
		var err:
			print_debug('Error saving score file %s'%filename)
			return err

func load_score(filename: String):
	var result = FileLoader.load_json('scores/%s'%filename)
	if not (result is Dictionary):
		print('An error occurred while trying to access the chosen score file: ', result)
		return result
	var data = {}
	for key in result.score_data:
		var value = {}
		for k2 in result.score_data[key]:
			if k2 != 'MISS':
				k2 = int(k2)  # Could use something more robust later
			value[k2] = result.score_data[key][k2]
		data[int(key)] = value
	scorescreen_score_data = data
	scorescreen_song_key = result.song_key
	scorescreen_saved = true
	set_menu_mode(MenuMode.SCORE_SCREEN)

func load_preview():
	var tmp = self.selected_song_key
	var data = Library.all_songs[tmp]
	PVMusic.stop()
	PVMusic.set_stream(FileLoader.load_ogg('songs/' + data.filepath.rstrip('/') + '/' + data.audio_filelist[0]))
	PVMusic.play(16*60.0/data.BPM)

func _ready():
	scan_library()
	connect('item_rect_changed', self, 'update_scale')
	NoteHandler.connect('finished_song', self, 'finished_song')

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
#	var swipe: Vector2 = $'../InputHandler'.swipe_momentum
#	if abs(swipe.x) > 10:
#		target_song_delta += swipe.x * 0.1 * delta
#	else:
	target_song_delta -= ease_curve.interpolate(clamp(target_song_delta, -2, 2)*0.5) * 10 * delta
	if abs(target_song_delta) < 0.02:  # Snap
		target_song_delta = 0.0

	var g_diff = selected_genre - (selected_genre_vis + selected_genre_delta)
	selected_genre_delta += ease_curve.interpolate(clamp(g_diff, -1, 1)) * 10 * delta
	if selected_genre_delta > 0.5:
		selected_genre_delta -= 1.0
		selected_genre_vis += 1
	elif selected_genre_delta < -0.5:
		selected_genre_delta += 1.0
		selected_genre_vis -= 1
	if abs(g_diff) < 0.02:  # Snap
		selected_genre_delta = 0.0
		selected_genre_vis = selected_genre

	menu_mode_prev_fade_timer = max(0.0, menu_mode_prev_fade_timer - delta)
	update()
	if (menu_mode == MenuMode.GAMEPLAY) and (menu_mode_prev_fade_timer <= 0.0) and not NoteHandler.running:
		NoteHandler.load_track(self.selected_song_key, Library.Song.default_difficulty_keys[selected_difficulty])
		NoteHandler.running = true


func draw_string_centered(font: Font, position: Vector2, string: String, color := GameTheme.COLOR_MENU_TEXT, vcenter := false) -> Vector2:
	# Draws horizontally centered from the baseline. Can vcenter via ascent but not perfectly reliable.
	# Returns size of the string.
	var ss := font.get_string_size(string)
	var v := -(font.get_descent() - font.get_height()*0.475) if vcenter else 0.0  # This VCentering is a little fudgey but works for our current fonts
	draw_string(font, Vector2(position.x - ss.x*0.5, position.y + v).round(), string, color)
	return ss

func draw_string_ralign(font: Font, position: Vector2, string: String, color := GameTheme.COLOR_MENU_TEXT, vcenter := false) -> Vector2:
	# Draws from the bottom-right. Can vcenter via ascent but not perfectly reliable.
	# Returns size of the string.
	var ss := font.get_string_size(string)
	var ascent := font.get_ascent() if vcenter else 0.0
	draw_string(font, Vector2(position.x - ss.x, position.y + ascent*0.5).round(), string, color)
	return ss

func draw_songtile(song_key, position, size, title_text:=false, difficulty=selected_difficulty, outline_px:=3.0, disabled:=false):
	# Draws from top left-corner. Returns Rect2 of the image (not the outline).
	# Draw difficulty-colored outline
	if typeof(difficulty) == TYPE_STRING:
		difficulty = Library.Song.difficulty_key_ids.get(difficulty, 0)

	outline_px *= f_scale

	var song_diffs = Library.all_songs[song_key]['chart_difficulties']
	if not (Library.Song.default_difficulty_keys[difficulty] in song_diffs):
		difficulty = Library.Song.difficulty_key_ids.get(song_diffs.keys()[-1], 0)
	var diff_color := GameTheme.COLOR_DIFFICULTY[difficulty*2]
	var rect := Rect2(position.x, position.y, size, size)
	draw_rect(Rect2(position.x - outline_px, position.y - outline_px, size + outline_px*2, size + outline_px*2), diff_color)
	draw_texture_rect(Library.get_song_tile_texture(song_key), rect, false, Color.white if not disabled else Color(0.5, 0.2, 0.1))
	# Draw track difficulty rating
	draw_string_ralign(DiffNumFont, position+Vector2(size-2*f_scale, size-5*f_scale), song_diffs.get(Library.Song.default_difficulty_keys[difficulty], '0'), diff_color)
	if disabled:
		draw_string_centered(DiffNumFont, position+Vector2(size/2, size/2), 'No Chart!', diff_color, true)
	if title_text:
		draw_string_centered(TitleFont, position+Vector2(size/2.0, size+40*f_scale), str(Library.all_songs[song_key].title), diff_color.lightened(0.33))
	return rect

func diff_f2str(difficulty: float):  # Convert .5 to +
	return str(int(floor(difficulty))) + ('+' if fmod(difficulty, 1.0)>0.4 else '')

var sel_scales := lerp_array.new([1.0, 0.8, 0.64, 0.5, 0.4])
var bg_scales := lerp_array.new([0.64, 0.64, 0.64, 0.5, 0.4])
func _draw_song_select(center: Vector2) -> Array:
	var size = 200 * f_scale
	var spacer_x = 12 * f_scale
	var spacer_y = 64 * f_scale
	var title_spacer_y = 48 * f_scale
	var gy: float = center.y - 500 * f_scale - size*selected_genre_delta
	var touchrects := []

	var ssid = self.selected_song_idx
	var s_delta = target_song_delta-round(target_song_delta)
	for gi in [-2, -1, 0, 1, 2]:
		var g = (selected_genre_vis + gi) % len(genres)
		var selected: bool = (gi == 0)
		var scales = sel_scales if selected else bg_scales

		var subsize = size * scales.value(abs(s_delta))
		var gx = center.x - (subsize + spacer_x) * s_delta
		var songslist = Library.genre_songs[g].keys()
		var genre_str = '%s (%d songs)'%[genres.keys()[g], len(songslist)]
		draw_string_centered(GenreFont, Vector2(center.x, gy), genre_str, Color.lightblue)

		var s = len(songslist)
		var key = songslist[self.selected_song_idx % s]
		var y = gy + 16*f_scale
		var x = -subsize/2.0
		var r = draw_songtile(key, Vector2(gx+x, y), subsize, selected)
		touchrects.append({rect=r, song_idx=self.selected_song_idx, genre_idx=g})

		var subsize_p = subsize
		var subsize_n = subsize
		var x_p = x
		var x_n = x
		for i in range(1, scales.len()):
			x_p += subsize_p + spacer_x
			x_n += subsize_n + spacer_x
			subsize_p = size * scales.value(abs(i-s_delta))
			subsize_n = size * scales.value(abs(-i-s_delta))
			r = draw_songtile(songslist[(ssid+i) % s], Vector2(gx+x_p, y), subsize_p)
			touchrects.append({rect=r, song_idx=ssid+i, genre_idx=g})
			r = draw_songtile(songslist[(ssid-i) % s], Vector2(gx-x_n - subsize_n, y), subsize_n)
			touchrects.append({rect=r, song_idx=ssid-i, genre_idx=g})
		gy += size*scales.value(0) + spacer_y + (title_spacer_y if selected else 0)
	var b = 600 * f_scale
	var v1 = -590 * f_scale
	var v2 = -230 * f_scale
	var v4 = -v2
	var v3 = -v1
	var ps = PoolVector2Array([center+Vector2(-b, v1), center+Vector2(b, v1), center+Vector2(b, v2), center+Vector2(-b, v2)])
	var ps2 = PoolVector2Array([center+Vector2(-b, v3), center+Vector2(b, v3), center+Vector2(b, v4), center+Vector2(-b, v4)])
	var cs = PoolColorArray([Color(0,0,0.1,1.25), Color(0,0,0.1,1.25), Color(0,0,0,0), Color(0,0,0,0)])
	draw_polygon(ps, cs)
	draw_polygon(ps2, cs)
	draw_string_centered(GenreFont, Vector2(center.x, center.y-440*f_scale), 'Select Song', Color.aqua)
	draw_string_centered(DiffNumFont, Vector2(center.x, center.y-390*f_scale), 'Tap to scroll, tap focused to select', Color.lightgreen)
	return touchrects

func _draw_chart_select(center: Vector2) -> Array:
	# Select difficulty for chosen song
	var charts: Dictionary = Library.get_song_charts(self.selected_song_key)
	var song_data = Library.all_songs[self.selected_song_key]
	var diffs = song_data.chart_difficulties
	var n = len(diffs)
	var spacer_x = max(14, 70/n) * f_scale
	var size = min(192, (1000-spacer_x*(n-1))/n) * f_scale
	var rect_back = Rect2(center + Vector2(-300.0, 390.0)*f_scale, Vector2(600.0, 140.0)*f_scale)
	draw_rect(rect_back, Color.red)
	draw_string_centered(TitleFont, get_rect_center(rect_back), 'Back to song selection', Color.white, true)
	draw_string_centered(GenreFont, center+Vector2(0, -360*f_scale), 'Select Difficulty', Color.aqua)
	draw_string_centered(DiffNumFont, center+Vector2(0, -300*f_scale), 'Tap to show stats, tap focused to play', Color.lightgreen)
	var touchrects = [{rect=rect_back, chart_idx=-1, enabled=true}]  # invisible back button
	var x = center.x - (size*n + spacer_x*(n-1))/2

	for diff in diffs:
		var i_diff = Library.Song.difficulty_key_ids.get(diff, 0)
		var width = 8 if i_diff == selected_difficulty else 3
		var chart_exists: bool = (diff in charts)
		var r = draw_songtile(self.selected_song_key, Vector2(x, center.y-160*f_scale), size, false, i_diff, width, not chart_exists)
		touchrects.append({rect=r, chart_idx=i_diff, enabled=chart_exists})
		x += size + spacer_x
	draw_string_centered(TitleFont, center+Vector2(0, size-116*f_scale), str(Library.all_songs[self.selected_song_key].title))

	draw_string_centered(TitleFont, center+Vector2(-50*f_scale, size-64*f_scale), 'BPM:')
	draw_string_centered(TitleFont, center+Vector2(+50*f_scale, size-64*f_scale), str(song_data.BPM))

	if len(charts) > 0:
		var sel_chart: Array = charts.values()[min(selected_difficulty, len(charts)-1)]
		var all_notes: Array = sel_chart[1]
		var meta: Dictionary = sel_chart[0]

		var notestrs = ['Taps:', 'Holds:', 'Slides:']
		var notetypes = [0, 1, 2]
		var note_counts = [meta.num_taps, meta.num_holds, meta.num_slides]
		for i in len(notestrs):
			draw_string_centered(TitleFont, center+Vector2(-50*f_scale, size+(12+i*50)*f_scale), notestrs[i])
			draw_string_centered(TitleFont, center+Vector2(+50*f_scale, size+(12+i*50)*f_scale), str(note_counts[notetypes[i]]))
	else:
		draw_string_centered(TitleFont, center+Vector2(0, size-12*f_scale), 'No available charts!', Color.red)

	return touchrects

func _draw_score_screen(center: Vector2) -> Array:
	var size = 192 * f_scale
	var spacer_x = 12 * f_scale
	var touchrects = []
	var songslist = genres[genres.keys()[selected_genre]]
	var song_key = scorescreen_song_key
#	var song_data = Library.all_songs[song_key]
	var chart: Array = Library.get_song_charts(song_key)[Library.Song.default_difficulty_keys[selected_difficulty]]
	var all_notes: Array = chart[1]
	var meta: Dictionary = chart[0]

	var x = center.x
	var y = -160*f_scale
	var x_score = 110
	var y_score = -380
	var x2 = -360*f_scale
	var x_spacing = 124*f_scale
	var y_spacing = 42*f_scale
	var y2 = y + y_spacing*1.5
	var y3 = y2 + y_spacing

	var tex_judgement_text = GameTheme.tex_judgement_text
	var judgement_text_scale = 0.667
	var judgement_text_size = Vector2(256, 64) * judgement_text_scale

	draw_songtile(song_key, center + Vector2.LEFT*size*0.5 + Vector2(-x_score, y_score)*f_scale, size, false, selected_difficulty, 3)
	draw_string_centered(TitleFont, center + Vector2.DOWN*size + Vector2(-x_score, y_score+48)*f_scale, str(Library.all_songs[song_key].title))
	var notestrs = ['Taps (%d):'%meta.num_taps, 'Holds (%d) Hit:'%meta.num_holds, 'Released:', 'Stars (%d):'%meta.num_slides, 'Slides:']
	var notetypes = [0, 1, -1, 2, -2]
	var note_spacing = [0.0, 1.25, 2.25, 3.5, 4.5]
	var judgestrs = Array(Rules.JUDGEMENT_STRINGS + ['Miss'])
	var judge_scores = [1.0, 0.9, 0.75, 0.5, 0.0]
	var notetype_weights = [1.0, 1.0, 1.0, 1.0, 1.0]
	var notecount_total = 0
	var notecount_early = 0
	var notecount_late = 0
	var total_score = 0.0
	var total_scoremax = 0.0

	for i in len(judgestrs):
		# For each judgement type, print a column header
#		draw_string_centered(TitleFont, Vector2(x2+x_spacing*(i+1), y2), judgestrs[i])
		var dst_rect = Rect2(center+Vector2(x2+x_spacing*(i+1)-judgement_text_size.x*f_scale/2.0, y2), judgement_text_size*f_scale)
		draw_texture_rect_region(tex_judgement_text, dst_rect, Rect2(0, 128*(i+3), 512, 128))
	draw_string_centered(TitleFont, center+Vector2(x2+x_spacing*(len(judgestrs)+1), y2+34*f_scale), 'Score')

	for i in len(notestrs):
		# For each note type, make a row and print scores
		var idx = notetypes[i]
		var note_score = 0
		var note_count = 0
		var y_row = y3 + y_spacing * (note_spacing[i]+1)
		draw_string_centered(TitleFont, center+Vector2(x2-20*f_scale, y_row), notestrs[i])
		for j in len(judgestrs):
			var score
			if j == 0:
				score = scorescreen_score_data[idx][0]
			elif j >= len(judgestrs)-1:
				score = scorescreen_score_data[idx]['MISS']
			else:
				score = scorescreen_score_data[idx][j] + scorescreen_score_data[idx][-j]
				notecount_early += scorescreen_score_data[idx][-j]
				notecount_late += scorescreen_score_data[idx][j]
			if (j >= len(judgestrs)-1) and (idx == -1):
				draw_string_centered(TitleFont, center+Vector2(x2+x_spacing*(j+1), y_row), '^')
			else:
				draw_string_centered(TitleFont, center+Vector2(x2+x_spacing*(j+1), y_row), str(score))
			notecount_total += score  # Kinda redundant, will probably refactor eventually
			note_count += score
			note_score += score * judge_scores[j]
		draw_string_centered(TitleFont, center+Vector2(x2+x_spacing*(len(judgestrs)+1), y_row), '%2.2f%%'%(note_score/max(note_count, 1)*100.0))
		total_score += note_score * notetype_weights[i]
		total_scoremax += note_count * notetype_weights[i]

	var overall_score = total_score/max(total_scoremax, 1.0)
	var score_idx = 0
	for cutoff in Rules.SCORE_CUTOFFS:
		if overall_score >= cutoff:
			break
		else:
			score_idx += 1
	ScoreText.position = center+Vector2(x_score, y_score)*f_scale
	ScoreText.score = Rules.SCORE_STRINGS[score_idx]
	ScoreText.score_sub = '%2.3f%%'%(overall_score*100.0)
	ScoreText.update()

	draw_string_centered(TitleFont, center+Vector2(0, y3+y_spacing*7), 'Early : Late')
	draw_string_centered(TitleFont, center+Vector2(0, y3+y_spacing*8), '%3d%% : %3d%%'%[notecount_early*100/max(notecount_total, 1), notecount_late*100/max(notecount_total, 1)])

	var txt_offset = Vector2.DOWN*10*f_scale
	var rect_songs := Rect2(center+Vector2(-100.0, 300.0)*f_scale, Vector2(400.0, 100.0)*f_scale)
	draw_rect(rect_songs, Color.red)
	draw_string_centered(TitleFont, get_rect_center(rect_songs), 'Song Select', Color.white, true)
	touchrects.append({rect=rect_songs, next_menu=MenuMode.SONG_SELECT})

	var rect_save := Rect2(center+Vector2(-300.0, 300.0)*f_scale, Vector2(180.0, 100.0)*f_scale)
	if not scorescreen_saved:
		draw_rect(rect_save, Color(0.0, 0.01, 1.0))
		draw_string_centered(TitleFont, get_rect_center(rect_save), 'Save', Color.white, true)
		touchrects.append({rect=rect_save, action='save'})
	else:
		draw_rect(rect_save, Color.darkgray)
		draw_string_centered(TitleFont, get_rect_center(rect_save), 'Saved', Color.white, true)

	draw_string_centered(GenreFont, center+Vector2.UP*410*f_scale, 'Results', Color.aqua)
	return touchrects

func _draw_gameplay(center: Vector2) -> Array:
	var touchrects = []

	var rect_songselect := Rect2(center+Vector2(+860.0, 480.0)*f_scale, Vector2(100.0, 50.0)*f_scale)
	draw_rect(rect_songselect, Color.red)
	draw_string_centered(TitleFont, get_rect_center(rect_songselect), 'Stop', Color.white, true)
	touchrects.append({rect=rect_songselect, action='stop'})
	return touchrects


func _draw():
	var songs = len(Library.all_songs)
	var score_screen_filter_alpha := 0.65
	var size = 216
	var outline_px = 3
	var center = rect_size * 0.5
	touch_rects = []
	ScoreText.hide()
	for i in MenuMode:
		touch_rects.append([])

	if menu_mode_prev_fade_timer > 0.0:
		var progress = 1.0 - menu_mode_prev_fade_timer/menu_mode_prev_fade_timer_duration
		var center_prev = lerp(center, center+Vector2(0.0, 1200.0), progress)
		var center_next = center_prev + Vector2(0.0, -1200.0)
		match menu_mode_prev:
			MenuMode.SONG_SELECT:
				_draw_song_select(center_prev)
			MenuMode.CHART_SELECT:
				_draw_chart_select(center_prev)
			MenuMode.OPTIONS:
				pass
			MenuMode.GAMEPLAY:
				GameTheme.set_screen_filter_alpha(lerp(0.0, score_screen_filter_alpha, progress))
			MenuMode.SCORE_SCREEN:
				_draw_score_screen(center_prev)
		match menu_mode:
			MenuMode.SONG_SELECT:
				_draw_song_select(center_next)
			MenuMode.CHART_SELECT:
				_draw_chart_select(center_next)
			MenuMode.OPTIONS:
				pass
			MenuMode.GAMEPLAY:
				GameTheme.set_screen_filter_alpha(1.0 - progress)
			MenuMode.SCORE_SCREEN:
				_draw_score_screen(center_next)
				ScoreText.show()
	else:
		match menu_mode:
			MenuMode.SONG_SELECT:
				GameTheme.set_screen_filter_alpha(1.0)
				touch_rects[menu_mode] = _draw_song_select(center)
			MenuMode.CHART_SELECT:
				GameTheme.set_screen_filter_alpha(1.0)
				touch_rects[menu_mode] = _draw_chart_select(center)
			MenuMode.OPTIONS:
				pass
			MenuMode.GAMEPLAY:
				GameTheme.set_screen_filter_alpha(0.0)
				touch_rects[menu_mode] = _draw_gameplay(center)
			MenuMode.SCORE_SCREEN:
				GameTheme.set_screen_filter_alpha(score_screen_filter_alpha)
				touch_rects[menu_mode] = _draw_score_screen(center)
				ScoreText.show()

func set_menu_mode(mode):
	Receptors.fade(mode == MenuMode.GAMEPLAY)
	if mode == MenuMode.GAMEPLAY:
		PVMusic.stop()
		rect_clip_content = false
	else:
		rect_clip_content = true
	menu_mode_prev = menu_mode
	menu_mode = mode
	menu_mode_prev_fade_timer = menu_mode_prev_fade_timer_duration

func touch_select_song(touchdict):
	if (self.selected_genre == touchdict.genre_idx) and (self.selected_song_idx == touchdict.song_idx):
		SoundPlayer.play(SoundPlayer.Type.NON_POSITIONAL, self, snd_interact, 0.0)
		# var songslist = genres[genres.keys()[selected_genre]]
		# selected_song_key = songslist[self.target_song_idx % len(songslist)]
		set_menu_mode(MenuMode.CHART_SELECT)
	else:
		self.selected_genre = touchdict.genre_idx
		self.target_song_idx = touchdict.song_idx
		SoundPlayer.play(SoundPlayer.Type.NON_POSITIONAL, self, snd_interact, -4.5)
		load_preview()

func touch_select_chart(touchdict):
	if touchdict.chart_idx == selected_difficulty:
		if touchdict.enabled:
			SoundPlayer.play(SoundPlayer.Type.NON_POSITIONAL, self, snd_interact, 0.0)
			set_menu_mode(MenuMode.GAMEPLAY)
		else:
			SoundPlayer.play(SoundPlayer.Type.NON_POSITIONAL, self, snd_error, 0.0)
	elif touchdict.chart_idx < 0:
		SoundPlayer.play(SoundPlayer.Type.NON_POSITIONAL, self, snd_interact, -3.0, 0.7)
		set_menu_mode(MenuMode.SONG_SELECT)
	else:
		self.selected_difficulty = touchdict.chart_idx
		SoundPlayer.play(SoundPlayer.Type.NON_POSITIONAL, self, snd_interact, -4.5)

func touch_gameplay(touchdict):
	if touchdict.has('action'):
		SoundPlayer.play(SoundPlayer.Type.NON_POSITIONAL, self, snd_interact, 0.0)
		if touchdict.action == 'stop':
			NoteHandler.stop()

func touch_score_screen(touchdict):
	if touchdict.has('next_menu'):
		SoundPlayer.play(SoundPlayer.Type.NON_POSITIONAL, self, snd_interact, 0.0)
		set_menu_mode(touchdict.next_menu)
		ScoreText.score = ''
		ScoreText.score_sub = ''
		# TODO: time this to coincide with the menu going fully offscreen
		ScoreText.update()
	elif touchdict.has('action'):
		SoundPlayer.play(SoundPlayer.Type.NON_POSITIONAL, self, snd_interact, 0.0)
		if touchdict.action == 'save':
			save_score()

func finished_song(song_key, score_data):
	scorescreen_song_key = song_key
	scorescreen_score_data = score_data
	scorescreen_datetime = OS.get_datetime()
	scorescreen_saved = false
	set_menu_mode(MenuMode.SCORE_SCREEN)


func _input(event):
	if !visible:
		return
	if (event is InputEventMouseButton):  # Add this if we ever manage to be rid of the curse of Touch->Mouse emulation: (event is InputEventScreenTouch)
#		print(event)
		if event.pressed:
			var pos = event.position - get_global_transform_with_canvas().get_origin()
			match menu_mode:
				MenuMode.SONG_SELECT:
					for d in touch_rects[MenuMode.SONG_SELECT]:
						if d.rect.has_point(pos):
							touch_select_song(d)
				MenuMode.CHART_SELECT:
					for d in touch_rects[MenuMode.CHART_SELECT]:
						if d.rect.has_point(pos):
							touch_select_chart(d)
				MenuMode.GAMEPLAY:
					for d in touch_rects[MenuMode.GAMEPLAY]:
						if d.rect.has_point(pos):
							touch_gameplay(d)
				MenuMode.SCORE_SCREEN:
					for d in touch_rects[MenuMode.SCORE_SCREEN]:
						if d.rect.has_point(pos):
							touch_score_screen(d)
	match menu_mode:
		MenuMode.SONG_SELECT:
			if event.is_action_pressed('ui_right'):  # Sadly can't use match with this input system
				self.target_song_idx += 1
			elif event.is_action_pressed('ui_left'):
				self.target_song_idx -= 1
			elif event.is_action_pressed('ui_up'):
				selected_genre = posmod(selected_genre - 1, len(genres))
			elif event.is_action_pressed('ui_down'):
				selected_genre = posmod(selected_genre + 1, len(genres))
			elif event.is_action_pressed('ui_page_up'):
				selected_difficulty = int(max(0, selected_difficulty - 1))
			elif event.is_action_pressed('ui_page_down'):
				selected_difficulty = int(min(6, selected_difficulty + 1))
