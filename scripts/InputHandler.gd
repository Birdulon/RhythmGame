extends Control

var buttons_pressed := PoolByteArray()
var touchbuttons_pressed := PoolByteArray()
signal button_pressed(column)  # Add int type to these once Godot supports typed signals
signal button_released(column)
signal touchbutton_pressed(column)
signal touchbutton_released(column)
signal column_pressed(column)  # This will trigger when either is pressed
signal column_released(column)  # This will trigger when both are released
const TOUCHBUTTON_MIN_DIST := 0.8
const TOUCHBUTTON_MAX_DIST := 1.075
const BUTTON_MIN_DIST := 0.925
const BUTTON_MAX_DIST := 1.25

func _ready():
	$'/root/main/TouchInput'.connect('touch_positions_updated', self, '_check_buttons')

func _init():
	buttons_pressed.resize(Rules.COLS)
	touchbuttons_pressed.resize(Rules.COLS)
	for i in Rules.COLS:
		buttons_pressed[i] = 0
		touchbuttons_pressed[i] = 0
	connect('button_pressed', self, '_on_button_pressed')
	connect('touchbutton_pressed', self, '_on_button_pressed')
	connect('button_released', self, '_on_button_released')
	connect('touchbutton_released', self, '_on_touchbutton_released')

func print_pressed(col: int):
	print('Pressed %d'%col)

func _check_buttons(touch_positions):
	var buttons_pressed_temp := []
	var touchbuttons_pressed_temp := []
	for i in Rules.COLS:
		buttons_pressed_temp.append(false)
		touchbuttons_pressed_temp.append(false)

	var global_center = rect_global_position + rect_size*0.5
	for pos in touch_positions:
		pos -= global_center
		pos /= rect_size.x * 0.5
		var pol = cartesian2polar(pos.x, pos.y)
		var dist = pol.x/GameTheme.receptor_ring_radius_normalized
		var angle = rad2deg(pol.y)
		if dist < TOUCHBUTTON_MIN_DIST:  # Short circuit out to save some logic
			continue
		# bin the angle
		angle -= Rules.FIRST_COLUMN_ANGLE_DEG - Rules.COLS_TOUCH_ARC_DEG/2.0
		if fmod(angle, Rules.COLS_ANGLE_DEG) > Rules.COLS_TOUCH_ARC_DEG:
			continue
		var col := int(floor(angle/Rules.COLS_ANGLE_DEG))
		touchbuttons_pressed_temp[col] = touchbuttons_pressed_temp[col] or (dist < TOUCHBUTTON_MAX_DIST)  # min dist already checked
		buttons_pressed_temp[col] = buttons_pressed_temp[col] or (dist >= BUTTON_MIN_DIST) and (dist < BUTTON_MAX_DIST)

	for i in Rules.COLS:
		set_button_state(i, buttons_pressed_temp[i])
		set_touchbutton_state(i, touchbuttons_pressed_temp[i])

func set_button_state(index: int, state: bool):
	var new_state = int(state)
	match new_state - buttons_pressed[index]:
		1:
			emit_signal('button_pressed', index)
		-1:
			emit_signal('button_released', index)
	buttons_pressed[index] = new_state

func set_touchbutton_state(index: int, state: bool):
	var new_state = int(state)
	match new_state - touchbuttons_pressed[index]:
		1:
			emit_signal('touchbutton_pressed', index)
		-1:
			emit_signal('touchbutton_released', index)
	touchbuttons_pressed[index] = new_state

func _on_button_pressed(column: int):
	emit_signal('column_pressed', column)

func _on_button_released(column: int):
	if touchbuttons_pressed[column] == 0:
		emit_signal('column_released', column)

func _on_touchbutton_released(column: int):
	if buttons_pressed[column] == 0:
		emit_signal('column_released', column)
