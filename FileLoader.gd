#extends Object
extends Node

class SRT:
	const TAP_DURATION := 0.062500
	const ID_BREAK := 4
	const ID_HOLD := 2
	const ID_SLIDE_END := 128

	static func load_file(filename):
		var file = File.new()
		var err = file.open(filename, File.READ)
		if err != OK:
			print(err)
			return err
		var notes = []
		var beats_per_measure := 4
		var length = file.get_len()
		while (file.get_position() < (length-2)):
			var noteline = file.get_csv_line()
			var time_hit := (float(noteline[0]) + float(noteline[1])) * beats_per_measure
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
					pass  # id2 is slide ID
				_:
					if id2 == 0:
						notes.push_back(Note.make_tap(time_hit, column))
					else:
						# id2 is slide ID, id3 is slide pattern
						# In order to properly declare the slide, we need the paired endcap which may not be the next note
						notes.push_back(Note.make_slide(time_hit, duration, column, column))
		return notes

class SRB:
	func load_file(filename):
		pass
