extends Node
# In case things need to be tested without a library

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
