extends Node

# Video decoding is relatively expensive for Godot so we only want to do it once at a time.

var video := VideoPlayer.new()

var texture: Texture setget , get_texture
func get_texture() -> Texture:
	return video.get_video_texture()

func _ready():
	video.expand = false
	add_child(video)  # Needs to be in scene tree to make the textures
	video.visible = false  # Luckily this is enough to make the textures without rendering

func _process(delta: float) -> void:
	get_tree().call_group('VideoTexRects', 'set_texture', self.texture)
