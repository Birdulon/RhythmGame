#extends Object
extends Node

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
		var notes = []
		var beats_per_measure := 4
		var length = file.get_len()
		var slide_idxs = {}
		while (file.get_position() < (length-2)):
			var noteline = file.get_csv_line()
			var time_hit := (float(noteline[0]) + (float(noteline[1]))-1.0) * beats_per_measure
			var duration := float(noteline[2]) * beats_per_measure
			var column := int(noteline[3])
			var id := int(noteline[4])
			var id2 := int(noteline[5])
			var id3 := int(noteline[6])

			match id:
				ID_HOLD:
					notes.push_back(Note.make_hold(time_hit, duration, column))
				ID_BREAK:
					notes.push_back(Note.make_break(time_hit, column))
				ID_SLIDE_END:
					# id2 is slide ID
					if id2 in slide_idxs:
						notes[slide_idxs[id2]].column_release = column
						notes[slide_idxs[id2]].update_slide_variables()
				_:
					if id2 == 0:
						notes.push_back(Note.make_tap(time_hit, column))
					else:
						# id2 is slide ID, id3 is slide pattern
						# In order to properly declare the slide, we need the paired endcap which may not be the next note
						slide_idxs[id2] = len(notes)
						var slide_type = Note.SlideType.CHORD
						match id3:
							ID3_SLIDE_CHORD:
								slide_type = Note.SlideType.CHORD
							ID3_SLIDE_ARC_CW:
								slide_type = Note.SlideType.ARC_CW
							ID3_SLIDE_ARC_ACW:
								slide_type = Note.SlideType.ARC_ACW
							_:
								print("Unknown slide type: ", id3)
						notes.push_back(Note.NoteSlide.new(time_hit, duration, column, -1, slide_type))
		return notes


class SRB:
	static func load_file(filename):
		pass


class Test:
	static func stress_pattern():
		var notes = []
		for bar in range(8):
			notes.push_back(Note.make_hold(bar*4, 1, bar%8))
			for i in range(1, 8):
				notes.push_back(Note.make_tap(bar*4 + (i/2.0), (bar + i)%8))
			notes.push_back(Note.make_tap(bar*4 + (7/2.0), (bar + 3)%8))
		for bar in range(8, 16):
			notes.push_back(Note.make_hold(bar*4, 2, bar%8))
			for i in range(1, 8):
				notes.push_back(Note.make_tap(bar*4 + (i/2.0), (bar + i)%8))
				notes.push_back(Note.make_tap(bar*4 + ((i+0.5)/2.0), (bar + i)%8))
				notes.push_back(Note.make_slide(bar*4 + ((i+1)/2.0), 1, (bar + i)%8, 0))
		for bar in range(16, 24):
			notes.push_back(Note.make_hold(bar*4, 2, bar%8))
			notes.push_back(Note.make_hold(bar*4, 1, (bar+1)%8))
			for i in range(2, 8):
				notes.push_back(Note.make_tap(bar*4 + (i/2.0), (bar + i)%8))
				notes.push_back(Note.make_hold(bar*4 + ((i+1)/2.0), 0.5, (bar + i)%8))
		for bar in range(24, 32):
			notes.push_back(Note.make_hold(bar*4, 1, bar%8))
			for i in range(1, 32):
				notes.push_back(Note.make_tap(bar*4 + (i/8.0), (bar + i)%8))
				if (i%2) > 0:
					notes.push_back(Note.make_tap(bar*4 + (i/8.0), (bar + i + 4)%8))
		for bar in range(32, 48):
			notes.push_back(Note.make_hold(bar*4, 1, bar%8))
			for i in range(1, 32):
				notes.push_back(Note.make_tap(bar*4 + (i/8.0), (bar + i)%8))
				notes.push_back(Note.make_tap(bar*4 + (i/8.0), (bar + i + 3)%8))
		return notes

func load_folder(folder):
	var file = File.new()
	var err = file.open("%s/song.json" % folder, File.READ)
	if err != OK:
		print(err)
		return err
	var result_json = JSON.parse(file.get_as_text())
	file.close()
	if result_json.error != OK:
		print("Error: ", result_json.error)
		print("Error Line: ", result_json.error_line)
		print("Error String: ", result_json.error_string)
		return result_json.error
	var result = result_json.result
	result.directory = folder
	return result