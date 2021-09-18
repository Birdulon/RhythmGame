extends Control

var touch_points = {} 								# dict containing all points touched on the screen
var touch_positions = []							# array of above
signal touch_positions_updated(positions)

var fingers = 0 setget set_fingers					# setter for show fingers number on screen
var txt_ball = preload('res://assets/ball.png')		# preload our ball texture
var default_font = preload('res://assets/NotoSans.tres')

var swipe_momentum := Vector2.ZERO

func _ready():
	Input.set_use_accumulated_input(false)  # Gotta go fast
	set_process_unhandled_input(true)  # process user input
	set_fingers(0)
#	connect('button_pressed', self, 'print_pressed')

func print_pressed(col: int):
	print('Pressed %d'%col)

func _draw():  # draw fingers points on screen
#	var swipe_origin = Vector2(300, 540)
#	draw_line(swipe_origin, swipe_origin+swipe_momentum, Color.red)

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

func _process(delta):
#	swipe_momentum *= max(1.0 - 5.0*delta, 0)
#	if swipe_momentum.length_squared() < 1.0:
#		swipe_momentum = Vector2.ZERO
	update()

func update_data():
	touch_positions.clear()
	for i in touch_points:
		touch_positions.push_back(touch_points[i].position)  # - rect_size/2)
	emit_signal('touch_positions_updated', touch_positions)
	set_fingers(len(touch_positions))
	update()

##########################################################################
func _input(event):
	# Unfortunately event.device does NOT differentiate touchscreen inputs on X11, Godot v3.1.1
	# As such, we'll need to do some fancy mapping for multiple inputs
	if (event is InputEventScreenDrag):
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		touch_points[event.index] = {pressed = true, position = event.position}
#		swipe_momentum = event.speed
	elif (event is InputEventScreenTouch):
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		if event.pressed:
			if not touch_points.has(event.index):
				touch_points[event.index] = {}
			touch_points[event.index].position = event.position				# update position
#			touch_points[event.index].pressed = event.pressed		# update "pressed" flag
		else:
			if touch_points.has(event.index):
				touch_points.erase(event.index)
	elif (event is InputEventMouse):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	update_data()

func set_fingers(value):
	fingers = max(value, 0)
