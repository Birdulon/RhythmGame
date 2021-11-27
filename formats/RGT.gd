extends Node
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
