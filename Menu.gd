extends Node2D

var song_defs = {}
var song_images = {}

func scan_library():
	print("Scanning library")
	var rootdir = "res://songs"
	var dir = Directory.new()
	var err = dir.open(rootdir)
	if err == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		while (file_name != ""):
			if dir.current_is_dir():
				if dir.file_exists(file_name + "/song.json"):
					song_defs[file_name] = FileLoader.load_folder("%s/%s" % [rootdir, file_name])
					print("Loaded song directory: %s" % file_name)
					song_images[file_name] = load("%s/%s/%s" % [rootdir, file_name, song_defs[file_name]["tile_filename"]])
				else:
					print("Found directory: " + file_name)
			else:
				print("Found file: " + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("An error occurred when trying to access the songs directory: ", err)

func _ready():
	scan_library()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _draw():
	var i = -512
	for key in song_images:
		draw_texture(song_images[key], Vector2(i, -256))
		i += 512