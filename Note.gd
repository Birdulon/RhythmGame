#extends Object
extends Node

#class_name Note

enum {NOTE_TAP, NOTE_HOLD, NOTE_SLIDE, NOTE_ARROW, NOTE_TOUCH, NOTE_TOUCH_HOLD}
enum SlideType {CHORD, ARC_CW, ARC_ACW}
const DEATH_DELAY := 0.45

static func make_tap(time_hit: float, column: int) -> Dictionary:
	return {type=NOTE_TAP, time_hit=time_hit, time_death=time_hit+DEATH_DELAY, column=column, double_hit=false}

static func make_break(time_hit: float, column: int) -> Dictionary:
	return {type=NOTE_TAP, time_hit=time_hit, time_death=time_hit+DEATH_DELAY, column=column, double_hit=false}

static func make_hold(time_hit: float, duration: float, column: int) -> Dictionary:
	var time_release := time_hit + duration
	return {type=NOTE_HOLD, time_hit=time_hit, time_release=time_release, time_death=time_release+DEATH_DELAY, column=column, double_hit=false}

static func make_slide(time_hit: float, duration: float, column: int, column_release: int) -> Dictionary:
	var time_release := time_hit + duration
	return {type=NOTE_SLIDE, time_hit=time_hit, time_release=time_release, duration=duration,
			time_death=time_release+DEATH_DELAY, column=column, column_release=column_release, double_hit=false}

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
