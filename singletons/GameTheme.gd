tool
extends Node

var tex_notes := preload('res://assets/spritesheet-2048.png')
var tex_judgement_text := preload('res://assets/text-4k.png')
var tex_slide_arrow := tex_notes
var slide_trail_shadermaterial := preload('res://shaders/slidetrail.tres')

var snd_miss := preload('res://assets/miss.wav')
var snd_clap := preload('res://assets/softclap.wav')
var snd_count_in := snd_clap
var snd_judgement := {
	0: snd_clap,
	1: snd_clap,
	-1: snd_clap,
	2: snd_clap,
	-2: snd_clap,
	3: snd_miss,
	-3: snd_miss,
	'MISS': snd_miss
}
var db_judgement := {
	0: 0.0,
	1: -1.5,
	-1: -1.5,
	2: -3.0,
	-2: -3.0,
	3: -6.0,
	-3: -6.0,
	'MISS': 0.0
}
var pitch_judgement := {
	0: 1.0,
	-1: 1.0/0.75,
	1: 0.75,
	-2: 1.0/0.60,
	2: 0.60,
	-3: 1.5,
	3: 1.5,
	'MISS': 1.0
}

var receptor_ring_radius := 460.0
var note_forecast_beats := 2.0  # Notes start to appear this many beats before you need to tap them
const INNER_NOTE_CIRCLE_RATIO := 0.3  # Notes under this far from the center will zoom into existence
const SLIDE_DELAY := 0.5  #0.125  #0.5  # Time in beats between the tap of the star and the start of the visual slide

var sprite_size := 128
var sprite_size2 := sprite_size/2

var judge_text_size := 256
# Text is rendered from center.
const JUDGE_TEXT_ANG2 := atan(1.0/4.0)
const JUDGE_TEXT_ANG1 := PI - JUDGE_TEXT_ANG2
const JUDGE_TEXT_ANG3 := PI + JUDGE_TEXT_ANG2
const JUDGE_TEXT_ANG4 := -JUDGE_TEXT_ANG2
var judge_text_size2 := 0.5*judge_text_size/cos(JUDGE_TEXT_ANG2)

var judge_text_duration := 2.0


# UV vertex arrays for our sprites
# tap/star/arrow are 4-vertex 2-triangle simple squares
# hold is 8-vertex 6-triangle to enable stretching in the middle
const TNSZ := 4;
const UV_ARRAY_TAP := PoolVector2Array([Vector2(0, 0)/TNSZ, Vector2(1, 0)/TNSZ, Vector2(0, 1)/TNSZ, Vector2(1, 1)/TNSZ])
const UV_ARRAY_HOLD := PoolVector2Array([
	Vector2(1, 0)/TNSZ, Vector2(2, 0)/TNSZ, Vector2(1, 0.5)/TNSZ, Vector2(2, 0.5)/TNSZ,
	Vector2(1, 0.5)/TNSZ, Vector2(2, 0.5)/TNSZ, Vector2(1, 1)/TNSZ, Vector2(2, 1)/TNSZ
	])
const UV_ARRAY_STAR := PoolVector2Array([Vector2(2, 0)/TNSZ, Vector2(3, 0)/TNSZ, Vector2(2, 1)/TNSZ, Vector2(3, 1)/TNSZ])
const UV_ARRAY_ARROW := PoolVector2Array([Vector2(0, 1)/TNSZ, Vector2(1, 1)/TNSZ, Vector2(0, 2)/TNSZ, Vector2(1, 2)/TNSZ])
# Slide trail arrow. Single tri.
const UV_ARRAY_SLIDE_ARROW := PoolVector2Array([Vector2(3, 0)/TNSZ, Vector2(4, 0)/TNSZ, Vector2(3, 1)/TNSZ])
const UV_ARRAY_SLIDE_ARROW2 := PoolVector2Array([Vector2(4, 1)/TNSZ, Vector2(3, 1)/TNSZ, Vector2(4, 0)/TNSZ])

# Dance mode
const UV_ARRAY_D_ARROW := PoolVector2Array([Vector2(0, 2)/TNSZ, Vector2(1, 2)/TNSZ, Vector2(0, 3)/TNSZ, Vector2(1, 3)/TNSZ])
const UV_ARRAY_D_RECEPTOR := PoolVector2Array([Vector2(0, 3)/TNSZ, Vector2(1, 3)/TNSZ, Vector2(0, 4)/TNSZ, Vector2(1, 4)/TNSZ])
const UV_ARRAY_D_HOLD := PoolVector2Array([
	Vector2(1, 1)/TNSZ, Vector2(2, 1)/TNSZ, Vector2(1, 1.5)/TNSZ, Vector2(2, 1.5)/TNSZ,
	Vector2(1, 1.5)/TNSZ, Vector2(2, 1.5)/TNSZ, Vector2(1, 2)/TNSZ, Vector2(2, 2)/TNSZ
	])
const UV_ARRAY_D_ROLL := PoolVector2Array([
	Vector2(2, 1)/TNSZ, Vector2(3, 1)/TNSZ, Vector2(2, 1.5)/TNSZ, Vector2(3, 1.5)/TNSZ,
	Vector2(2, 1.5)/TNSZ, Vector2(3, 1.5)/TNSZ, Vector2(2, 2)/TNSZ, Vector2(3, 2)/TNSZ
	])

# Color definitions
const COLOR_MENU_TEXT = Color(0.95, 0.95, 1.0)

const COLOR_TAP := Color(1, 0.15, 0.15, 1)
const COLOR_TAP2 := Color(0.75, 0.5, 0, 1)  # High-score taps ("breaks" in maimai)
const COLOR_HOLD := Color(1, 0.15, 0.15, 1)
const COLOR_HOLD_HELD := Color(1, 1, 1, 1)
const COLOR_HOLD_MISS := Color(0.33, 0.05, 0.05, 1)
const COLOR_STAR := Color(0, 0, 1, 1)
const COLOR_DOUBLE := Color(1, 1, 0, 1)  # When two (or more in master) hit events coincide
const COLOR_DOUBLE_MISS := Color(0.33, 0.33, 0, 1)
const COLOR_TEXT := Color(1, 1, 1, 1)
const COLOR_SLIDE := Color(0.65, 0.65, 1.0, 1.0)
const COLOR_DOUBLE_SLIDE := Color(1.0, 1.0, 0.35, 1.0)

const COLOR_DIFFICULTY := PoolColorArray([  # Background, foreground for each
	Color(0.435, 0.333, 1.000), Color.white,
	Color(0.150, 1.000, 0.275), Color.white,
	Color(0.973, 0.718, 0.039), Color.white,
	Color(1.000, 0.150, 0.150), Color.white,
	Color(0.761, 0.271, 0.902), Color.white,
	Color(1.0, 1.0, 1.0), Color(0.737, 0.188, 0.894),
	Color(0.000, 0.000, 1.000), Color.white,
])

const COLOR_ARRAY_TAP := PoolColorArray([COLOR_TAP, COLOR_TAP, COLOR_TAP, COLOR_TAP])
const COLOR_ARRAY_TAP2 := PoolColorArray([COLOR_TAP2, COLOR_TAP2, COLOR_TAP2, COLOR_TAP2])
const COLOR_ARRAY_HOLD := PoolColorArray([
	COLOR_HOLD, COLOR_HOLD, COLOR_HOLD, COLOR_HOLD,
	COLOR_HOLD, COLOR_HOLD, COLOR_HOLD, COLOR_HOLD
	])
const COLOR_ARRAY_HOLD_HELD := PoolColorArray([
	COLOR_HOLD_HELD, COLOR_HOLD_HELD, COLOR_HOLD_HELD, COLOR_HOLD_HELD,
	COLOR_HOLD_HELD, COLOR_HOLD_HELD, COLOR_HOLD_HELD, COLOR_HOLD_HELD
	])
const COLOR_ARRAY_HOLD_MISS := PoolColorArray([
	COLOR_HOLD_MISS, COLOR_HOLD_MISS, COLOR_HOLD_MISS, COLOR_HOLD_MISS,
	COLOR_HOLD_MISS, COLOR_HOLD_MISS, COLOR_HOLD_MISS, COLOR_HOLD_MISS
	])
const COLOR_ARRAY_STAR := PoolColorArray([COLOR_STAR, COLOR_STAR, COLOR_STAR, COLOR_STAR])
const COLOR_ARRAY_DOUBLE_4 := PoolColorArray([COLOR_DOUBLE, COLOR_DOUBLE, COLOR_DOUBLE, COLOR_DOUBLE])
const COLOR_ARRAY_DOUBLE_8 := PoolColorArray([
	COLOR_DOUBLE, COLOR_DOUBLE, COLOR_DOUBLE, COLOR_DOUBLE,
	COLOR_DOUBLE, COLOR_DOUBLE, COLOR_DOUBLE, COLOR_DOUBLE
	])
const COLOR_ARRAY_DOUBLE_MISS_4 := PoolColorArray([COLOR_DOUBLE_MISS, COLOR_DOUBLE_MISS, COLOR_DOUBLE_MISS, COLOR_DOUBLE_MISS])
const COLOR_ARRAY_DOUBLE_MISS_8 := PoolColorArray([
	COLOR_DOUBLE_MISS, COLOR_DOUBLE_MISS, COLOR_DOUBLE_MISS, COLOR_DOUBLE_MISS,
	COLOR_DOUBLE_MISS, COLOR_DOUBLE_MISS, COLOR_DOUBLE_MISS, COLOR_DOUBLE_MISS
	])

# Normal vertex arrays for our sprites. Might be unnecessary?
const DEFAULT_NORMAL := Vector3(0, 0, 1)
const NORMAL_ARRAY_4 := PoolVector3Array([DEFAULT_NORMAL, DEFAULT_NORMAL, DEFAULT_NORMAL, DEFAULT_NORMAL])
const NORMAL_ARRAY_8 := PoolVector3Array([
	DEFAULT_NORMAL, DEFAULT_NORMAL, DEFAULT_NORMAL, DEFAULT_NORMAL,
	DEFAULT_NORMAL, DEFAULT_NORMAL, DEFAULT_NORMAL, DEFAULT_NORMAL
	])

var display_language = 'n'

var screen_filter_min_alpha := 0.2
var screen_filter := Color(0.0, 0.0, 0.0, screen_filter_min_alpha)
signal screen_filter_changed()
var receptor_color := Color.blue
var bezel_color := Color.black if not Engine.editor_hint else Color.red

var slide_trail_alpha := 0.88

var RADIAL_COL_ANGLES := PoolRealArray()  # ideally const
var RADIAL_UNIT_VECTORS := PoolVector2Array()  # ideally const

func set_screen_filter_alpha(alpha: float):
	# Scale to minimum alpha
	var new_alpha = lerp(screen_filter_min_alpha, 1.0, alpha)
	if new_alpha != screen_filter.a:
		screen_filter = Color(screen_filter.r, screen_filter.g, screen_filter.b, new_alpha)
		emit_signal("screen_filter_changed")

var radial_values_initialized := false
func init_radial_values():
	for i in range(Rules.COLS):
		var angle = deg2rad(fposmod(Rules.FIRST_COLUMN_ANGLE_DEG + (i * Rules.COLS_ANGLE_DEG), 360.0))
		RADIAL_COL_ANGLES.push_back(angle)
		RADIAL_UNIT_VECTORS.push_back(Vector2(cos(angle), sin(angle)))
	radial_values_initialized = true


func color_array_text(alpha: float) -> PoolColorArray:
	var color := Color(COLOR_TEXT.r, COLOR_TEXT.g, COLOR_TEXT.b, alpha)
	return PoolColorArray([color, color, color, color])

func color_array_tap(alpha: float, double:=false) -> PoolColorArray:
	if alpha >= 1.0:
		return COLOR_ARRAY_DOUBLE_4 if double else COLOR_ARRAY_TAP
	else:
		var col := COLOR_DOUBLE if double else COLOR_TAP
		var color = Color(col.r, col.g, col.b, alpha)
		return PoolColorArray([color, color, color, color])

func color_array_star(alpha: float, double:=false) -> PoolColorArray:
	if alpha >= 1.0:
		return COLOR_ARRAY_DOUBLE_4 if double else COLOR_ARRAY_STAR
	else:
		var col := COLOR_DOUBLE if double else COLOR_STAR
		var color = Color(col.r, col.g, col.b, alpha)
		return PoolColorArray([color, color, color, color])
