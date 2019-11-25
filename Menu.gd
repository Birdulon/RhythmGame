extends Node2D

var song_defs = {}
var song_images = {}
var genres = {}

enum ChartDifficulty {EASY, BASIC, ADV, EXPERT, MASTER}

var selected_genre: int = 0
var selected_song: int = 0
var selected_song_delta: float = 0.0  # For floaty display scrolling
var selected_song_speed: float = 0.25  # For floaty display scrolling
var selected_difficulty = ChartDifficulty.ADV

var TitleFont := preload("res://assets/MenuTitleFont.tres")
var GenreFont := preload("res://assets/MenuGenreFont.tres")

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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	selected_song_delta += selected_song_speed * delta
	if selected_song_delta > 0.5:
		selected_song_delta -= 1.0
		selected_song += 1
	elif selected_song_delta < -0.5:
		selected_song_delta += 1.0
		selected_song -= 1
	update()

func draw_string_centered(font, position, string, color := Color.white):
	draw_string(font, Vector2(position.x - font.get_string_size(string).x/2.0, position.y + font.get_ascent()), string, color)

func draw_songtile(song_key, position, size, title_text:=false, difficulty=selected_difficulty, outline_px:=3):
	# Draws from top left-corner.
	# Draw difficulty-colored outline
	var diff_color := GameTheme.COLOR_DIFFICULTY[difficulty*2]
	draw_rect(Rect2(position.x - outline_px, position.y - outline_px, size + outline_px*2, size + outline_px*2), diff_color)
	draw_texture_rect(song_images[song_key], Rect2(position.x, position.y, size, size), false)
	# Draw track difficulty rating
	draw_string_centered(GenreFont, Vector2(position.x+size-24, position.y+size-56), diffstr(song_defs[song_key]["chart_difficulties"][difficulty]), diff_color)
	if title_text:
		draw_string_centered(TitleFont, Vector2(position.x + size/2.0, position.y+size), song_defs[song_key]["title"], Color(0.95, 0.95, 1.0))

func diffstr(difficulty: float):
	# Convert .5 to +
	return str(int(floor(difficulty))) + ("+" if fmod(difficulty, 1.0)>0.4 else "")

func _draw():
	var songs = len(song_defs)
	var size = 216
	var spacer_x = 12
	var spacer_y = 64
	var outline_px = 3
	var center_x = 0.0
	var sel_scales := [1.0, 0.8, 0.64, 0.512, 0.4096]
	var bg_scales := [0.64, 0.64, 0.64, 0.512, 0.4096]

	var gy := -160.0
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
		var gx = center_x - (subsize + spacer_x) * selected_song_delta
		var genre = genres.keys()[g]
		draw_string_centered(GenreFont, Vector2(0, gy), genre)
		var songslist = genres[genre]
		var s = len(songslist)
		var key = songslist[selected_song % s]
		var y = gy + spacer_y
		var x = -subsize/2.0
		draw_songtile(key, Vector2(gx+x, y), subsize, selected, selected_difficulty)
		for i in [1, 2, 3, 4]:
			x += subsize + spacer_x
			subsize = size * scales[i]
			draw_songtile(songslist[(selected_song+i) % s], Vector2(gx+x, y), subsize)
		subsize = size * scales[0]
		x = -subsize/2.0
		for i in [1, 2, 3, 4]:
			x += subsize + spacer_x
			subsize = size * scales[-i]
			draw_songtile(songslist[(selected_song-i) % s], Vector2(gx-x - subsize, y), subsize)
		gy += size + (spacer_y * 2)


func _input(event):
	if event.is_action_pressed("ui_right"):
		selected_song += 1
	if event.is_action_pressed("ui_left"):
		selected_song -= 1
	if event.is_action_pressed("ui_up"):
		selected_genre = int(max(0, selected_genre - 1))
	if event.is_action_pressed("ui_down"):
		selected_genre = int(min(1, selected_genre + 1))
	if event.is_action_pressed("ui_page_up"):
		selected_difficulty = int(max(0, selected_difficulty - 1))
	if event.is_action_pressed("ui_page_down"):
		selected_difficulty = int(min(4, selected_difficulty + 1))
