extends ColorRect

onready var root := $'/root'

func _ready():
	GameTheme.connect('screen_filter_changed', self, 'set_frame_color')
