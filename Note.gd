#extends Object
extends Node

#class_name Note

enum {NOTE_TAP, NOTE_HOLD, NOTE_SLIDE, NOTE_ARROW, NOTE_TOUCH, NOTE_TOUCH_HOLD, NOTE_ROLL}
enum SlideType {CHORD, ARC_CW, ARC_ACW}
const DEATH_DELAY := 1.0  # This is touchy with the judgement windows and variable bpm.
const RELEASE_SCORE_TYPES := [NOTE_HOLD, NOTE_SLIDE, NOTE_TOUCH_HOLD, NOTE_ROLL]

class NoteBase:
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

class NoteTap extends NoteBase:
	var type := NOTE_TAP
	func _init(time_hit: float, column: int, is_break:=false):
		self.time_hit = time_hit
		self.column = column
		self.is_break = is_break

class NoteHoldBase extends NoteBase:
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

class NoteSlide extends NoteBase:
	var type := NOTE_SLIDE
	var time_release: float setget set_time_release
	var duration: float setget set_duration
	var column_release: int
	var slide_type: int
	var slide_id: int
	var progress := INF
	var missed_slide := false
	var values: Dictionary

	func _init(time_hit: float, column: int, duration: float, column_release: int, slide_type: int):
		self.time_hit = time_hit
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
			Note.SlideType.CHORD:
				values.start = GameTheme.RADIAL_UNIT_VECTORS[column] * GameTheme.receptor_ring_radius
				values.end = GameTheme.RADIAL_UNIT_VECTORS[column_release] * GameTheme.receptor_ring_radius
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

	func get_position(progress: float) -> Vector2:
		match slide_type:
			Note.SlideType.CHORD:
				return lerp(values.start, values.end, progress)
			Note.SlideType.ARC_CW:
				var circle_angle : float = lerp(values.start_a, values.end_a, progress)
				return polar2cartesian(GameTheme.receptor_ring_radius, circle_angle)
			Note.SlideType.ARC_ACW:
				var circle_angle : float = lerp(values.start_a, values.end_a, progress)
				return polar2cartesian(GameTheme.receptor_ring_radius, circle_angle)
		return Vector2(0.0, 0.0)

	func get_angle(progress: float) -> float:
		match slide_type:
			Note.SlideType.CHORD:
				return values.angle
			Note.SlideType.ARC_CW:
				var circle_angle : float = lerp(values.start_a, values.end_a, progress)
				return circle_angle + PI/2.0
			Note.SlideType.ARC_ACW:
				var circle_angle : float = lerp(values.start_a, values.end_a, progress)
				return circle_angle - PI/2.0
		return 0.0

	func get_slide_length() -> float:
		# Return unit-circle (r=1) length of slide trail
		match slide_type:
			Note.SlideType.CHORD:
				return 2*abs(sin((GameTheme.RADIAL_COL_ANGLES[column_release] - GameTheme.RADIAL_COL_ANGLES[column])/2))
			Note.SlideType.ARC_CW:
				return fposmod(GameTheme.RADIAL_COL_ANGLES[column_release] - GameTheme.RADIAL_COL_ANGLES[column], TAU)
			Note.SlideType.ARC_ACW:
				return fposmod(GameTheme.RADIAL_COL_ANGLES[column] - GameTheme.RADIAL_COL_ANGLES[column_release], TAU)
		return 0.0


static func make_slide(time_hit: float, duration: float, column: int, column_release: int, slide_type:=SlideType.CHORD) -> NoteSlide:
	return NoteSlide.new(time_hit, column, duration, column_release, slide_type)

static func make_touch(time_hit: float, location: Vector2) -> Dictionary:
	return {type=NOTE_TOUCH, time_hit=time_hit, time_death=time_hit+DEATH_DELAY, location=location, double_hit=false}

static func make_touch_hold(time_hit: float, duration: float, location: Vector2) -> Dictionary:
	var time_release := time_hit + duration
	return {type=NOTE_TOUCH_HOLD, time_hit=time_hit, time_release=time_release, time_death=time_release+DEATH_DELAY, location=location, double_hit=false}

static func process_note_list(note_array: Array):
	# Preprocess double hits, assign Slide IDs
	# If this were performance-critical, we'd single iterate it
	# It's not though, so we lay it out simply
	var slide_id := 0
	if len(note_array):
		# Doubles
		for i in len(note_array)-1:
			if note_array[i].time_hit == note_array[i+1].time_hit:
				note_array[i].double_hit = true
				note_array[i+1].double_hit = true
		# Slides
		for i in len(note_array):
			if note_array[i].type == NOTE_SLIDE:
				note_array[i].slide_id = slide_id
				slide_id += 1

