extends Node2D

var song_defs = {}
var song_images = {}
var genres = {}

enum ChartDifficulty {EASY, BASIC, ADV, EXPERT, MASTER}
enum MenuMode {SONG_SELECT, CHART_SELECT, OPTIONS, GAMEPLAY, SCORE_SCREEN}

var selected_genre: int = 0
var selected_song: int = 0
var selected_song_vis: int = 0
var selected_song_delta: float = 0.0  # For floaty display scrolling
var selected_song_speed: float = 0.0  # For floaty display scrolling
var selected_difficulty = ChartDifficulty.ADV
var menu_mode = MenuMode.SONG_SELECT
var menu_mode_prev = MenuMode.SONG_SELECT
var menu_mode_prev_fade_timer := 0.0
var menu_mode_prev_fade_timer_duration := 0.25
var currently_playing := false

var scorescreen_song_key := ""
var scorescreen_score_data := {}

var touch_rects = []

var TitleFont := preload("res://assets/MenuTitleFont.tres")
var GenreFont := preload("res://assets/MenuGenreFont.tres")
var snd_interact := preload("res://assets/softclap.wav")

func scan_library():
	print("Scanning library")
	var rootdir = "res://songs"
	var dir = Directory.new()
	var err = dir.open(rootdir)
	if err == OK:
		dir.list_dir_begin(true, true)
		var key = dir.get_next()
		while (key != ""):
			if dir.current_is_dir():
				if dir.file_exists(key + "/song.json"):
					song_defs[key] = FileLoader.load_folder("%s/%s" % [rootdir, key])
					print("Loaded song directory: %s" % key)
					song_images[key] = load("%s/%s/%s" % [rootdir, key, song_defs[key]["tile_filename"]])
					if song_defs[key]["genre"] in genres:
						genres[song_defs[key]["genre"]].append(key)
					else:
						genres[song_defs[key]["genre"]] = [key]
				else:
					print("Found non-song directory: " + key)
			else:
				print("Found file: " + key)
			key = dir.get_next()
		dir.list_dir_end()
	else:
		print("An error occurred when trying to access the songs directory: ", err)

func _ready():
	scan_library()
	$"/root/main/NoteHandler".connect("finished_song", self, "finished_song")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var diff = selected_song - (selected_song_vis + selected_song_delta)
	selected_song_speed = sign(diff)*ease(abs(diff), 2)*10
	selected_song_delta += selected_song_speed * delta
	if selected_song_delta > 0.5:
		selected_song_delta -= 1.0
		selected_song_vis += 1
	elif selected_song_delta < -0.5:
		selected_song_delta += 1.0
		selected_song_vis -= 1

	menu_mode_prev_fade_timer = max(0.0, menu_mode_prev_fade_timer - delta)
	update()
	if (menu_mode == MenuMode.GAMEPLAY) and (menu_mode_prev_fade_timer <= 0.0) and not $"/root/main/NoteHandler".running:
		var songslist = genres[genres.keys()[selected_genre]]
		var song_key = songslist[selected_song % len(songslist)]
		$"/root/main/NoteHandler".load_track(song_defs[song_key], selected_difficulty)
		$"/root/main/NoteHandler".running = true

func draw_string_centered(font, position, string, color := Color.white):
	draw_string(font, Vector2(position.x - font.get_string_size(string).x/2.0, position.y + font.get_ascent()), string, color)

func draw_songtile(song_key, position, size, title_text:=false, difficulty=selected_difficulty, outline_px:=3):
	# Draws from top left-corner. Returns Rect2 of the image (not the outline).
	# Draw difficulty-colored outline
	var diff_color := GameTheme.COLOR_DIFFICULTY[difficulty*2]
	var rect := Rect2(position.x, position.y, size, size)
	draw_rect(Rect2(position.x - outline_px, position.y - outline_px, size + outline_px*2, size + outline_px*2), diff_color)
	draw_texture_rect(song_images[song_key], rect, false)
	# Draw track difficulty rating
	draw_string_centered(GenreFont, Vector2(position.x+size-24, position.y+size-56), diffstr(song_defs[song_key]["chart_difficulties"][difficulty]), diff_color)
	if title_text:
		draw_string_centered(TitleFont, Vector2(position.x+size/2.0, position.y+size), song_defs[song_key]["title"], Color(0.95, 0.95, 1.0))
	return rect

func diffstr(difficulty: float):
	# Convert .5 to +
	return str(int(floor(difficulty))) + ("+" if fmod(difficulty, 1.0)>0.4 else "")


func _draw_song_select(center: Vector2) -> Array:
	var size = 216
	var spacer_x = 12
	var spacer_y = 64
	var sel_scales := [1.0, 0.8, 0.64, 0.512, 0.4096]
	var bg_scales := [0.64, 0.64, 0.64, 0.512, 0.4096]
	var gy := center.y
	var touchrects := []

	for g in len(genres):
		var selected: bool = (g == selected_genre)
		var base_scales = sel_scales if selected else bg_scales
		var scales = []
		scales.resize(len(base_scales)*2-1)
		if selected_song_delta >= 0.0:
			for i in len(base_scales)-1:
				scales[i+1] = lerp(base_scales[i+1], base_scales[i], selected_song_delta)
				scales[-i] = lerp(base_scales[i], base_scales[i+1], selected_song_delta)
			scales[len(base_scales)] = base_scales[-1]
		else:
			for i in len(base_scales)-1:
				scales[i] = lerp(base_scales[i], base_scales[i+1], -selected_song_delta)
				scales[-i-1] = lerp(base_scales[i+1], base_scales[i], -selected_song_delta)
			scales[-len(base_scales)] = base_scales[-1]

		var subsize = size * scales[0]
		var gx = center.x - (subsize + spacer_x) * selected_song_delta
		var genre = genres.keys()[g]
		draw_string_centered(GenreFont, Vector2(0, gy), genre)
		var songslist = genres[genre]
		var s = len(songslist)
		var key = songslist[selected_song_vis % s]
		var y = gy + spacer_y
		var x = -subsize/2.0
		var r = draw_songtile(key, Vector2(gx+x, y), subsize, selected, selected_difficulty)
		touchrects.append({rect=r, song_idx=selected_song_vis, genre_idx=g})

		for i in range(1, len(base_scales)):
			x += subsize + spacer_x
			subsize = size * scales[i]
			r = draw_songtile(songslist[(selected_song_vis+i) % s], Vector2(gx+x, y), subsize)
			touchrects.append({rect=r, song_idx=selected_song_vis+i, genre_idx=g})
		subsize = size * scales[0]
		x = -subsize/2.0
		for i in range(1, len(base_scales)):
			x += subsize + spacer_x
			subsize = size * scales[-i]
			r = draw_songtile(songslist[(selected_song_vis-i) % s], Vector2(gx-x - subsize, y), subsize)
			touchrects.append({rect=r, song_idx=selected_song_vis-i, genre_idx=g})
		gy += size*base_scales[0] + (spacer_y * 2)
	return touchrects

func _draw_chart_select(center: Vector2) -> Array:
	var size = 192
	var spacer_x = 12
	var touchrects = []
	var songslist = genres[genres.keys()[selected_genre]]
	var song_key = songslist[selected_song % len(songslist)]
	var x = center.x - (size*2.5 + spacer_x*2)
	for diff in 5:
		var r = draw_songtile(song_key, Vector2(x, center.y), size, false, diff, (9 if diff == selected_difficulty else 3))
		touchrects.append({rect=r, chart_idx=diff})
		x += size + spacer_x
	draw_string_centered(TitleFont, Vector2(center.x, center.y+size+64), song_defs[song_key]["title"], Color(0.95, 0.95, 1.0))
	touchrects.append({rect=Rect2(-450.0, 150.0, 900.0, 300.0), chart_idx=-1})
	return touchrects

func _draw_score_screen(center: Vector2) -> Array:
	var size = 192
	var spacer_x = 12
	var touchrects = []
	var songslist = genres[genres.keys()[selected_genre]]
	var song_key = scorescreen_song_key
	var x = center.x
	var y = center.y - 200
	var x2 = x - 360
	var x_spacing = 116
	var y_spacing = 48
	var y1 = y + size + y_spacing
	var y2 = y1 + 120

	draw_songtile(song_key, Vector2(x-size/2.0, y), size, false, selected_difficulty, 3)
	draw_string_centered(TitleFont, Vector2(x, y+size), song_defs[song_key]["title"], Color(0.95, 0.95, 1.0))
	var notestrs = ["Tap", "Hold", "Slide"]
	var judgestrs = Array(Rules.JUDGEMENT_STRINGS + ["Miss"])
	var judge_scores = [1.0, 0.9, 0.75, 0.5, 0.0]
	var notetype_weights = [1.0, 2.0, 2.0]
	var notetype_scores = []
	var notetype_counts = []
	var total_score = 0.0
	var total_scoremax = 0.0
	for i in len(judgestrs):
		# For each judgement type, print a column header
		draw_string_centered(TitleFont, Vector2(x2+x_spacing*(i+1), y2), judgestrs[i], Color(0.95, 0.95, 1.0))
	draw_string_centered(TitleFont, Vector2(x2+x_spacing*(len(judgestrs)+1), y2), "Score", Color(0.95, 0.95, 1.0))
	for i in len(notestrs):
		# For each note type, make a row and print scores
		draw_string_centered(TitleFont, Vector2(x2, y2+y_spacing*(i+1)), notestrs[i]+"s:", Color(0.95, 0.95, 1.0))
		var note_score = 0
		var note_count = 0
		for j in len(judgestrs):
			var score
			if j == 0:
				score = scorescreen_score_data[i][0]
			elif j >= len(judgestrs)-1:
				score = scorescreen_score_data[i]["MISS"]
			else:
				score = scorescreen_score_data[i][j] + scorescreen_score_data[i][-j]
			draw_string_centered(TitleFont, Vector2(x2+x_spacing*(j+1), y2+y_spacing*(i+1)), str(score), Color(0.95, 0.95, 1.0))
			note_count += score
			note_score += score * judge_scores[j]
		draw_string_centered(TitleFont, Vector2(x2+x_spacing*(len(judgestrs)+1), y2+y_spacing*(i+1)), "%2.2f%%"%(note_score/note_count*100.0), Color(0.95, 0.95, 1.0))
		notetype_counts.append(note_count)
		notetype_scores.append(note_score)
		total_score += note_score * notetype_weights[i]
		total_scoremax += note_count * notetype_weights[i]
	var overall_score = total_score/total_scoremax
	var score_idx = 0
	for cutoff in Rules.SCORE_CUTOFFS:
		if overall_score >= cutoff:
			break
		else:
			score_idx += 1
	draw_string_centered(TitleFont, Vector2(x, y1), Rules.SCORE_STRINGS[score_idx], Color(0.95, 0.95, 1.0))
	draw_string_centered(TitleFont, Vector2(x, y1+y_spacing), "%2.3f%%"%(overall_score*100.0), Color(0.95, 0.95, 1.0))
#	touchrects.append({rect=r, chart_idx=diff})
	touchrects.append({rect=Rect2(-450.0, 150.0, 900.0, 300.0), next_menu=MenuMode.SONG_SELECT})
	return touchrects


func _draw():
	var songs = len(song_defs)
	var size = 216
	var outline_px = 3
	var center = Vector2(0.0, -160.0)
	touch_rects = []
	for i in MenuMode:
		touch_rects.append([])

	if menu_mode_prev_fade_timer > 0.0:
		var progress = 1.0 - menu_mode_prev_fade_timer/menu_mode_prev_fade_timer_duration
		var center_prev = lerp(center, Vector2(0.0, 700.0), progress)
		var center_next = lerp(Vector2(0.0, -700.0), center, progress)
		match menu_mode_prev:
			MenuMode.SONG_SELECT:
				_draw_song_select(center_prev)
			MenuMode.CHART_SELECT:
				_draw_chart_select(center_prev)
			MenuMode.OPTIONS:
				pass
			MenuMode.GAMEPLAY:
				pass
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
				pass
			MenuMode.SCORE_SCREEN:
				_draw_score_screen(center_next)
	else:
		match menu_mode:
			MenuMode.SONG_SELECT:
				touch_rects[menu_mode] = _draw_song_select(center)
			MenuMode.CHART_SELECT:
				touch_rects[menu_mode] = _draw_chart_select(center)
			MenuMode.OPTIONS:
				pass
			MenuMode.GAMEPLAY:
				pass
			MenuMode.SCORE_SCREEN:
				touch_rects[menu_mode] = _draw_score_screen(center)

func set_menu_mode(mode):
	menu_mode_prev = menu_mode
	menu_mode = mode
	menu_mode_prev_fade_timer = menu_mode_prev_fade_timer_duration

func touch_select_song(touchdict):
	if (self.selected_genre == touchdict.genre_idx) and (self.selected_song == touchdict.song_idx):
		SFXPlayer.play(SFXPlayer.Type.NON_POSITIONAL, self, snd_interact, 0.0)
		set_menu_mode(MenuMode.CHART_SELECT)
	else:
		self.selected_genre = touchdict.genre_idx
		self.selected_song = touchdict.song_idx
		SFXPlayer.play(SFXPlayer.Type.NON_POSITIONAL, self, snd_interact, -4.5)

func touch_select_chart(touchdict):
	if touchdict.chart_idx == selected_difficulty:
		SFXPlayer.play(SFXPlayer.Type.NON_POSITIONAL, self, snd_interact, 0.0)
		set_menu_mode(MenuMode.GAMEPLAY)
	elif touchdict.chart_idx < 0:
		SFXPlayer.play(SFXPlayer.Type.NON_POSITIONAL, self, snd_interact, -3.0, 0.7)
		set_menu_mode(MenuMode.SONG_SELECT)
	else:
		self.selected_difficulty = touchdict.chart_idx
		SFXPlayer.play(SFXPlayer.Type.NON_POSITIONAL, self, snd_interact, -4.5)

func touch_score_screen(touchdict):
	if touchdict.has("next_menu"):
		set_menu_mode(touchdict.next_menu)

func finished_song(song_key, score_data):
	scorescreen_song_key = song_key
	scorescreen_score_data = score_data
	set_menu_mode(MenuMode.SCORE_SCREEN)


func _input(event):
	if event is InputEventScreenTouch:
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
				MenuMode.SCORE_SCREEN:
					for d in touch_rects[MenuMode.SCORE_SCREEN]:
						if d.rect.has_point(pos):
							touch_score_screen(d)
	match menu_mode:
		MenuMode.SONG_SELECT:
			if event.is_action_pressed("ui_right"):
				selected_song += 1
			elif event.is_action_pressed("ui_left"):
				selected_song -= 1
			elif event.is_action_pressed("ui_up"):
				selected_genre = int(max(0, selected_genre - 1))
			elif event.is_action_pressed("ui_down"):
				selected_genre = int(min(1, selected_genre + 1))
			elif event.is_action_pressed("ui_page_up"):
				selected_difficulty = int(max(0, selected_difficulty - 1))
			elif event.is_action_pressed("ui_page_down"):
				selected_difficulty = int(min(4, selected_difficulty + 1))
