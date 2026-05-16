extends RefCounted
class_name UIStyle

const FONT_PATH := "res://assets/placeholders/ui/Pixelify_Sans/PixelifySans-VariableFont_wght.ttf"
const DEFAULT_FONT_SIZE := 24
const TITLE_FONT_SIZE := 42
const CARD_FONT_SIZE := 18

static var _cached_font: Font = null

static func apply_to_scene(root: Control) -> void:
	if root == null:
		return
	_apply_recursive(root)

static func apply_button_style(button: Button, font_size: int = CARD_FONT_SIZE) -> void:
	if button == null:
		return
	if button.has_theme_font_override("font") or button.has_theme_font_size_override("font_size"):
		return
	_apply_font_to_control(button, font_size)

static func _apply_recursive(node: Node) -> void:
	if node is Label:
		var label := node as Label
		if not (label.has_theme_font_override("font") or label.has_theme_font_size_override("font_size")):
			var is_title := label.name.to_lower().find("title") != -1
			_apply_font_to_control(label, TITLE_FONT_SIZE if is_title else DEFAULT_FONT_SIZE)
	elif node is Button:
		var btn := node as Button
		if not (btn.has_theme_font_override("font") or btn.has_theme_font_size_override("font_size")):
			_apply_font_to_control(btn, DEFAULT_FONT_SIZE)
	elif node is RichTextLabel:
		var rt := node as RichTextLabel
		if not (rt.has_theme_font_override("font") or rt.has_theme_font_size_override("font_size")):
			_apply_font_to_control(rt, DEFAULT_FONT_SIZE - 2)

	for child in node.get_children():
		_apply_recursive(child)

static func _apply_font_to_control(control: Control, font_size: int) -> void:
	var font := _get_font()
	if font != null:
		control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", font_size)

static func get_font() -> Font:
	if _cached_font != null:
		return _cached_font

	if not ResourceLoader.exists(FONT_PATH):
		return null

	var loaded := load(FONT_PATH)
	if loaded is Font:
		_cached_font = loaded

	return _cached_font

static func _get_font() -> Font:
	return get_font()
