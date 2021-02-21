#extends Object
extends Node

const ERROR_CODES := [
	'OK', 'FAILED', 'ERR_UNAVAILABLE', 'ERR_UNCONFIGURED', 'ERR_UNAUTHORIZED', 'ERR_PARAMETER_RANGE_ERROR',
	'ERR_OUT_OF_MEMORY', 'ERR_FILE_NOT_FOUND', 'ERR_FILE_BAD_DRIVE', 'ERR_FILE_BAD_PATH','ERR_FILE_NO_PERMISSION',
	'ERR_FILE_ALREADY_IN_USE', 'ERR_FILE_CANT_OPEN', 'ERR_FILE_CANT_WRITE', 'ERR_FILE_CANT_READ', 'ERR_FILE_UNRECOGNIZED',
	'ERR_FILE_CORRUPT', 'ERR_FILE_MISSING_DEPENDENCIES', 'ERR_FILE_EOF', 'ERR_CANT_OPEN', 'ERR_CANT_CREATE', 'ERR_QUERY_FAILED',
	'ERR_ALREADY_IN_USE', 'ERR_LOCKED', 'ERR_TIMEOUT', 'ERR_CANT_CONNECT', 'ERR_CANT_RESOLVE', 'ERR_CONNECTION_ERROR',
	'ERR_CANT_ACQUIRE_RESOURCE', 'ERR_CANT_FORK', 'ERR_INVALID_DATA', 'ERR_INVALID_PARAMETER', 'ERR_ALREADY_EXISTS',
	'ERR_DOES_NOT_EXIST', 'ERR_DATABASE_CANT_READ', 'ERR_DATABASE_CANT_WRITE', 'ERR_COMPILATION_FAILED', 'ERR_METHOD_NOT_FOUND',
	'ERR_LINK_FAILED', 'ERR_SCRIPT_FAILED', 'ERR_CYCLIC_LINK', 'ERR_INVALID_DECLARATION', 'ERR_DUPLICATE_SYMBOL',
	'ERR_PARSE_ERROR', 'ERR_BUSY', 'ERR_SKIP', 'ERR_HELP', 'ERR_BUG'
]

var userroot := OS.get_user_data_dir().rstrip('/')+'/' if OS.get_name() != 'Android' else '/storage/emulated/0/RhythmGame/'
var PATHS := PoolStringArray([userroot, '/media/fridge-q/Games/RTG/slow_userdir/'])  # Temporary hardcoded testing
# The following would probably work. One huge caveat is that permission needs to be manually granted by the user in app settings as we can't use OS.request_permission('WRITE_EXTERNAL_STORAGE')
# '/storage/emulated/0/Android/data/au.ufeff.rhythmgame/'
# '/sdcard/Android/data/au.ufeff.rhythmgame/'
func _ready() -> void:
	print('Library paths: ', PATHS)

func find_file(name: String) -> String:
	# Searches through all of the paths to find the file
	var file := File.new()
	for root in PATHS:
		var filename: String = root + name
		if file.file_exists(filename):
			return filename
	return ''

func directory_list(directory: String, hidden: bool, sort:=true) -> Dictionary:
	# Sadly there's no filelist sugar so we make our own
	var output = {folders=[], files=[], err=OK}
	var dir = Directory.new()
	output.err = dir.open(directory)
	if output.err != OK:
		print_debug('Failed to open directory: ' + directory + '(Error code '+output.err+')')
		return output
	output.err = dir.list_dir_begin(true, !hidden)
	if output.err != OK:
		print_debug('Failed to begin listing directory: ' + directory + '(Error code '+output.err+')')
		return output

	var item = dir.get_next()
	while (item != ''):
		if dir.current_is_dir():
			output['folders'].append(item)
		else:
			output['files'].append(item)
		item = dir.get_next()
	dir.list_dir_end()

	if sort:
		output.folders.sort()
		output.files.sort()
	# Maybe convert the Arrays to PoolStringArrays?
	return output

func find_by_extensions(array, extensions=null) -> Dictionary:
	# Both args can be Array or PoolStringArray
	# If extensions omitted, do all extensions
	var output = {}
	if extensions:
		for ext in extensions:
			output[ext] = []
		for filename in array:
			for ext in extensions:
				if filename.ends_with(ext):
					output[ext].append(filename)
	else:
		for filename in array:
			var ext = filename.rsplit('.', false, 1)[1]
			if ext in output:
				output[ext].append(filename)
			else:
				output[ext] = [filename]
	return output

const default_difficulty_keys = ['Z', 'B', 'A', 'E', 'M', 'R']
func scan_library():
	print('Scanning library')
	var song_defs = {}
	var collections = {}
	var genres = {}

	for root in PATHS:
		var rootdir = root + 'songs'
		var dir = Directory.new()
		var err = dir.make_dir_recursive(rootdir)
		if err != OK:
			print_debug('An error occurred while trying to create the songs directory: ', err)
			return err

		var songslist = directory_list(rootdir, false)
		if songslist.err != OK:
			print('An error occurred when trying to access the songs directory: ', songslist.err)
			return songslist.err

		dir.open(rootdir)
		for folder in songslist.folders:
			var full_folder := '%s/%s' % [rootdir, folder]

			if dir.file_exists(folder + '/song.json'):
				# Our format
				song_defs[folder] = FileLoader.load_folder(full_folder)
				print('Loaded song directory: %s' % folder)
				if song_defs[folder]['genre'] in genres:
					genres[song_defs[folder]['genre']].append(folder)
				else:
					genres[song_defs[folder]['genre']] = [folder]
				if typeof(song_defs[folder]['chart_difficulties']) == TYPE_ARRAY:
					var diffs = song_defs[folder]['chart_difficulties']
					var chart_difficulties = {}
					for i in min(len(diffs), len(default_difficulty_keys)):
						chart_difficulties[default_difficulty_keys[i]] = diffs[i]
					song_defs[folder]['chart_difficulties'] = chart_difficulties

			elif dir.file_exists(folder + '/collection.json'):
				var collection = FileLoader.load_folder(full_folder, 'collection')
				collections[folder] = collection
				var base_dict = {'filepath': folder+'/'}  # Top level of the collection dict contains defaults for every song in it
				for key in collection.keys():
					if key != 'songs':
						base_dict[key] = collection[key]
				for song_key in collection['songs'].keys():
					var song_dict = collection['songs'][song_key]
					var song_def = base_dict.duplicate()
					for key in song_dict.keys():
						song_def[key] = song_dict[key]
					Library.add_song(song_key, song_def)
					# Legacy compat stuff
					song_defs[song_key] = song_def
					if song_defs[song_key]['genre'] in genres:
						genres[song_defs[song_key]['genre']].append(song_key)
					else:
						genres[song_defs[song_key]['genre']] = [song_key]

			else:
				var files_by_ext = find_by_extensions(directory_list(full_folder, false).files)
				if 'sm' in files_by_ext:
					var sm_filename = files_by_ext['sm'][0]
					print(sm_filename)
					var thing = SM.load_file(full_folder + '/' + sm_filename)
					print(thing)
					pass
				else:
					print('Found non-song directory: ' + folder)
		for file in songslist.files:
			print('Found file: ' + file)

	return {song_defs=song_defs, genres=genres}



class SRT:
	const TAP_DURATION := 0.062500
	const ID_BREAK := 4
	const ID_HOLD := 2
	const ID_SLIDE_END := 128
	const ID3_SLIDE_CHORD := 0  # Straight line
	const ID3_SLIDE_ARC_CW := 1
	const ID3_SLIDE_ARC_ACW := 2

	static func load_file(filename):
		var file = File.new()
		var err = file.open(filename, File.READ)
		if err != OK:
			print(err)
			return err
		var metadata := {}
		var num_taps := 0
		var num_holds := 0
		var num_slides := 0
		var notes := []
		var beats_per_measure := 4
		var length = file.get_len()
		var slide_ids = {}
		while (file.get_position() < (length-2)):
			var noteline = file.get_csv_line()
			var time_hit := (float(noteline[0]) + (float(noteline[1]))) * beats_per_measure
			var duration := float(noteline[2]) * beats_per_measure
			var column := int(noteline[3])
			var id := int(noteline[4])
			var id2 := int(noteline[5])
			var id3 := int(noteline[6])

			match id:
				ID_HOLD:
					notes.push_back(Note.NoteHold.new(time_hit, column, duration))
					num_holds += 1
				ID_BREAK:
					notes.push_back(Note.NoteTap.new(time_hit, column, true))
					num_taps += 1
				ID_SLIDE_END:
					# id2 is slide ID
					if id2 in slide_ids:
						slide_ids[id2].column_release = column
						slide_ids[id2].update_slide_variables()
				_:
					if id2 == 0:
						notes.push_back(Note.NoteTap.new(time_hit, column))
						num_taps += 1
					else:
						# id2 is slide ID, id3 is slide pattern
						# In order to properly declare the slide, we need the paired endcap which may not be the next note
						var slide_type = Note.SlideType.CHORD
						match id3:
							ID3_SLIDE_CHORD:
								slide_type = Note.SlideType.CHORD
							ID3_SLIDE_ARC_CW:
								slide_type = Note.SlideType.ARC_CW
							ID3_SLIDE_ARC_ACW:
								slide_type = Note.SlideType.ARC_ACW
							_:
								print('Unknown slide type: ', id3)
						var note = Note.NoteStar.new(time_hit, column)
						num_slides += 1
						note.duration = duration
						notes.push_back(note)
						var slide = Note.NoteSlide.new(time_hit, column, duration, -1, slide_type)
						notes.push_back(slide)
						slide_ids[id2] = slide
		metadata['num_taps'] = num_taps
		metadata['num_holds'] = num_holds
		metadata['num_slides'] = num_slides
		return [metadata, notes]


class RGT:
	# RhythmGameText formats
	# .rgts - simplified format cutting out redundant data, should be easy to write charts in
	# .rgtx - a lossless representation of MM in-memory format
	# .rgtm - a collection of rgts charts, with a [title] at the start of each one
	enum Format{RGTS, RGTX, RGTM}
	const EXTENSIONS = {
		'rgts': Format.RGTS,
		'rgtx': Format.RGTX,
		'rgtm': Format.RGTM,
	}
	const NOTE_TYPES = {
		't': Note.NOTE_TAP,
		'h': Note.NOTE_HOLD,
		's': Note.NOTE_STAR,
		'e': Note.NOTE_SLIDE,
		'b': Note.NOTE_TAP,  # Break
		'x': Note.NOTE_STAR  # Break star
	}
	const SLIDE_TYPES = {
		'0': null,  # Seems to be used for stars without slides attached
		'1': Note.SlideType.CHORD,
		'2': Note.SlideType.ARC_ACW,
		'3': Note.SlideType.ARC_CW,
		'4': Note.SlideType.COMPLEX,  # Orbit around center ACW on the way
		'5': Note.SlideType.COMPLEX,  # CW of above
		'6': Note.SlideType.COMPLEX,  # S zigzag through center
		'7': Note.SlideType.COMPLEX,  # Z zigzag through center
		'8': Note.SlideType.COMPLEX,  # V into center
		'9': Note.SlideType.COMPLEX,  # Go to center then orbit off to the side ACW
		'a': Note.SlideType.COMPLEX,  # CW of above
		'b': Note.SlideType.COMPLEX,  # V into column 2 places ACW
		'c': Note.SlideType.COMPLEX,  # V into column 2 places CW
		'd': Note.SlideType.CHORD_TRIPLE,  # Triple cone. Spreads out to the adjacent receptors of the target.
		'e': Note.SlideType.CHORD,  # Not used in any of our charts
		'f': Note.SlideType.CHORD,  # Not used in any of our charts
	}
	const SLIDE_IN_R := sin(PI/8)  # Circle radius circumscribed by chords 0-3, 1-4, 2-5 etc.

	static func load_file(filename: String):
		var extension = filename.rsplit('.', false, 1)[1]
		if not EXTENSIONS.has(extension):
			return -1
		var format = EXTENSIONS[extension]
		var file := File.new()
		var err := file.open(filename, File.READ)
		if err != OK:
			print(err)
			return err
		var length = file.get_len()
		var chart_ids = []
		var lines = [[]]
		# This loop will segment the lines as if the file were RGTM
		while (file.get_position() < (length-1)):  # Could probably replace this with file.eof_reached()
			var line : String = file.get_line()
			if line.begins_with('['):  # Split to a new list for each chart definition
				chart_ids.append(line.lstrip('[').rstrip(']'))
				lines.append([])
			elif !line.empty():
				lines[-1].push_back(line)
		file.close()
		print('Parsing chart: ', filename)

		match format:
			Format.RGTS:
				var metadata_and_notes = parse_rgts(lines[0])
				return metadata_and_notes
			Format.RGTX:
				var metadata_and_notes = parse_rgtx(lines[0])
				return metadata_and_notes
			Format.RGTM:
				lines.pop_front()  # Anything before the first [header] is meaningless
				var charts = {}
				for i in len(lines):
					charts[chart_ids[i]] = parse_rgts(lines[i])
				return charts
		return format

	static func parse_rgtx(lines: PoolStringArray):
		return []  # To be implemented later

	const beats_per_measure = 4.0  # TODO: Bit of an ugly hack, need to revisit this later
	static func parse_rgts(lines: PoolStringArray):
		var metadata := {}
		var num_taps := 0
		var num_holds := 0
		var num_slides := 0
		var notes := []
		var slide_ids := {}
		var slide_stars := {}  # Multiple stars might link to one star. We only care about linking for the spin speed.
		var last_star := []
		for i in Rules.COLS:
			last_star.append(null)

		for line in lines:
			if len(line) < 4:  # shortest legal line would be like '1:1t'
				continue
			var s = line.split(':')
			var time := float(s[0]) * beats_per_measure
			var note_hits := []
			var note_nonhits := []
			for i in range(1, len(s)):
				var n = s[i]
				var column := int(n[0])
				var ntype = n[1]
				n = n.substr(2)

				match ntype:
					't', 'b':  # tap
						note_hits.append(Note.NoteTap.new(time, column, ntype=='b'))
						num_taps += 1
					'h':  # hold
						var duration = float(n) * beats_per_measure
						note_hits.append(Note.NoteHold.new(time, column, duration))
						num_holds += 1
					's', 'x':  # slide star
						var star = Note.NoteStar.new(time, column, ntype=='z')
						note_hits.append(star)
						num_slides += 1
						last_star[column] = star
						if len(n) > 1:  # Not all stars have proper slide info
							var slide_type = n[0]  # hex digit
							var slide_id = int(n.substr(1))
							if slide_id > 0:
								slide_stars[slide_id] = star
								var slide = Note.NoteSlide.new(time, column)
								slide_ids[slide_id] = slide
								note_nonhits.append(slide)
					'e':  # slide end
						var slide_type = n[0]  # numeric digit, left as str just in case
						var slide_id = int(n.substr(1))
						if slide_id in slide_ids:  # Classic slide end
							slide_ids[slide_id].time_release = time
							if slide_id in slide_stars:
								slide_stars[slide_id].duration = slide_ids[slide_id].duration  # Should probably recalc in case start time is different but w/e
							slide_ids[slide_id].column_release = column
							slide_ids[slide_id].slide_type = SLIDE_TYPES[slide_type]
							slide_ids[slide_id].update_slide_variables()
							if SLIDE_TYPES[slide_type] == Note.SlideType.COMPLEX:
								var col_hit = slide_ids[slide_id].column
								var RUV = GameTheme.RADIAL_UNIT_VECTORS
								var RCA = GameTheme.RADIAL_COL_ANGLES
								slide_ids[slide_id].values.curve2d.add_point(RUV[col_hit])  # Start col
								match slide_type:
									'4':  # Orbit ACW around center. Size of loop is roughly inscribed in chords of 0-3, 1-4, 2-5...   NB: doesn't loop if directly opposite col
										Note.curve2d_make_orbit(slide_ids[slide_id].values.curve2d, RCA[col_hit], RCA[column], true)
									'5':  # CW of above
										Note.curve2d_make_orbit(slide_ids[slide_id].values.curve2d, RCA[col_hit], RCA[column], false)
									'6':  # S zigzag through center
										slide_ids[slide_id].values.curve2d.add_point(RUV[posmod(col_hit-2, Rules.COLS)] * SLIDE_IN_R)
										slide_ids[slide_id].values.curve2d.add_point(RUV[posmod(col_hit+2, Rules.COLS)] * SLIDE_IN_R)
									'7':  # Z zigzag through center
										slide_ids[slide_id].values.curve2d.add_point(RUV[posmod(col_hit+2, Rules.COLS)] * SLIDE_IN_R)
										slide_ids[slide_id].values.curve2d.add_point(RUV[posmod(col_hit-2, Rules.COLS)] * SLIDE_IN_R)
									'8':  # V into center
										slide_ids[slide_id].values.curve2d.add_point(Vector2.ZERO)
									'9':  # Orbit off-center ACW
										Note.curve2d_make_sideorbit(slide_ids[slide_id].values.curve2d, RCA[col_hit], RCA[column], true)
									'a':  # CW of above
										Note.curve2d_make_sideorbit(slide_ids[slide_id].values.curve2d, RCA[col_hit], RCA[column], false)
									'b':  # V into column 2 places ACW
										slide_ids[slide_id].values.curve2d.add_point(RUV[posmod(col_hit-2, Rules.COLS)])
									'c':  # V into column 2 places CW
										slide_ids[slide_id].values.curve2d.add_point(RUV[posmod(col_hit+2, Rules.COLS)])
								slide_ids[slide_id].values.curve2d.add_point(RUV[column])  # End col
						else:  # Naked slide start
							if last_star[column] != null:
								slide_stars[slide_id] = last_star[column]
							else:
								print_debug('Naked slide with no prior star in column!')
							var note = Note.NoteSlide.new(time, column)
							slide_ids[slide_id] = note
							note_nonhits.append(note)
					'_':
						print_debug('Unknown note type: ', ntype)

			if len(note_hits) > 1:
				for note in note_hits:  # Set multihit on each one
					note.double_hit = true
			notes += note_hits + note_nonhits
		metadata['num_taps'] = num_taps
		metadata['num_holds'] = num_holds
		metadata['num_slides'] = num_slides
		return [metadata, notes]


class SM:
	# Stepmania simfile

	const NOTE_VALUES = {
		'0': 'None',
		'1': 'Tap',
		'2': 'HoldStart',
		'3': 'HoldRollEnd',
		'4': 'RollStart',
		'M': 'Mine',
		# These three are less likely to show up anywhere, no need to implement
		'K': 'Keysound',
		'L': 'Lift',
		'F': 'Fake',
	}

	const CHART_DIFFICULTIES = {
		'Beginner': 0,
		'Easy': 1,
		'Medium': 2,
		'Hard': 3,
		'Challenge': 4,
		'Edit': 5,
		# Some will just write whatever for special difficulties, but we should at least color-code these standard ones
	}

	const TAG_TRANSLATIONS = {
		'#TITLE': 'title',
		'#SUBTITLE': 'subtitle',
		'#ARTIST': 'artist',
		'#TITLETRANSLIT': 'title_transliteration',
		'#SUBTITLETRANSLIT': 'subtitle_transliteration',
		'#ARTISTTRANSLIT': 'artist_transliteration',
		'#GENRE': 'genre',
		'#CREDIT': 'chart_author',
		'#BANNER': 'image_banner',
		'#BACKGROUND': 'image_background',
#		'#LYRICSPATH': '',
		'#CDTITLE': 'image_cd_title',
		'#MUSIC': 'audio_filelist',
		'#OFFSET': 'audio_offsets',
		'#SAMPLESTART': 'audio_preview_times',
		'#SAMPLELENGTH': 'audio_preview_times',
#		'#SELECTABLE': '',
		'#BPMS': 'bpm_values',
#		'#STOPS': '',
#		'#BGCHANGES': '',
#		'#KEYSOUNDS': '',
	}

	static func load_chart(lines):
		var metadata = {}
		var notes = []

		assert(lines[0].begins_with('#NOTES:'))
		metadata['chart_type'] = lines[1].strip_edges().rstrip(':')
		metadata['description'] = lines[2].strip_edges().rstrip(':')
		metadata['difficulty_str'] = lines[3].strip_edges().rstrip(':')
		metadata['numerical_meter'] = lines[4].strip_edges().rstrip(':')
		metadata['groove_radar'] = lines[5].strip_edges().rstrip(':')

		# Measures are separated by lines that start with a comma
		# Each line has a state for each of the pads, e.g. '0000' for none pressed
		# The lines become even subdivisions of the measure, so if there's 4 lines everything represents a 1/4 beat, if there's 8 lines everything represents a 1/8 beat etc.
		# For this reason it's probably best to just have a float for beat-within-measure rather than integer beats.
		var measures = [[]]
		for i in range(6, len(lines)):
			var line = lines[i].strip_edges()
			if line.begins_with(','):
				measures.append([])
			elif line.begins_with(';'):
				break
			elif len(line) > 0:
				measures[-1].append(line)

		var ongoing_holds = {}
		var num_notes := 0
		var num_jumps := 0
		var num_hands := 0
		var num_holds := 0
		var num_rolls := 0
		var num_mines := 0

		for measure in range(len(measures)):
			var m_lines = measures[measure]
			var m_length = len(m_lines)  # Divide out all lines by this
			for beat in m_length:
				var line : String = m_lines[beat]
				# Jump check at a line-level (check for multiple 1/2/4s)
				var hits : int = line.count('1') + line.count('2') + line.count('4')
				# Hand/quad check more complex as need to check hold/roll state as well
				# TODO: are they exclusive? Does quad override hand override jump? SM5 doesn't have quads and has hands+jumps inclusive
				var total_pressed : int = hits + len(ongoing_holds)
				var jump : bool = hits >= 2
				var hand : bool = total_pressed >= 3
				# var quad : bool = total_pressed >= 4
				num_notes += hits
				num_jumps += int(jump)
				num_hands += int(hand)
				var time = measure + beat/float(m_length)
				for col in len(line):
					match line[col]:
						'1':
							notes.append(Note.NoteTap.new(time, col))
						'2':  # Hold
							ongoing_holds[col] = len(notes)
							notes.append(Note.NoteHold.new(time, col, 0.0))
							num_holds += 1
						'4':  # Roll
							ongoing_holds[col] = len(notes)
							notes.append(Note.NoteRoll.new(time, col, 0.0))
							num_rolls += 1
						'3':  # End Hold/Roll
							assert(ongoing_holds.has(col))
							notes[ongoing_holds[col]].set_time_release(time)
							ongoing_holds.erase(col)
						'M':  # Mine
							num_mines += 1
							pass
		metadata['num_notes'] = num_notes
		metadata['num_taps'] = num_notes - num_jumps
		metadata['num_jumps'] = num_jumps
		metadata['num_hands'] = num_hands
		metadata['num_holds'] = num_holds
		metadata['num_rolls'] = num_rolls
		metadata['num_mines'] = num_mines
		return [metadata, notes]

	static func load_file(filename: String) -> Array:
		# Output is [metadata, [[meta0, chart0], ..., [metaN, chartN]]]
		# Technically, declarations end with a semicolon instead of a linebreak.
		# This is a PITA to do correctly in GDScript and the files in our collection are well-behaved with linebreaks anyway, so we won't bother.
		var file := File.new()
		match file.open(filename, File.READ):
			OK:
				pass
			var err:
				print_debug('Error loading file: ', err)
				return []
		var length = file.get_len()
		var lines = [[]]  # First list will be header, then every subsequent one is a chart
		while (file.get_position() < (length-1)):  # Could probably replace this with file.eof_reached()
			var line : String = file.get_line()
			if line.begins_with('#NOTES'):  # Split to a new list for each chart definition
				lines.append([])
			lines[-1].append(line)
		file.close()

		var metadata = {}
		for line in lines[0]:
			var tokens = line.rstrip(';').split(':')
			if TAG_TRANSLATIONS.has(tokens[0]):
				metadata[TAG_TRANSLATIONS[tokens[0]]] = tokens[1]
			elif len(tokens) >= 2:
				metadata[tokens[0]] = tokens[1]
		var charts = []

		for i in range(1, len(lines)):
			charts.append(load_chart(lines[i]))

		return [metadata, charts]


class Test:
	static func stress_pattern():
		var notes = []
		for bar in range(8):
			notes.push_back(Note.NoteHold.new(bar*4, bar%8, 1))
			for i in range(1, 8):
				notes.push_back(Note.NoteTap.new(bar*4 + (i/2.0), (bar + i)%8))
			notes.push_back(Note.NoteTap.new(bar*4 + (7/2.0), (bar + 3)%8))
		for bar in range(8, 16):
			notes.push_back(Note.NoteHold.new(bar*4, bar%8, 2))
			for i in range(1, 8):
				notes.push_back(Note.NoteTap.new(bar*4 + (i/2.0), (bar + i)%8))
				notes.push_back(Note.NoteTap.new(bar*4 + ((i+0.5)/2.0), (bar + i)%8))
				notes.push_back(Note.make_slide(bar*4 + ((i+1)/2.0), 1, (bar + i)%8, 0))
		for bar in range(16, 24):
			notes.push_back(Note.NoteHold.new(bar*4, bar%8, 2))
			notes.push_back(Note.NoteHold.new(bar*4, (bar+1)%8, 1))
			for i in range(2, 8):
				notes.push_back(Note.NoteTap.new(bar*4 + (i/2.0), (bar + i)%8))
				notes.push_back(Note.NoteHold.new(bar*4 + ((i+1)/2.0), (bar + i)%8, 0.5))
		for bar in range(24, 32):
			notes.push_back(Note.NoteHold.new(bar*4, bar%8, 1))
			for i in range(1, 32):
				notes.push_back(Note.NoteTap.new(bar*4 + (i/8.0), (bar + i)%8))
				if (i%2) > 0:
					notes.push_back(Note.NoteTap.new(bar*4 + (i/8.0), (bar + i + 4)%8))
		for bar in range(32, 48):
			notes.push_back(Note.NoteHold.new(bar*4, bar%8, 1))
			for i in range(1, 32):
				notes.push_back(Note.NoteTap.new(bar*4 + (i/8.0), (bar + i)%8))
				notes.push_back(Note.NoteTap.new(bar*4 + (i/8.0), (bar + i + 3)%8))
		return notes


func load_folder(folder, filename='song'):
	var file = File.new()
	var err = file.open('%s/%s.json' % [folder, filename], File.READ)
	if err != OK:
		print(err)
		return err
	var result_json = JSON.parse(file.get_as_text())
	file.close()
	if result_json.error != OK:
		print('Error: ', result_json.error)
		print('Error Line: ', result_json.error_line)
		print('Error String: ', result_json.error_string)
		return result_json.error
	var result = result_json.result
	result.directory = folder
	return result

func load_filelist(filelist: Array, directory=''):
	var charts = {}
	var key := 0
	for name in filelist:
		var extension: String = name.rsplit('.', true, 1)[-1]
		name = directory.rstrip('/') + '/' + name
		var filename = find_file(name)
		if filename != '':
			match extension:
				'rgtm':  # multiple charts
					var res = RGT.load_file(filename)
					for k in res:
						charts[Library.difficulty_translations.get(k, k)] = res[k]
				'rgts', 'rgtx':  # single chart - The keys for this should be translated afterwards
					charts[key] = RGT.load_file(filename)
					key += 1
				'srt':  # maimai, single chart
					var metadata_and_notes = SRT.load_file(filename)
					Note.process_note_list(metadata_and_notes[1])  # SRT doesn't handle doubles
					charts[key] = metadata_and_notes
					key += 1
				'sm':  # Stepmania, multiple charts
					var res = SM.load_file(filename)
					for chart in res[1]:
						var diff = chart[0].difficulty_str
						charts[diff] = chart[1]
				_:
					pass
	return charts

func direct_load_ogg(filename: String) -> AudioStreamOGGVorbis:
	# Loads the ogg file with that exact filename
	var audiostream = AudioStreamOGGVorbis.new()
	var oggfile = File.new()
	oggfile.open(filename, File.READ)
	audiostream.set_data(oggfile.get_buffer(oggfile.get_len()))
	oggfile.close()
	return audiostream

var fallback_audiostream = AudioStreamOGGVorbis.new()
func load_ogg(name: String) -> AudioStreamOGGVorbis:
	# Searches through all of the paths to find the file
	match find_file(name):
		'': return fallback_audiostream
		var filename: return direct_load_ogg(filename)

var fallback_videostream = VideoStreamWebm.new()
func load_video(name: String):
	match find_file(name):
		'': return fallback_videostream
		var filename:
			return load(filename)
	#		var videostream = VideoStreamGDNative.new()
	#		videostream.set_file(filename1)
	#		return videostream

func direct_load_image(filename: String) -> ImageTexture:
	var tex := ImageTexture.new()
	var img := Image.new()
	img.load(filename)
	tex.create_from_image(img)
	return tex

var fallback_texture := ImageTexture.new()
func load_image(name: String) -> ImageTexture:
	var filename = find_file(name)
	if filename != '':
		return direct_load_image(filename)
	print('File not found: ', name)
	return fallback_texture


func init_directory(directory: String):
	var dir = Directory.new()
	var err = dir.make_dir_recursive(directory)
	if err != OK:
		print('An error occurred while trying to create the scores directory: ', err, ERROR_CODES[err])
	return err

func save_json(filename: String, data: Dictionary):
	filename = userroot + filename
	var dir = filename.rsplit('/', true, 1)[0]
	match FileLoader.init_directory(dir):
		OK:
			pass
		var err:
			print_debug('Error making directory for JSON file: ', err, ERROR_CODES[err])
			return err
	var json = JSON.print(data)
	var file = File.new()
	match file.open(filename, File.WRITE):
		OK:
			file.store_string(json)
			file.close()
			return OK
		var err:
			print_debug('Error saving JSON file: ', err, ERROR_CODES[err])
			return err

func load_json(filename: String):
	var file = File.new()
	var err
	for root in PATHS:
		var filename1 = root + filename
		if file.file_exists(filename1):
			err = file.open(filename1, File.READ)
			if err != OK:
				print('An error occurred while trying to open file: ', filename1, err, ERROR_CODES[err])
				continue  # return err
			var result_json = JSON.parse(file.get_as_text())
			file.close()
			if result_json.error != OK:
				print('Error: ', result_json.error)
				print('Error Line: ', result_json.error_line)
				print('Error String: ', result_json.error_string)
				return result_json.error
			return result_json.result
	print('File not found in any libraries: ', filename)
	return ERR_FILE_NOT_FOUND
