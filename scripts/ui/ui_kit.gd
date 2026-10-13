class_name UiKit
extends RefCounted
## Tema visual "cyber" y atajos para construir interfaz por código.

const CYAN := Color("#00e5ff")
const GREEN := Color("#3ddc84")
const RED := Color("#ff5470")
const AMBER := Color("#ffb020")
const TEXT := Color("#e6f1f7")
const MUTED := Color("#8aa4b4")
const PANEL := Color(0.02, 0.07, 0.11, 0.9)

static var _mono: SystemFont


static func box(bg: Color, border := Color(0, 0.9, 1, 0.35), radius := 10, margin := 12, border_w := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "Button", box(Color(0, 0.9, 1, 0.06), Color(0, 0.9, 1, 0.45), 8, 10))
	t.set_stylebox("hover", "Button", box(Color(0, 0.9, 1, 0.16), CYAN, 8, 10))
	t.set_stylebox("pressed", "Button", box(Color(0, 0.9, 1, 0.3), CYAN, 8, 10))
	t.set_stylebox("disabled", "Button", box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.1), 8, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", TEXT)
		t.set_color(c, "CheckBox", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED)
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(s, "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("background", "ProgressBar", box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 4, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(CYAN, Color(0, 0, 0, 0), 4, 0, 0))
	return t


static func mono() -> SystemFont:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["Cascadia Code", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "Courier New", "monospace"])
	return _mono


static func label(text: String, size := 16, color := TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, callback: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", box(CYAN, CYAN, 8, 10))
		b.add_theme_stylebox_override("hover", box(Color("#5cf0ff"), CYAN, 8, 10))
		b.add_theme_stylebox_override("pressed", box(Color("#00b8cc"), CYAN, 8, 10))
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color("#00131a"))
	return b


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func panel(style: StyleBox = null) -> PanelContainer:
	var p := PanelContainer.new()
	if style != null:
		p.add_theme_stylebox_override("panel", style)
	return p


static func bar(color: Color, width := 120.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 100.0
	b.custom_minimum_size = Vector2(width, 9)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("fill", box(color, Color(0, 0, 0, 0), 4, 0, 0))
	return b


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func severity_color(sev: String) -> Color:
	match sev:
		"Crítica":
			return RED
		"Alta":
			return Color("#ff8a3d")
		"Media":
			return AMBER
	return Color("#8ecae6")


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
