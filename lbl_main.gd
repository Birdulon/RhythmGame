extends Label

var touch_points = {} 								# array containing all points touched on the screen
var fingers = 0 setget set_fingers					# setter for show fingers number on screen
var txt_ball = preload("res://assets/ball.png")		# preload our ball texture
var default_font = preload("res://assets/NotoSans.tres")	# point to godot standard font

func _ready():
	set_process_unhandled_input(true)				# process user input

##########################################################################
# draw fingers points on screen
func _draw():
	var touch_positions = PoolVector2Array()
	# draw points
	for i in touch_points:
		var point = touch_points[i]
		if point.pressed:
			touch_positions.push_back(point.position)
			# DRAW POINTS ################################################
			draw_texture(txt_ball, point.position - Vector2(24, 24))
			draw_string(default_font, point.position - Vector2(24, 24), str(i))
	if len(touch_positions) > 1:
		for i in range(len(touch_positions)-1):
			# Draw line
			draw_line(touch_positions[i], touch_positions[i+1], Color(1,1,1,1))
	set_fingers(len(touch_positions))
##########################################################################
func _input(event):
	if (event is InputEventScreenDrag):
		touch_points[event.index] = {pressed = true, position = event.position}
	if (event is InputEventScreenTouch):
		if event.pressed:
			if not touch_points.has(event.index):
				touch_points[event.index] = {}
			touch_points[event.index].position = event.position				# update position
			touch_points[event.index].pressed = event.pressed		# update "pressed" flag
		else:
			if touch_points.has(event.index):
				touch_points.erase(event.index)
	update()

##########################################################################
# write how many fingers are tapping the screen
func set_fingers(value):
	fingers = value
	if fingers > 0:
		set_text(str(fingers))
	else:
		set_text("0")