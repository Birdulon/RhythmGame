extends Control

var fonts = []
const path = 'res://assets/fonts/'
const font_size = 32
func _ready() -> void:
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin(true, true)
	var filename = dir.get_next()
	while filename != '':
		var file = load(path+filename)
		if file is DynamicFontData:
			var font := DynamicFont.new()
			font.size = font_size
			font.font_data = file
			fonts.append(font)
		filename = dir.get_next()
	dir.list_dir_end()


func _draw() -> void:
	var teststr := 'abcdefghijklmnopqrstuvwxyz'
	var string = teststr.to_upper() + teststr + '!?#$^²°' + 'らりるれろ（笑）'
	var x = 100
	var y = 20
	for font in fonts:
		y += 12
		var a = font.get_ascent()
		var d = font.get_descent()
		var bb = font.get_string_size(string)
		assert(a+d == bb.y)
		var pos = Vector2(x, y+a)
		y += bb.y
		draw_rect(Rect2(pos, Vector2(bb.x, -a)), Color.red)
		draw_rect(Rect2(pos, Vector2(bb.x, d)), Color.blue)
		draw_rect(Rect2(pos, Vector2(-32, -font_size)), Color.green)
		draw_line(Vector2(x, y-bb.y/2), Vector2(x+bb.x, y-bb.y/2), Color.green, 2)
#		draw_line(Vector2(x, y-d-a/2), Vector2(x+bb.x, y-d-a/2), Color.darkgray, 2)
		draw_line(Vector2(x, y-d-font_size/2), Vector2(x+bb.x, y-d-font_size/2), Color.darkgray, 2)
		draw_rect(Rect2(pos+Vector2.UP*a, Vector2(-8, bb.y)), Color.gray)
		draw_string(font, pos, string)

func _process(delta: float) -> void:
	update()
