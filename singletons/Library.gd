extends Node

const difficulty_translations = {'01': 'Z', '02': 'B', '03': 'A', '04': 'E', '05': 'M', '06': 'R', '10': '宴'}  # A bit redundant now but might be useful later for other hacks


class MultilangStr:
	# Automatically propogate higher langs to lower ones if lower ones are missing.
	# e.g. if we don't have a proper english title, return the transliterated one instead
	# If I could alias properties, these would have their full names as well, but no point duplicating variables for the longform.
	var n := '' setget set_native
	var tl := '' setget set_translit
	var en := '' setget set_english
	func _init(native='', translit='', english=''):
		self.n = native
		if translit and not translit.empty():
			self.tl = translit
		if english and not english.empty():
			self.en = english
	func set_native(native) -> void:
		n = native
		if tl.empty():
			set_translit(native)
	func set_translit(translit) -> void:
		tl = translit
		if en.empty():
			set_english(translit)
	func set_english(english) -> void:
		en = english
	func _to_string() -> String:
		return self[GameTheme.display_language]


class Song:
	var title: MultilangStr
	var subtitle: MultilangStr
	var artist: MultilangStr
	var BPM: float
	var bpm_beats: Array
	var bpm_values: Array
	var dynamic_bpm: bool
	var genre: String
	var filepath: String  # For now this excludes the 'songs/' bit.
	var tile_filename: String
	var audio_filelist: Array
	var video_filelist: Array
	var chart_filelist: Array
	var audio_offsets: Array
	var video_offsets: Array
	var audio_preview_times: Array
	var chart_difficulties := {}
	const default_difficulty_keys = ['Z', 'B', 'A', 'E', 'M', 'R', '宴']
	const difficulty_key_ids = {'Z':0, 'B':1, 'A':2, 'E':3, 'M':4, 'R':5, '宴':6}

	func _init(values: Dictionary):
		title = MultilangStr.new(values.get('title', ''), values.get('title_transliteration', ''), values.get('title_english', ''))
		subtitle = MultilangStr.new(values.get('subtitle', ''), values.get('subtitle_transliteration', ''), values.get('subtitle_english', ''))
		artist = MultilangStr.new(values.get('artist', ''), values.get('artist_transliteration', ''), values.get('artist_english', ''))

		dynamic_bpm = false
		if 'bpm_values' in values:
			bpm_values = values['bpm_values']
			BPM = bpm_values[0]
			bpm_beats = values.get('bpm_beats', [0.0])
			dynamic_bpm = true if len(bpm_beats) > 1 and len(bpm_beats)==len(bpm_values) else false
		if 'bpm' in values:
			BPM = values['bpm']

		filepath = values.get('filepath', '')
		tile_filename = values.get('tile_filename', '%s.png'%values.get('index', 'tile'))
		audio_filelist = values.get('audio_filelist', ['%s.ogg'%values.get('index', 'audio')])
		video_filelist = values.get('video_filelist', ['%s.webm'%values.get('index', 'video')])
		audio_offsets = values.get('audio_filelist', [0.0, 240.0/BPM])
		video_offsets = values.get('video_filelist', [0.0, 240.0/BPM])
		audio_preview_times = values.get('audio_preview_times', [1.0, 1.0])
		genre = values.get('genre', 'None')

		chart_filelist = values.get('chart_filelist', ['%s.rgtm'%values.get('index', 'charts')])

		var diffs = values['chart_difficulties']
		match typeof(diffs):
			TYPE_DICTIONARY:
				chart_difficulties = diffs
			TYPE_ARRAY:
				for i in min(len(diffs), len(default_difficulty_keys)):
					chart_difficulties[default_difficulty_keys[i]] = diffs[i]
			_:
				print_debug('Invalid chart_difficulties!', title.en)

	func get_BPM(realtime:=0.0):
		if not dynamic_bpm:
			return BPM
		# TODO: some dynamic behaviour when all that jazz is implemented


var all_songs = {}
var genre_ids = {}  # String: int
var genre_titles = []  # Strings
var genre_songs = []  # Dictionaries of key: Song

var tile_tex_cache = {}  # We'll need some way of managing this later since holding all the tiles in memory might be expensive
var charts_cache = {}


func add_song(key: String, data: Dictionary):
	if not data.has('index'):
		data['index'] = key
	var song = Song.new(data)
	all_songs[key] = song
	if not genre_ids.has(song.genre):
		genre_ids[song.genre] = len(genre_titles)
		genre_titles.append(song.genre)
		genre_songs.append({})
	genre_songs[genre_ids[song.genre]][key] = song


func get_song_tile_texture(song_key):
	if song_key in tile_tex_cache:
		return tile_tex_cache[song_key]
	elif song_key in all_songs:
		tile_tex_cache[song_key] = FileLoader.load_image('songs/' + all_songs[song_key].filepath.rstrip('/') + '/' + all_songs[song_key].tile_filename)
		return tile_tex_cache[song_key]
	else:
		print_debug('Invalid song_key: ', song_key)


func get_song_charts(song_key):
	if song_key in charts_cache:
		return charts_cache[song_key]
	elif song_key in all_songs:
		var charts = FileLoader.load_filelist(all_songs[song_key].chart_filelist, 'songs/'+all_songs[song_key].filepath)
		# Need to fix keys on this to match the song
		var diffs = all_songs[song_key].chart_difficulties
		var missing_diffs = []
		var unid_charts = []
		for k in diffs:
			if not (k in charts):
				missing_diffs.push_back(k)
		for k in charts:
			if not (k in diffs):
				unid_charts.push_back(k)
		for i in len(missing_diffs):
			if i < len(unid_charts):
				charts[missing_diffs[i]] = charts[unid_charts[i]]
				charts.erase(unid_charts[i])

		charts_cache[song_key] = charts
		return charts_cache[song_key]
	else:
		print_debug('Invalid song_key: ', song_key)


func initialize():
	pass
