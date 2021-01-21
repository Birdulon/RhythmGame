extends Label

var touch_points = {} 								# dict containing all points touched on the screen
var touch_positions = []							# array of above
var fingers = 0 setget set_fingers					# setter for show fingers number on screen
var txt_ball = preload('res://assets/ball.png')		# preload our ball texture
var default_font = preload('res://assets/NotoSans.tres')

var buttons_pressed := PoolByteArray()
var touchbuttons_pressed := PoolByteArray()
signal button_pressed(index)  # Add int type to these once Godot supports typed signals
signal button_released(index)
signal touchbutton_pressed(index)
signal touchbutton_released(index)
const TOUCHBUTTON_MIN_DIST := 0.8
const TOUCHBUTTON_MAX_DIST := 1.075
const BUTTON_MIN_DIST := 0.925
const BUTTON_MAX_DIST := 1.25

var swipe_momentum := Vector2.ZERO

func resize():
	var screen_size = $'/root'.get_visible_rect().size
	rect_position = -screen_size*0.5
	rect_size = screen_size

func _init():
	buttons_pressed.resize(Rules.COLS)
	touchbuttons_pressed.resize(Rules.COLS)
	for i in Rules.COLS:
		buttons_pressed[i] = 0
		touchbuttons_pressed[i] = 0

func _ready():
	Input.set_use_accumulated_input(false)  # Gotta go fast
	set_process_unhandled_input(true)  # process user input
	set_fingers(0)
#	connect('button_pressed', self, 'print_pressed')
	$'/root'.connect('size_changed', self, 'resize')
	$VsyncButton.connect('toggled', self, 'update_vsync')
	$WakelockButton.connect('toggled', self, 'update_wakelock')
	$FilterSlider.connect('value_changed', self, 'update_filter')
	$VolumeSlider.connect('value_changed', self, 'update_volume')
	$SSXSlider.connect('value_changed', Settings, 'SSX_set')
	$SSYSlider.connect('value_changed', Settings, 'SSY_set')
	$BtnLanguage.add_item('Native')
	$BtnLanguage.add_item('Romaji')
	$BtnLanguage.add_item('English')
	$BtnLanguage.connect('item_selected', self, 'update_display_language')
	resize()

func update_vsync(setting: bool):
	OS.vsync_enabled = setting

func update_wakelock(setting: bool):
	OS.keep_screen_on = setting  # This is waiting on godotengine/godot#35536 to be merged to do anything in Linux :(

func update_filter(alpha: float):
	GameTheme.screen_filter_min_alpha = alpha

func update_volume(volume: float):
	AudioServer.set_bus_volume_db(0, volume)

func update_display_language(index: int):
	GameTheme.display_language = ['n', 'tl', 'en'][index]

func print_pressed(col: int):
	print('Pressed %d'%col)


##########################################################################
# draw fingers points on screen
var fps: float = 0.0
var audio_latency: float = 0.0
func _draw():
	set_text('FPS: %.0f\nAudio Latency: %.2fms'%[fps, audio_latency*1000])
	var swipe_origin = Vector2(300, 540)
	draw_line(swipe_origin, swipe_origin+swipe_momentum, Color.red)

	# draw points
	for i in touch_points:
		var point = touch_points[i]
#		if point.pressed:
		# DRAW POINTS ################################################
		draw_texture(txt_ball, point.position - Vector2(24, 24))
#		draw_string(default_font, point.position - Vector2(24, 24), str(i))
#		draw_string(default_font, point.position + Vector2(-24, 48), str(point.position))
#	if len(touch_positions) > 1:
#		for i in range(len(touch_positions)-1):
#			# Draw line
#			draw_line(touch_positions[i], touch_positions[i+1], Color(1,1,1,1))

var last_latency_check := 0.0
func _process(delta):
	swipe_momentum *= max(1.0 - 5.0*delta, 0)
	if swipe_momentum.length_squared() < 1.0:
		swipe_momentum = Vector2.ZERO
	last_latency_check += delta
	fps = Engine.get_frames_per_second()
	if last_latency_check > 3.0:
		last_latency_check = 0.0
		audio_latency = AudioServer.get_output_latency()  # Note that on official godot builds this will only work ONCE for PulseAudio
	update()

func update_data():
	touch_positions.clear()
	for i in touch_points:
		touch_positions.push_back(touch_points[i].position - rect_size/2)

	var buttons_pressed_temp := []
	var touchbuttons_pressed_temp := []
	for i in Rules.COLS:
		buttons_pressed_temp.append(false)
		touchbuttons_pressed_temp.append(false)

	for pos in touch_positions:
		var pol = cartesian2polar(pos.x, pos.y)
		var dist = pol.x/GameTheme.receptor_ring_radius
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

	set_fingers(len(touch_positions))
	update()

##########################################################################
func _input(event):
	# Unfortunately event.device does NOT differentiate touchscreen inputs on X11, Godot v3.1.1
	# As such, we'll need to do some fancy mapping for multiple inputs
	if (event is InputEventScreenDrag):
		touch_points[event.index] = {pressed = true, position = event.position}
		swipe_momentum = event.speed
	elif (event is InputEventScreenTouch):
		if event.pressed:
			if not touch_points.has(event.index):
				touch_points[event.index] = {}
			touch_points[event.index].position = event.position				# update position
#			touch_points[event.index].pressed = event.pressed		# update "pressed" flag
		else:
			if touch_points.has(event.index):
				touch_points.erase(event.index)
	update_data()

##########################################################################
# write how many fingers are tapping the screen
func set_fingers(value):
	fingers = max(value, 0)

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
