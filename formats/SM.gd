extends Node
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
	metadata['notes'] = notes
	return metadata


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
