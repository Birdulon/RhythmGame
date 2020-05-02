extends Node

class MultilangStr:
	# Automatically propogate higher langs to lower ones if lower ones are missing.
	# e.g. if we don't have a proper english title, return the transliterated one instead
	# If I could alias properties, these would have their full names as well, but no point duplicating variables for the longform.
	var n := '' setget set_native
	var tl := '' setget set_translit
	var en := '' setget set_english
	func _init(native='', translit='', english=''):
		self.n = native
		if not translit.empty():
			self.tl = translit
		if not english.empty:
			self.en = english
#	func get_native() -> String:
#		return n
#	func get_translit() -> String:
#		return tl if tl else n
#	func get_english() -> String:
#		return en if en else self.tl
	func set_native(native) -> void:
		n = native
		if tl.empty():
			tl = native
	func set_translit(translit) -> void:
		tl = translit
		if en.empty():
			en = translit
	func set_english(english) -> void:
		en = english

class Song:
	var title: MultilangStr
	var subtitle: MultilangStr
	var artist: MultilangStr
	var BPM: float
	var bpm_beats: Array
	var bpm_values: Array
	var dynamic_bpm: bool
	var genre: String
	var tile_filename: String
	var audio_filelist: Array
	var video_filelist: Array
	var chart_filelist: Array
	var audio_offsets: Array
	var video_offsets: Array
	var audio_preview_times: Array
	var video_dimensions: Array
	var chart_difficulties: Dictionary
	const default_difficulty_keys = ['Z', 'B', 'A', 'E', 'M', 'R']

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

		tile_filename = values.get('tile_filename', '%s.png'%values.get('index', 'tile'))
		audio_filelist = values.get('audio_filelist', ['%s.ogg'%values.get('index', 'audio')])
		video_filelist = values.get('video_filelist', ['%s.webm'%values.get('index', 'video')])
		video_dimensions = values.get('video_dimensions', [1.0, 1.0])
		audio_preview_times = values.get('video_dimensions', [1.0, 1.0])
		genre = values.get('genre', 'None')

		chart_filelist = values.get('chart_filelist', ['%s.rtgm'%values.get('index', 'charts')])

		var diffs = values['chart_difficulties']
		match typeof(diffs):
			TYPE_DICTIONARY:
				chart_difficulties = diffs
			TYPE_ARRAY:
				chart_difficulties = {}
				for i in min(len(diffs), len(default_difficulty_keys)):
					chart_difficulties[default_difficulty_keys[i]] = diffs[i]
			_:
				print_debug('Invalid chart_difficulties!', title.en)
				chart_difficulties = {}

	func get_BPM(realtime:=0.0):
		if not dynamic_bpm:
			return BPM
		# TODO: some dynamic behaviour when all that jazz is implemented


var all_songs = {}
var genre_ids = {}
var genre_titles = []
var genre_songs = []

var tile_tex_cache = {}  # We'll need some way of managing this later since holding all the tiles in memory might be expensive
var charts_cache = {}

func get_song_tile_texture(song_key):
	if song_key in tile_tex_cache:
		return tile_tex_cache[song_key]
	elif song_key in all_songs:
		tile_tex_cache[song_key] = load(all_songs[song_key].tile_filename)
		return tile_tex_cache[song_key]
	else:
		print_debug('Invalid song_key: ', song_key)

func get_song_charts(song_key):
	if song_key in charts_cache:
		return charts_cache[song_key]
	elif song_key in all_songs:
		charts_cache[song_key] = FileLoader.load_filelist(all_songs[song_key].chart_filelist)
		return charts_cache[song_key]
	else:
		print_debug('Invalid song_key: ', song_key)

func initialize():
	pass
