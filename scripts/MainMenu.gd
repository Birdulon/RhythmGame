extends Control
signal start_touchgame
signal start_stepgame

func quit() -> void:
	get_tree().quit()

func _on_btn_touch_pressed() -> void:
	emit_signal('start_touchgame')

func _on_btn_step_pressed() -> void:
	emit_signal('start_stepgame')
