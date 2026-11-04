class_name UiTheme
extends RefCounted
## Builds the game's Godot Theme in code: cream panels with brown outlines,
## chunky "3D" buttons (thicker darker bottom edge) and the two OFL fonts.
## Type variations: TitleLabel, HeadingLabel, SmallLabel, ValueLabel,
## GreenButton, BlueButton, RedButton, GhostButton, CardPanel, DarkPanel.

const FONT_DISPLAY := preload("res://assets/fonts/LilitaOne-Regular.woff2")
const FONT_BODY := preload("res://assets/fonts/Nunito-ExtraBold.woff2")
const BASE_FONT_SIZE := 30


static func build(text_scale: float = 1.0) -> Theme:
	var t := Theme.new()
	t.default_font = FONT_BODY
	t.default_font_size = int(BASE_FONT_SIZE * text_scale)

	t.set_color("font_color", "Label", Palette.INK)
	_label_variation(t, "TitleLabel", FONT_DISPLAY, int(64 * text_scale), Palette.WHITE, Palette.OUTLINE, 12)
	_label_variation(t, "HeadingLabel", FONT_DISPLAY, int(40 * text_scale), Palette.INK, Color.TRANSPARENT, 0)
	_label_variation(t, "ValueLabel", FONT_DISPLAY, int(34 * text_scale), Palette.WHITE, Palette.OUTLINE, 8)
	_label_variation(t, "SmallLabel", FONT_BODY, int(24 * text_scale), Palette.INK_SOFT, Color.TRANSPARENT, 0)

	_button_style(t, "Button", Palette.GOLD, Palette.GOLD_DARK, text_scale)
	_button_style(t, "GreenButton", Palette.GREEN, Palette.GREEN_DARK, text_scale)
	_button_style(t, "BlueButton", Palette.BLUE, Color("#2f7fd0"), text_scale)
	_button_style(t, "RedButton", Palette.RED, Color("#c42f35"), text_scale)
	_button_style(t, "GhostButton", Palette.CREAM, Palette.CREAM_DARK, text_scale)
	for variation in ["GreenButton", "BlueButton", "RedButton", "GhostButton"]:
		t.set_type_variation(variation, "Button")

	t.set_stylebox("panel", "PanelContainer", box(Palette.CREAM, Palette.OUTLINE, 28, 5))
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", box(Palette.WHITE, Palette.OUTLINE, 24, 5))
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", box(Color(0.12, 0.08, 0.05, 0.82), Palette.OUTLINE, 24, 4))

	t.set_stylebox("background", "ProgressBar", box(Color("#3b2414"), Palette.OUTLINE, 10, 3, 0))
	t.set_stylebox("fill", "ProgressBar", box(Palette.HP, Color.TRANSPARENT, 8, 0, 0))
	t.set_constant("separation", "VBoxContainer", 16)
	t.set_constant("separation", "HBoxContainer", 16)
	return t


## Rounded box with an outline; a thicker bottom edge gives a chunky 3D feel.
static func box(bg: Color, border: Color, radius: int, border_width: int, bottom_extra: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.border_width_bottom = border_width + bottom_extra
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 12
	s.content_margin_bottom = 12 + bottom_extra
	s.anti_aliasing = true
	return s


static func _button_style(t: Theme, type: String, fill: Color, edge: Color, text_scale: float) -> void:
	var normal := box(fill, Palette.OUTLINE, 22, 5, 6)
	normal.border_color = Palette.OUTLINE
	var hover := box(fill.lightened(0.12), Palette.OUTLINE, 22, 5, 6)
	var pressed := box(edge, Palette.OUTLINE, 22, 5, 2)
	pressed.content_margin_top = 16
	var disabled := box(Color("#d9cdb4"), Color("#a08a6a"), 22, 5, 6)
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_font("font", type, FONT_DISPLAY)
	t.set_font_size("font_size", type, int(36 * text_scale))
	t.set_color("font_color", type, Palette.INK)
	t.set_color("font_hover_color", type, Palette.INK)
	t.set_color("font_pressed_color", type, Palette.INK)
	t.set_color("font_disabled_color", type, Color("#8a7a5a"))


static func _label_variation(t: Theme, variation: String, font: Font, size: int, color: Color, outline: Color, outline_size: int) -> void:
	t.set_type_variation(variation, "Label")
	t.set_font("font", variation, font)
	t.set_font_size("font_size", variation, size)
	t.set_color("font_color", variation, color)
	if outline_size > 0:
		t.set_color("font_outline_color", variation, outline)
		t.set_constant("outline_size", variation, outline_size)
