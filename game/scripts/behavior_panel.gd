extends Node
var app
var panel: Window
var status: Label
var automatic=true
var typing=false
var bridge=preload("res://scripts/typing_input.gd").new()
var activity=preload("res://scripts/typing_activity.gd").new()
var last_typing=-10000
var action_buttons={}
func _exit_tree() -> void: bridge.stop()
func open() -> void:
	if not is_instance_valid(panel): build()
	panel.position=app.usable_screen().get_center()-panel.size/2
	panel.show()
func build() -> void:
	panel=Window.new();panel.visible=false;panel.force_native=true;panel.always_on_top=true
	panel.title="말랑친구 · 다양한 행동";panel.size=Vector2i(490,700);panel.unresizable=true
	panel.theme=app.app_theme;panel.close_requested.connect(panel.hide);add_child(panel)
	var background=ColorRect.new();background.color=Color(preload("res://scripts/cozy_ui.gd").PAPER)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE;background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(background)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	panel.add_child(margin)
	var col=VBoxContainer.new();col.add_theme_constant_override("separation",12);margin.add_child(col)
	var title=Label.new();title.text="오늘은 무얼 해볼까?";title.add_theme_font_size_override("font_size",22);col.add_child(title)
	var hint=Label.new();hint.text="행동을 고르면 지금 있는 자리에서 보여줘요.\n펫을 집거나 가구를 고르면 자연스럽게 중단합니다.";hint.add_theme_font_size_override("font_size",13);col.add_child(hint)
	var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",8);col.add_child(grid)
	for kind in preload("res://scripts/daily_behaviors.gd").LABELS:
		var button=Button.new();button.text=preload("res://scripts/daily_behaviors.gd").LABELS[kind]
		action_buttons[kind]=button
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size=Vector2(210,42)
		button.pressed.connect(func():
			panel.hide()
			app.cancel_feeding();app.cancel_hunt();app.furniture_room.toy_play.cancel()
			var m=app.pet.motion
			if not m.held and not m.carried and m.phase not in ["drop","dizzy"]:
				m.cancel_play();m.daily.start(m,kind))
		grid.add_child(button)
	var auto_box=CheckBox.new();auto_box.text="쉬는 동안 다양한 행동 스스로 하기";auto_box.button_pressed=automatic
	auto_box.toggled.connect(func(value): automatic=value);col.add_child(auto_box)
	var type_box=CheckBox.new();type_box.text="빠른 타자에 신나게 반응하기";type_box.button_pressed=typing
	type_box.toggled.connect(func(value):
		typing=value
		if value: bridge.start()
		else: bridge.stop()
		status.text="키 입력 횟수로만 반응해요." if value else "버튼으로 직접 고르거나 자동 행동을 켜 주세요.")
	col.add_child(type_box)
	status=Label.new();status.text="버튼으로 직접 고르거나 자동 행동을 켜 주세요.";status.add_theme_font_size_override("font_size",12);col.add_child(status)
	var close=Button.new();close.text="닫기";close.pressed.connect(panel.hide);col.add_child(close)
func _process(_delta: float) -> void:
	if not is_instance_valid(app.pet): return
	var m=app.pet.motion
	m.behavior_points=app.state.home_points()
	for kind in action_buttons:
		var ready=preload("res://scripts/behavior_unlocks.gd").available(m.behavior_points,kind)
		action_buttons[kind].disabled=not ready
		action_buttons[kind].tooltip_text=preload("res://scripts/behavior_unlocks.gd").hint(m.behavior_points,kind)
		action_buttons[kind].text=preload("res://scripts/daily_behaviors.gd").LABELS[kind]+("\n교감 %d 필요"%preload("res://scripts/behavior_unlocks.gd").THRESHOLDS.get(kind,0) if not ready else "")
	m.daily.enabled=automatic and not app.decorating and not app.pet.menu.visible and not (is_instance_valid(panel) and panel.visible)
	if not typing: return
	var count=bridge.poll()
	var now=Time.get_ticks_msec()
	activity.update(now,count,bridge.connected)
	if is_instance_valid(status) and not bridge.error.is_empty(): status.text=bridge.error
	if count>0 and activity.apm>=130 and now-last_typing>16000 and m.phase in ["idle","wander"] and m.daily.start(m,"run"):
		last_typing=now
