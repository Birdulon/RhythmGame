#extends Object
extends Node

#class_name Note

enum {NOTE_TAP, NOTE_HOLD, NOTE_STAR=2, NOTE_SLIDE=-2, NOTE_TOUCH=3, NOTE_TOUCH_HOLD=4, NOTE_ARROW, NOTE_ROLL}
enum SlideType {CHORD, ARC_CW, ARC_ACW, CHORD_TRIPLE, COMPLEX}
const DEATH_DELAY := 1.0  # This is touchy with the judgement windows and variable bpm.
const RELEASE_SCORE_TYPES := {
	NOTE_HOLD: -NOTE_HOLD,
	NOTE_SLIDE: NOTE_SLIDE,
	NOTE_TOUCH_HOLD: -NOTE_TOUCH_HOLD,
	NOTE_ROLL: -NOTE_ROLL
}

class NoteBase extends Resource:
	var time_hit: float setget set_time_hit
	var time_death: float
	var column: int
	var double_hit := false
	var time_activated := INF
	var missed := false
	var is_break := false

	func set_time_hit(value: float):
		time_hit = value
		time_death = time_hit + DEATH_DELAY

class NoteHittableBase extends NoteBase:
	const hittable := true

class NoteTapBase extends NoteHittableBase:
	func _init(time_hit: float, column: int, is_break:=false):
		self.time_hit = time_hit
		self.column = column
		self.is_break = is_break

class NoteTap extends NoteTapBase:
	var type := NOTE_TAP
	func _init(time_hit: float, column: int, is_break:=false).(time_hit, column, is_break):
		pass

class NoteStar extends NoteTapBase:  # Fancy charts have naked slides which necessitates separation of Star and Slide :(
	var type := NOTE_STAR
	var duration := 1.0  # This is required for the spin speed
	func _init(time_hit: float, column: int, is_break:=false).(time_hit, column, is_break):
		pass

class NoteHoldBase extends NoteHittableBase:
	var time_release: float setget set_time_release
	var time_released := INF
	var duration: float setget set_duration
	var is_held: bool
	func _init(time_hit: float, column: int, duration: float):
		self.time_hit = time_hit
		self.column = column
		self.duration = duration
		self.is_held = false

	func set_time_hit(value: float):
		time_hit = value
		time_release = time_hit + duration
		time_death = time_release + DEATH_DELAY

	func set_time_release(value: float):
		time_release = value
		time_death = time_release + DEATH_DELAY
		duration = time_release - time_hit

	func set_duration(value: float):
		duration = value
		time_release = time_hit + duration
		time_death = time_release + DEATH_DELAY

class NoteHold extends NoteHoldBase:
	var type := NOTE_HOLD
	func _init(time_hit: float, column: int, duration: float).(time_hit, column, duration):
		pass

class NoteRoll extends NoteHoldBase:
	var type := NOTE_ROLL
	func _init(time_hit: float, column: int, duration: float).(time_hit, column, duration):
		pass

class NoteSlide extends NoteBase:  # Fancy charts have naked slides which necessitates separation of Star and Slide :(
	const hittable := false
	var type := NOTE_SLIDE
	var time_release: float setget set_time_release
	var duration: float setget set_duration
	var column_release: int
	var slide_type: int
	var slide_id: int
	var progress := INF
	var missed_slide := false
	var values: Dictionary

	func _init(time_hit: float, column: int, duration:=0.0, column_release:=0, slide_type:=0):
		self.time_hit = time_hit  # The hit doesn't actually count for anything
		self.column = column
		self.duration = duration
		self.time_release = time_hit + duration
		self.time_death = time_release + DEATH_DELAY
		self.column_release = column_release
		self.slide_type = slide_type
		self.values = {}
		update_slide_variables()

	func set_time_hit(value: float):
		time_hit = value
		time_release = time_hit + duration
		time_death = time_release + DEATH_DELAY

	func set_time_release(value: float):
		time_release = value
		time_death = time_release + DEATH_DELAY
		duration = time_release - time_hit

	func set_duration(value: float):
		duration = value
		time_release = time_hit + duration
		time_death = time_release + DEATH_DELAY

	func update_slide_variables():
		match slide_type:
			Note.SlideType.CHORD, Note.SlideType.CHORD_TRIPLE:
				values.start = GameTheme.RADIAL_UNIT_VECTORS[column]
				values.end = GameTheme.RADIAL_UNIT_VECTORS[column_release]
				values.angle = (values.end - values.start).angle()
			Note.SlideType.ARC_CW:
				values.start_a = GameTheme.RADIAL_COL_ANGLES[column]
				values.end_a = GameTheme.RADIAL_COL_ANGLES[column_release]
				if values.end_a < values.start_a:
					values.end_a += TAU
			Note.SlideType.ARC_ACW:
				values.start_a = GameTheme.RADIAL_COL_ANGLES[column]
				values.end_a = GameTheme.RADIAL_COL_ANGLES[column_release]
				if values.end_a > values.start_a:
					values.end_a -= TAU
			Note.SlideType.COMPLEX:
				values.curve2d = Curve2D.new()
				values.curve2d.bake_interval = 0.1  # TODO: play around with this

	func get_position(progress: float) -> Vector2:
		match slide_type:
			Note.SlideType.CHORD, Note.SlideType.CHORD_TRIPLE:
				return lerp(values.start, values.end, progress)
			Note.SlideType.ARC_CW, Note.SlideType.ARC_ACW:
				var circle_angle : float = lerp(values.start_a, values.end_a, progress)
				return polar2cartesian(1.0, circle_angle)
			Note.SlideType.COMPLEX:
				progress *= values.curve2d.get_baked_length()
				return values.curve2d.interpolate_baked(progress)
		return Vector2(0.0, 0.0)

	func get_points(per_radius: float = 10.0) -> Array:
		# Returns PoolVector2Array positions, PoolRealArray angles
		match slide_type:
			Note.SlideType.COMPLEX:
				var interval = 1.0/per_radius
				if values.curve2d.bake_interval != interval:
					values.curve2d.set_bake_interval(interval)  # Setting this, even to the same value triggers a new bake
				var positions: PoolVector2Array = values.curve2d.get_baked_points()
				var angles = []
				for i in len(positions)-1:
					angles.append((positions[i+1]-positions[i]).angle())
				positions.remove(0)  # Don't need an arrow pointing at the start position
				return [positions, PoolRealArray(angles)]
			_:
				var trail_length : int = int(floor(get_slide_length() * per_radius))
				var angles = []
				var positions = []
				for i in trail_length:
					angles.append(get_angle((i+1)/float(trail_length)))
					positions.append(get_position((i+1)/float(trail_length)))
				return [PoolVector2Array(positions), PoolRealArray(angles)]

	func get_angle(progress: float) -> float:
		match slide_type:
			Note.SlideType.CHORD, Note.SlideType.CHORD_TRIPLE:
				return values.angle
			Note.SlideType.ARC_CW:
				var circle_angle : float = lerp(values.start_a, values.end_a, progress)
				return circle_angle + PI/2.0
			Note.SlideType.ARC_ACW:
				var circle_angle : float = lerp(values.start_a, values.end_a, progress)
				return circle_angle - PI/2.0
			Note.SlideType.COMPLEX:
				# TODO: get a better tangent maybe?
				progress = clamp(progress, 0.001, 0.999)  # Yes this is scuffed
				var l = values.curve2d.get_baked_length()
				return (values.curve2d.interpolate_baked((progress+0.001)*l) - values.curve2d.interpolate_baked((progress-0.001)*l)).angle()
		return 0.0

	func get_slide_length() -> float:
		# Return unit-circle (r=1) length of slide trail
		match slide_type:
			Note.SlideType.CHORD, Note.SlideType.CHORD_TRIPLE:
				return 2*abs(sin((GameTheme.RADIAL_COL_ANGLES[column_release] - GameTheme.RADIAL_COL_ANGLES[column])/2))
			Note.SlideType.ARC_CW:
				return fposmod(GameTheme.RADIAL_COL_ANGLES[column_release] - GameTheme.RADIAL_COL_ANGLES[column], TAU)
			Note.SlideType.ARC_ACW:
				return fposmod(GameTheme.RADIAL_COL_ANGLES[column] - GameTheme.RADIAL_COL_ANGLES[column_release], TAU)
			Note.SlideType.COMPLEX:
				return values.curve2d.get_baked_length()
		return 0.0

static func copy_note(note: NoteBase):
	# Honestly disappointed I couldn't find a better, more OOP solution for this.
	var newnote: NoteBase
	match note.type:
		NOTE_TAP:
			newnote = NoteTap.new(note.time_hit, note.column, note.is_break)
		NOTE_STAR:
			newnote = NoteStar.new(note.time_hit, note.column, note.is_break)
		NOTE_HOLD:
			newnote = NoteHold.new(note.time_hit, note.column, note.duration)
		NOTE_SLIDE:
			newnote = NoteSlide.new(note.time_hit, note.column, note.duration, note.column_release, note.slide_type)
			if note.slide_type == Note.SlideType.COMPLEX:
				newnote.values.curve2d = note.values.curve2d
		NOTE_ROLL:
			newnote = NoteRoll.new(note.time_hit, note.column, note.duration)
	newnote.double_hit = note.double_hit
	return newnote

static func make_slide(time_hit: float, duration: float, column: int, column_release: int, slide_type:=SlideType.CHORD) -> NoteSlide:
	return NoteSlide.new(time_hit, column, duration, column_release, slide_type)

static func make_touch(time_hit: float, location: Vector2) -> Dictionary:
	return {type=NOTE_TOUCH, time_hit=time_hit, time_death=time_hit+DEATH_DELAY, location=location, double_hit=false}

static func make_touch_hold(time_hit: float, duration: float, location: Vector2) -> Dictionary:
	var time_release := time_hit + duration
	return {type=NOTE_TOUCH_HOLD, time_hit=time_hit, time_release=time_release, time_death=time_release+DEATH_DELAY, location=location, double_hit=false}

static func process_note_list(note_array: Array, check_doubles:=true):
	# Preprocess double hits, assign Slide IDs
	# If this were performance-critical, we'd single iterate it
	# It's not though, so we lay it out simply
	var slide_id := 0
	if len(note_array):
		# Doubles
		if check_doubles:
			for i in len(note_array)-1:
				var note1 = note_array[i]
				if not note1.hittable:
					continue
				for j in len(note_array)-1-i:
					var note2 = note_array[i+j+1]
					if not note2.hittable:
						continue
					if note1.time_hit == note2.time_hit:
						note1.double_hit = true
						note2.double_hit = true
					else:
						break
		# Slides
		for i in len(note_array):
			if note_array[i].type == NOTE_SLIDE:
				note_array[i].slide_id = slide_id
				slide_id += 1

