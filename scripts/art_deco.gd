extends RefCounted
const TITLE_FONT = preload("res://assets/fonts/Limelight-Regular.ttf")
const BUTTON_BASE = preload("res://assets/fonts/JosefinSans.ttf")
const GOLD := Color("ebc88b")
const TEAL := Color("83e0d0")
static var shared_theme: Theme

static func button_font() -> FontVariation:
    var font := FontVariation.new()
    font.base_font = BUTTON_BASE
    font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600.0}
    font.variation_embolden = 0.35
    return font

static func style(fill: Color, border: Color, margin: int = 16) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = fill
    box.border_color = border
    box.set_border_width_all(1)
    box.set_corner_radius_all(0)
    box.content_margin_left = margin
    box.content_margin_right = margin
    box.content_margin_top = 7
    box.content_margin_bottom = 7
    return box

static func theme() -> Theme:
    if shared_theme != null:
        return shared_theme
    var result := Theme.new()
    result.set_font("font", "Button", button_font())
    result.set_font_size("font_size", "Button", 16)
    result.set_color("font_color", "Button", GOLD)
    result.set_color("font_hover_color", "Button", Color("fff0cf"))
    result.set_color("font_pressed_color", "Button", Color("fff0cf"))
    result.set_color("font_focus_color", "Button", Color("a1f4e5"))
    result.set_stylebox("normal", "Button", style(Color("10272e"), Color("8c7753")))
    result.set_stylebox("hover", "Button", style(Color("1d3a3d"), GOLD))
    result.set_stylebox("pressed", "Button", style(Color("285051"), TEAL))
    var focus: StyleBoxFlat = style(Color(0,0,0,0), TEAL)
    focus.set_border_width_all(2)
    focus.set_expand_margin_all(2)
    result.set_stylebox("focus", "Button", focus)
    result.set_stylebox("disabled", "Button", style(Color("151e23"), Color("46504f")))
    result.set_stylebox("normal", "LineEdit", style(Color("0a1a24"), Color("8c7753"), 10))
    result.set_stylebox("focus", "LineEdit", style(Color(0,0,0,0), TEAL, 10))
    result.set_color("caret_color", "LineEdit", GOLD)
    shared_theme = result
    return result

static func skin_button(button: Button) -> void:
    button.theme = theme()
    var compact: bool = button.text.length() <= 1 or button.text in ["SPACE", "DEL"]
    if compact:
        for state in ["normal", "hover", "pressed", "disabled"]:
            var base: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
            base.content_margin_left = 7
            base.content_margin_right = 7
            button.add_theme_stylebox_override(state, base)
    var frame := preload("res://scripts/deco_button_frame.gd").new()
    frame.compact = compact
    button.add_child(frame)

static func skin_title(label: Label) -> void:
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_override("font", TITLE_FONT)
    label.add_theme_color_override("font_color", GOLD)
    label.add_theme_color_override("font_shadow_color", Color("030b13"))
    label.add_theme_constant_override("shadow_offset_y", 2)
    label.add_child(preload("res://scripts/deco_title_rule.gd").new())

static func fit_title(label: Label, maximum: int, width: float) -> void:
    var font_size: int = maximum
    while font_size > 20 and TITLE_FONT.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
        font_size -= 1
    label.add_theme_font_size_override("font_size", font_size)
