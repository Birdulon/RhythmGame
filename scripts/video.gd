extends VideoPlayer

func _ready():
	pass
	# I need to put videoplayer resizing logic somewhere else, this is placeholder
	update_aspect_ratio(1440.0/1080.0)

func update_aspect_ratio(ratio: float):
	# e.g. for a 1920x1080 video you'd call update_aspect_ratio(1920.0/1080.0)
	# e.g. for a 1440x1080 video you'd call update_aspect_ratio(1440.0/1080.0)
	var height = 1080/ratio
	margin_top = -height/2.0
	margin_bottom = height/2.0
