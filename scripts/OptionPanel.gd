extends VBoxContainer

func resize():
	var screen_size = $'/root'.get_visible_rect().size
	rect_position = -screen_size*0.5
#	rect_size = screen_size

export var btn_language: NodePath = @"hbox_language/btn_language"
onready var BtnLanguage = get_node(btn_language)
func _ready() -> void:
	$'/root'.connect('size_changed', self, 'resize')
	$HBoxContainer/btn_vsync.connect('toggled', OS, 'set_use_vsync')
	$HBoxContainer/btn_wakelock.connect('toggled', OS, 'set_keep_screen_on')  # This is waiting on godotengine/godot#35536 to be merged to do anything in Linux :(
	$sl_screenfilter.connect('value_changed', self, 'update_filter')
	$sl_volume.connect('value_changed', self, 'update_volume')
	$sl_SSX.connect('value_changed', Settings, 'SSX_set')
	$sl_SSY.connect('value_changed', Settings, 'SSY_set')
	BtnLanguage.add_item('Native')
	BtnLanguage.add_item('Romaji')
	BtnLanguage.add_item('English')
	BtnLanguage.connect('item_selected', self, 'update_display_language')
	resize()


func update_filter(alpha: float):
	GameTheme.screen_filter_min_alpha = alpha

func update_volume(volume: float):
	AudioServer.set_bus_volume_db(0, volume)

func update_display_language(index: int):
	GameTheme.display_language = ['n', 'tl', 'en'][index]
