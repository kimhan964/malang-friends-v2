extends RefCounted
const PAPER="faf8f3"
const INK="59493d"
const SAGE="f0dfcc"
const BODY_SIZE=14
const CAPTION_SIZE=12
const TITLE_SIZE=20
static func label(target: Label,role: String="body") -> void:
	target.add_theme_font_size_override("font_size",TITLE_SIZE if role=="title" else (CAPTION_SIZE if role=="caption" else BODY_SIZE))
	target.add_theme_color_override("font_color",Color(INK))
	target.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	target.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
static func button(target: Button) -> void:
	target.add_theme_font_size_override("font_size",BODY_SIZE)
	target.alignment=HORIZONTAL_ALIGNMENT_CENTER
static func box(color: String,radius: int=10) -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=Color(color)
	style.set_corner_radius_all(radius)
	style.content_margin_left=14
	style.content_margin_right=14
	style.content_margin_top=9
	style.content_margin_bottom=9
	return style
static func theme() -> Theme:
	var skin=Theme.new()
	var font=SystemFont.new()
	font.font_names=PackedStringArray(["Malgun Gothic","sans-serif"])
	skin.default_font=font
	skin.default_font_size=BODY_SIZE
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","disabled","focus"]:
			var color={"normal":SAGE,"hover":"ead4bd","pressed":"dfc1a3","disabled":"eeece6","focus":"ead4bd"}[state]
			var style=box(color)
			if state=="focus":
				style.bg_color=Color.TRANSPARENT
				style.border_color=Color("aa8b70")
				style.set_border_width_all(2)
			skin.set_stylebox(state,type,style)
		for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: skin.set_color(key,type,Color(INK))
		skin.set_color("font_disabled_color",type,Color("817d73"))
	skin.set_color("font_color","Label",Color(INK))
	# AcceptDialog has its own panel; PopupPanel styling does not cover it.
	skin.set_stylebox("panel","AcceptDialog",box(PAPER,12))
	skin.set_stylebox("panel","PopupPanel",box(PAPER,18))
	skin.set_stylebox("panel","PopupMenu",box(PAPER))
	skin.set_color("font_color","PopupMenu",Color(INK))
	skin.set_color("font_hover_color","PopupMenu",Color(INK))
	skin.set_stylebox("hover","PopupMenu",box(SAGE))
	for state in ["background","fill"]:
		var bar=box("eeece6" if state=="background" else "c6aa88",4)
		bar.content_margin_top=0
		bar.content_margin_bottom=0
		bar.content_margin_left=0
		bar.content_margin_right=0
		skin.set_stylebox(state,"ProgressBar",bar)
	return skin
