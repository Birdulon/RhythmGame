extends Node

var receptor_ring_radius := 460.0
var note_forecast_beats := 2.0  # Notes start to appear this many beats before you need to tap them
const INNER_NOTE_CIRCLE_RATIO := 0.3  # Notes under this far from the center will zoom into existence
const SLIDE_DELAY := 0.5  # Time in beats between the tap of the star and the start of the visual slide

var sprite_size := 128
var sprite_size2 := sprite_size/2

var judge_text_size := 256
# Text is rendered from center.
const JUDGE_TEXT_ANG2 := atan(1.0/4.0)
const JUDGE_TEXT_ANG1 := PI - JUDGE_TEXT_ANG2
const JUDGE_TEXT_ANG3 := PI + JUDGE_TEXT_ANG2
const JUDGE_TEXT_ANG4 := -JUDGE_TEXT_ANG2
var judge_text_size2 := 0.5*judge_text_size/cos(JUDGE_TEXT_ANG2)

# Color definitions
const COLOR_TAP := Color(1, 0.15, 0.15, 1)
const COLOR_TAP2 := Color(0.75, 0.5, 0, 1)  # High-score taps ("breaks" in maimai)
const COLOR_HOLD := Color(1, 0.15, 0.15, 1)
const COLOR_HOLD_HELD := Color(1, 1, 1, 1)
const COLOR_STAR := Color(0, 0, 1, 1)
const COLOR_DOUBLE := Color(1, 1, 0, 1)  # When two (or more in master) hit events coincide
const COLOR_TEXT := Color(1, 1, 1, 1)

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

var screen_filter := Color(0.0, 0.0, 0.0, 0.2)
var receptor_color := Color.blue
var bezel_color := Color.black

var RADIAL_COL_ANGLES := PoolRealArray()  # ideally const
var RADIAL_UNIT_VECTORS := PoolVector2Array()  # ideally const

func init_radial_values():
	for i in range(Rules.COLS):
		var angle = deg2rad(fmod(Rules.FIRST_COLUMN_ANGLE_DEG + (i * Rules.COLS_ANGLE_DEG), 360.0))
		RADIAL_COL_ANGLES.push_back(angle)
		RADIAL_UNIT_VECTORS.push_back(Vector2(cos(angle), sin(angle)))


func color_array_text(alpha: float) -> PoolColorArray:
	var color := Color(COLOR_TEXT.r, COLOR_TEXT.g, COLOR_TEXT.b, alpha)
	return PoolColorArray([color, color, color, color])
