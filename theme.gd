extends Node

var receptor_ring_radius := 460
var note_forecast_beats := 2.0  # Notes start to appear this many beats before you need to tap them
const INNER_NOTE_CIRCLE_RATIO := 0.3  # Notes under this far from the center will zoom into existence
const SLIDE_DELAY := 0.5  # Time in beats between the tap of the star and the start of the visual slide

var sprite_size := 128
var sprite_size2 := sprite_size/2

# Color definitions
const COLOR_TAP := Color(1, 0.15, 0.15, 1)
const COLOR_TAP2 := Color(0.75, 0.5, 0, 1)  # High-score taps ("breaks" in maimai)
const COLOR_HOLD := Color(1, 0.15, 0.15, 1)
const COLOR_HOLD_HELD := Color(1, 1, 1, 1)
const COLOR_STAR := Color(0, 0, 1, 1)
const COLOR_DOUBLE := Color(1, 1, 0, 1)  # When two (or more in master) hit events coincide

var COLOR_ARRAY_TAP := PoolColorArray([COLOR_TAP, COLOR_TAP, COLOR_TAP, COLOR_TAP])
var COLOR_ARRAY_TAP2 := PoolColorArray([COLOR_TAP2, COLOR_TAP2, COLOR_TAP2, COLOR_TAP2])
var COLOR_ARRAY_HOLD := PoolColorArray([
	COLOR_HOLD, COLOR_HOLD, COLOR_HOLD, COLOR_HOLD,
	COLOR_HOLD, COLOR_HOLD, COLOR_HOLD, COLOR_HOLD
	])
var COLOR_ARRAY_HOLD_HELD := PoolColorArray([
	COLOR_HOLD_HELD, COLOR_HOLD_HELD, COLOR_HOLD_HELD, COLOR_HOLD_HELD,
	COLOR_HOLD_HELD, COLOR_HOLD_HELD, COLOR_HOLD_HELD, COLOR_HOLD_HELD
	])
var COLOR_ARRAY_STAR := PoolColorArray([COLOR_STAR, COLOR_STAR, COLOR_STAR, COLOR_STAR])
var COLOR_ARRAY_DOUBLE_4 := PoolColorArray([COLOR_DOUBLE, COLOR_DOUBLE, COLOR_DOUBLE, COLOR_DOUBLE])
var COLOR_ARRAY_DOUBLE_8 := PoolColorArray([
	COLOR_DOUBLE, COLOR_DOUBLE, COLOR_DOUBLE, COLOR_DOUBLE,
	COLOR_DOUBLE, COLOR_DOUBLE, COLOR_DOUBLE, COLOR_DOUBLE
	])
