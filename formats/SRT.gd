extends Node
# A legacy format that is relatively easily parsed. Radial game mode.
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
