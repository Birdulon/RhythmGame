extends Node2D

var song_defs = {}
var song_images = {}
var genres = {}

enum ChartDifficulty {EASY, BASIC, ADV, EXPERT, MASTER}

var selected_genre := 0
var selected_song := 0
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
	update()

func draw_string_centered(font, position, string, color := Color.white):
	draw_string(font, Vector2(position.x - font.get_string_size(string).x/2.0, position.y + font.get_ascent()), string, color)

func _draw():
	var songs = len(song_defs)
	var size = 216
	var spacer_x = 12
	var spacer_y = 64
	var outline_px = 3
	var x = -(size + spacer_x)*2
	var y = -(size + spacer_y)
	var sel_scales := [1.0, 0.8, 0.64, 0.512]
	var sel_cumscales := [1.0, 1.8, 2.44, 2.952]
	var bg_scales := [0.64, 0.64, 0.64, 0.512]
	var bg_cumscales := [0.64, 1.28, 1.92, 2.432]

	var gy := -160
	for g in len(genres):
		var selected: bool = (g == selected_genre)
		var scales = sel_scales if selected else bg_scales
		var cumscales = sel_cumscales if selected else bg_cumscales
		var genre = genres.keys()[g]
		draw_string_centered(GenreFont, Vector2(0, gy), genre)
		var songslist = genres[genre]
		var s = len(songslist)
		var key = songslist[selected_song%s]
		var subsize = size * scales[0]
		y = gy + spacer_y
		draw_rect(Rect2(-subsize/2.0 - outline_px, y - outline_px, subsize + outline_px*2, subsize + outline_px*2), GameTheme.COLOR_DIFFICULTY[selected_difficulty])
		draw_texture_rect(song_images[key], Rect2(-subsize/2.0, y, subsize, subsize), false)
		if selected:
			draw_string_centered(TitleFont, Vector2(0, y+subsize), song_defs[key]["title"], Color(0.95, 0.95, 1.0))
		draw_string_centered(GenreFont, Vector2(subsize/2.0 - 24, gy+subsize+8), str(song_defs[key]["chart_difficulties"][selected_difficulty]), GameTheme.COLOR_DIFFICULTY[selected_difficulty])
		for i in [1, 2, 3]:
			key = songslist[(selected_song+i)%s]
			subsize = size * scales[i]
			var gx = size * (cumscales[i] - scales[0]*0.5 - scales[i]*0.5) + spacer_x * i
			draw_rect(Rect2(gx - subsize/2.0 - outline_px, y - outline_px, subsize + outline_px*2, subsize + outline_px*2), GameTheme.COLOR_DIFFICULTY[selected_difficulty])
			draw_texture_rect(song_images[key], Rect2(gx - subsize/2.0, y, subsize, subsize), false)
			draw_string_centered(GenreFont, Vector2(gx + subsize/2.0 - 24, gy+subsize+8), str(song_defs[key]["chart_difficulties"][selected_difficulty]), GameTheme.COLOR_DIFFICULTY[selected_difficulty])
			key = songslist[(selected_song-i)%s]
			draw_rect(Rect2(-gx - subsize/2.0 - outline_px, y - outline_px, subsize + outline_px*2, subsize + outline_px*2), GameTheme.COLOR_DIFFICULTY[selected_difficulty])
			draw_texture_rect(song_images[key], Rect2(-gx - subsize/2.0, y, subsize, subsize), false)
			draw_string_centered(GenreFont, Vector2(-gx + subsize/2.0 - 24, gy+subsize+8), str(song_defs[key]["chart_difficulties"][selected_difficulty]), GameTheme.COLOR_DIFFICULTY[selected_difficulty])
		gy += size + (spacer_y * 2)

#	for key in song_images:
#		draw_texture_rect(song_images[key], Rect2(x, y, size, size), false)
#		draw_string_centered(TitleFont, Vector2(x+size/2.0, y+size), song_defs[key]["title"], Color(0.95, 0.95, 1.0))
#		x += size + spacer_x
#		if x >= (size + spacer_x)*2:
#			x = -(size + spacer_x)*2
#			y += size + spacer_y