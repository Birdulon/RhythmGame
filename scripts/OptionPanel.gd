extends VBoxContainer

func _on_btn_vsync_toggled(button_pressed: bool) -> void:
	OS.set_use_vsync(button_pressed)

func _on_btn_wakelock_toggled(button_pressed: bool) -> void:
	OS.set_keep_screen_on(button_pressed)  # This is waiting on godotengine/godot#35536 to be merged to do anything in Linux :(

func _on_btn_language_item_selected(index: int) -> void:
	GameTheme.display_language = ['n', 'tl', 'en'][index]

func _on_sl_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)

func _on_sl_screenfilter_value_changed(value: float) -> void:
	GameTheme.screen_filter_min_alpha = value

func _on_sl_SSX_value_changed(value: float) -> void:
	Settings.SSX_set(value)

func _on_sl_SSY_value_changed(value: float) -> void:
	Settings.SSY_set(value)
