extends Node

#const MAX_PLAYERS = 16
#var players = []
#
#func _init():
#	for i in MAX_PLAYERS:
#		players.append(AudioStreamPlayer.new())
#
#func play():
#	pass



# https://github.com/Calinou/escape-space/blob/master/autoload/sound.gd
enum Type {
	NON_POSITIONAL,
	POSITIONAL_2D,
}


# Plays a sound. The AudioStreamPlayer node will be added to the `parent`
# specified as parameter.
func play(type: int, parent: Node, stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var audio_stream_player: Node
	match type:
		Type.NON_POSITIONAL:
			audio_stream_player = AudioStreamPlayer.new()
		Type.POSITIONAL_2D:
			audio_stream_player = AudioStreamPlayer2D.new()

	parent.add_child(audio_stream_player)
	audio_stream_player.bus = "Effects"
	audio_stream_player.stream = stream
	audio_stream_player.volume_db = volume_db
	audio_stream_player.pitch_scale = pitch_scale
	audio_stream_player.play()
	audio_stream_player.connect("finished", audio_stream_player, "queue_free")


var music_player := AudioStreamPlayer.new()
var music_player_pv := AudioStreamPlayer.new()
func _ready() -> void:
	add_child(music_player)
	music_player.bus = "Music"
	add_child(music_player_pv)
	music_player_pv.bus = "Preview"
