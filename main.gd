extends Control
export var MainMenuPath := @'MainMenu'
onready var MainMenu := get_node(MainMenuPath)

const TouchGamePath := 'res://scenes/RadialGame.tscn'
const StepGamePath := 'res://scenes/StepGame.tscn'
var TouchGameScene := preload(TouchGamePath)
var StepGameScene := preload(StepGamePath)

var ActiveGame: Node = null

func _on_MainMenu_start_stepgame() -> void:
	MainMenu.hide()
	ActiveGame = StepGameScene.instance()
	add_child_below_node(MainMenu, ActiveGame)


func _on_MainMenu_start_touchgame() -> void:
	MainMenu.hide()
	ActiveGame = TouchGameScene.instance()
	add_child_below_node(MainMenu, ActiveGame)
	ActiveGame.alignment_horizontal = AspectRatioContainer.ALIGN_BEGIN
