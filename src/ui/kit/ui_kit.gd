class_name UiKit
extends RefCounted
## Small factory helpers so screens stay short and consistent.

const TOUCH_HEIGHT := 96


static func label(text: String, variation: String = "", align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if variation != "":
		l.theme_type_variation = variation
	return l


static func wrap_label(text: String, variation: String = "", align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, variation, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, on_press: Callable, variation: String = "", min_width: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, TOUCH_HEIGHT)
	if variation != "":
		b.theme_type_variation = variation
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


static func vbox(children: Array = [], separation: int = -1) -> VBoxContainer:
	var box := VBoxContainer.new()
	if separation >= 0:
		box.add_theme_constant_override("separation", separation)
	for c: Node in children:
		box.add_child(c)
	return box


static func hbox(children: Array = [], separation: int = -1) -> HBoxContainer:
	var box := HBoxContainer.new()
	if separation >= 0:
		box.add_theme_constant_override("separation", separation)
	for c: Node in children:
		box.add_child(c)
	return box


static func panel(child: Control, variation: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	p.add_child(child)
	return p


static func margin(child: Control, all: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, all)
	m.add_child(child)
	return m


static func spacer(expand: bool = true) -> Control:
	var c := Control.new()
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func expand(c: Control, horizontal: bool = true, vertical: bool = false) -> Control:
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func icon(kind: String, size: int = 44, color: Color = Color.TRANSPARENT) -> IconDraw:
	var i := IconDraw.new()
	i.kind = kind
	i.custom_minimum_size = Vector2(size, size)
	if color != Color.TRANSPARENT:
		i.tint = color
	return i


static func chip(icon_kind: String, text: String) -> PanelContainer:
	var row := hbox([icon(icon_kind, 40), label(text, "ValueLabel")], 8)
	var p := panel(row, "DarkPanel")
	return p


## 1234 -> "1,234"; 12345 -> "12.3K"; up to "T" and then "aa", "ab"...
static func format_number(n: int) -> String:
	if n < 10000:
		return str(n) if n < 1000 else "%d,%03d" % [n / 1000, n % 1000]
	var units := ["K", "M", "B", "T", "aa", "ab", "ac", "ad"]
	var value := float(n)
	var i := -1
	while value >= 1000.0 and i < units.size() - 1:
		value /= 1000.0
		i += 1
	return ("%.1f%s" if value < 100.0 else "%.0f%s") % [value, units[i]]
