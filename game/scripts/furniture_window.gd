extends Window
signal moved
signal removed
signal activated(action: String)
signal layer_changed
signal stack_requested(direction: int)
signal toy_launched(velocity: Vector2)
const Catalog=preload("res://scripts/furniture_catalog.gd")
var item_id="sofa"
var sprite: Sprite2D
var menu: PopupMenu
var dragging=false
var press_cursor=Vector2.ZERO
var press_position=Vector2.ZERO
var hit_polygon=PackedVector2Array()
var food_sprite: Sprite2D
var active=false
var drop_hover=false
var mirrored=false
var user_scale=1.0
var stack_order=0
var size_editor: Window
var size_percent: SpinBox
var size_slider: HSlider
var throw_samples: Array=[]
var press_local=Vector2.ZERO
var pressed_at=0
var floor_locked=false
var floor_top=0
var arriving=false
var effect_time=0.0
var roll_angle=0.0
var roam_speed=0.0
var roam_time=0.0
var appearance={"color":0,"finish":0,"design":0}
var art_origin=Vector2(6,6)
var settle_time=0.0
var last_layer_position=Vector2i(2147483647,2147483647)
func fit_surface(dimensions: Vector2) -> void:
	if item_id=="toy_ball":
		# Rotation and wobble must fit even when the yarn tail points diagonally.
		var extent=ceili(dimensions.length())+24
		size=Vector2i(extent,extent)
		art_origin=(Vector2(size)-dimensions)*.5
	else:
		size=Vector2i(dimensions.ceil())+Vector2i(12,12)
		art_origin=Vector2(6,6)
func set_appearance(value: Dictionary,persist: bool=false) -> void:
	appearance=Catalog.normalize_style(value)
	if is_instance_valid(sprite):
		sprite.texture=Catalog.texture(item_id,appearance.design)
		var limit: Vector2=Catalog.ITEMS[item_id].size
		var factor=minf(limit.x/sprite.texture.get_width(),limit.y/sprite.texture.get_height())*user_scale
		sprite.scale=Vector2.ONE*factor
		fit_surface(sprite.texture.get_size()*factor)
		sprite.position=art_origin+(sprite.texture.get_size()*sprite.scale*.5 if sprite.centered else Vector2.ZERO)
		Catalog.apply_style(sprite.material,appearance,item_id)
		refresh_hit_region()
	if persist: moved.emit(); layer_changed.emit()
func _init() -> void:
	visible=false
	force_native=true
	borderless=true
	transparent=true
	transparent_bg=true
	always_on_top=true
	unfocusable=true
	unresizable=true
	transient=false
	exclusive=false
func _ready() -> void:
	title=Catalog.ITEMS[item_id].name+" · 드래그로 이동 / 우클릭으로 반전"
	var tex=Catalog.texture(item_id,appearance.design)
	if tex==null: return
	var limit: Vector2=Catalog.ITEMS[item_id].size
	var factor=minf(limit.x/tex.get_width(),limit.y/tex.get_height())
	var dimensions=tex.get_size()*factor
	fit_surface(dimensions)
	sprite=Sprite2D.new()
	sprite.texture=tex
	sprite.material=Catalog.material()
	sprite.centered=item_id=="toy_ball"
	sprite.position=art_origin+(dimensions*.5 if sprite.centered else Vector2.ZERO)
	sprite.scale=Vector2.ONE*factor
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	Catalog.apply_style(sprite.material,appearance,item_id)
	refresh_hit_region()
	food_sprite=Sprite2D.new()
	food_sprite.material=Catalog.material()
	add_child(food_sprite)
	menu=PopupMenu.new()
	menu.force_native=true
	menu.theme=preload("res://scripts/cozy_ui.gd").theme()
	menu.add_item(Catalog.use_label(item_id),1)
	if item_id=="table": menu.add_item("물컵 내놓기",2)
	if item_id=="table": menu.add_item("선택한 음식 차리기",3)
	menu.add_separator()
	menu.add_check_item("좌우 반전",12)
	menu.add_item("맨 앞으로",20)
	menu.add_item("맨 뒤로",21)
	menu.add_separator()
	menu.add_item("크기 조절 (현재 100%)",22)
	menu.add_item("기본 크기",24)
	menu.add_separator()
	menu.add_item("가구 치우기",0)
	menu.id_pressed.connect(menu_action)
	menu.popup_hide.connect(func(): layer_changed.emit())
	add_child(menu)
	window_input.connect(handle_input)
	show()
	update_input()
func menu_action(id: int) -> void:
	match id:
		0: removed.emit()
		10: nudge(-24)
		11: nudge(24)
		12: set_mirrored(not mirrored,true)
		20: stack_requested.emit(1)
		21: stack_requested.emit(-1)
		22: open_size_editor()
		24: set_user_scale(1.0,true)
		_: activated.emit("drink" if id==2 else ("eat" if id==3 else "default"))
func set_user_scale(value: float,persist: bool=false) -> void:
	var ground=ground_point()
	user_scale=clampf(snappedf(value,.01),.6,1.6)
	set_appearance(appearance)
	position=clamp_position(Vector2(position)+ground-ground_point())
	if is_instance_valid(menu):
		menu.set_item_text(menu.get_item_index(22),"크기 조절 (현재 %d%%)"%roundi(user_scale*100))
	if is_instance_valid(size_percent): size_percent.set_value_no_signal(roundi(user_scale*100))
	if is_instance_valid(size_slider): size_slider.set_value_no_signal(roundi(user_scale*100))
	if persist: moved.emit(); layer_changed.emit()
func open_size_editor() -> void:
	if not is_instance_valid(size_editor):
		size_editor=Window.new()
		size_editor.visible=false
		size_editor.title="가구 크기 · "+Catalog.ITEMS[item_id].name
		size_editor.force_native=true
		size_editor.size=Vector2i(300,166)
		size_editor.unresizable=true
		size_editor.always_on_top=true
		size_editor.theme=preload("res://scripts/cozy_ui.gd").theme()
		size_editor.close_requested.connect(size_editor.hide)
		size_editor.visibility_changed.connect(func(): layer_changed.emit())
		add_child(size_editor)
		var background=ColorRect.new()
		background.color=Color(preload("res://scripts/cozy_ui.gd").PAPER)
		background.mouse_filter=Control.MOUSE_FILTER_IGNORE
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		size_editor.add_child(background)
		var margin=MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
		size_editor.add_child(margin)
		var column=VBoxContainer.new()
		column.add_theme_constant_override("separation",12)
		margin.add_child(column)
		var row=HBoxContainer.new()
		column.add_child(row)
		var label=Label.new()
		label.text="크기 (%)"
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(label)
		size_percent=SpinBox.new()
		size_percent.min_value=60
		size_percent.max_value=160
		size_percent.step=1
		size_percent.custom_minimum_size=Vector2(116,36)
		size_percent.alignment=HORIZONTAL_ALIGNMENT_CENTER
		size_percent.value_changed.connect(func(value): set_user_scale(value/100.0,true))
		row.add_child(size_percent)
		var input=size_percent.get_line_edit()
		input.add_theme_color_override("font_color",Color(preload("res://scripts/cozy_ui.gd").INK))
		input.add_theme_stylebox_override("normal",preload("res://scripts/cozy_ui.gd").box("ffffff",8))
		size_slider=HSlider.new()
		size_slider.min_value=60
		size_slider.max_value=160
		size_slider.step=1
		size_slider.custom_minimum_size=Vector2(0,28)
		size_slider.value_changed.connect(func(value): set_user_scale(value/100.0,true))
		column.add_child(size_slider)
		var reset=Button.new()
		reset.text="기본 크기 · 100%"
		reset.pressed.connect(func(): set_user_scale(1.0,true))
		column.add_child(reset)
	size_percent.set_value_no_signal(roundi(user_scale*100))
	size_slider.set_value_no_signal(roundi(user_scale*100))
	var screen=DisplayServer.screen_get_usable_rect() if DisplayServer.get_name()!="headless" else Rect2i(0,0,1920,1080)
	size_editor.position=Vector2i(Vector2(position-Vector2i(0,190)).clamp(Vector2(screen.position),Vector2(screen.end-size_editor.size)))
	size_editor.show()
	size_percent.get_line_edit().grab_focus()
	size_percent.get_line_edit().select_all()
	layer_changed.emit()
func refresh_hit_region() -> void:
	var tex=sprite.texture
	var points=preload("res://scripts/animation_outline.gd").local_hull(tex)
	if mirrored:
		for i in range(points.size()): points[i].x=tex.get_width()-points[i].x
	if sprite.centered:
		for i in range(points.size()): points[i]-=tex.get_size()*.5
	hit_polygon=sprite.transform*points
	# This picture never animates. Install one generously padded input region;
	# clicking must also work when the cursor enters and presses in one frame.
	var padded=PackedVector2Array()
	if item_id in preload("res://scripts/v2_furniture_art.gd").IDS:
		# One stable generous region includes every generated cushion/water cel.
		mouse_passthrough_polygon=PackedVector2Array([art_origin,art_origin+Vector2(tex.get_width()*sprite.scale.x,0),art_origin+tex.get_size()*sprite.scale,art_origin+Vector2(0,tex.get_height()*sprite.scale.y)])
		return
	if item_id=="toy_ball":
		# Windows clips drawing to the native input region too. Cover every
		# rotation with one stable mask instead of the upright yarn silhouette.
		var radius=sprite.texture.get_size().length()*sprite.scale.x*.5+5
		for i in range(48): padded.append(sprite.position+Vector2.from_angle(TAU*i/48)*radius)
		mouse_passthrough_polygon=Geometry2D.convex_hull(padded)
		return
	for point in hit_polygon:
		for offset in [Vector2(-2,-2),Vector2(2,-2),Vector2(-2,2),Vector2(2,2)]: padded.append(point+offset)
	mouse_passthrough_polygon=Geometry2D.convex_hull(padded)
func set_mirrored(value: bool,persist: bool=false) -> void:
	mirrored=value
	if is_instance_valid(sprite):
		sprite.flip_h=value
		refresh_hit_region()
	if is_instance_valid(menu) and menu.get_item_index(12)>=0: menu.set_item_checked(menu.get_item_index(12),value)
	if persist:
		moved.emit()
		layer_changed.emit()
func nudge(amount: int) -> void:
	position=clamp_position(Vector2(position)+Vector2(amount,0))
	if floor_locked: position.y=floor_top
	moved.emit()
	layer_changed.emit()
func clamp_position(point: Vector2) -> Vector2i:
	if DisplayServer.get_name()=="headless": return Vector2i(point.clamp(Vector2.ZERO,Vector2(1920,1080)-Vector2(size)))
	var monitor=DisplayServer.get_screen_from_rect(Rect2i(Vector2i(point+Vector2(size)*.5),Vector2i.ONE))
	if monitor<0: monitor=DisplayServer.SCREEN_PRIMARY
	var usable=DisplayServer.screen_get_usable_rect(monitor)
	return Vector2i(point.clamp(Vector2(usable.position),Vector2((usable.end-size).max(usable.position))))
func handle_input(event: InputEvent) -> void:
	if arriving: return
	if event is InputEventMouseMotion and dragging:
		move_dragged_to(Vector2(DisplayServer.mouse_get_position()))
		return
	if not event is InputEventMouseButton: return
	if event.pressed: layer_changed.emit()
	if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		dragging=false
		menu.position=DisplayServer.mouse_get_position()
		menu.popup()
	elif event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging=true
			pressed_at=Time.get_ticks_msec()
			press_local=event.position
			throw_samples=[{"at":Vector2(position),"time":Time.get_ticks_msec()}]
			# Use the position carried by the press event: the OS cursor can
			# already be at the release point during a very quick drag.
			press_cursor=Vector2(position)+event.position
			press_position=Vector2(position)
		elif dragging:
			# The queued release owns the actual click coordinate. A newer global
			# cursor location can falsely turn a quick click into a furniture drag.
			move_dragged_to(Vector2(position)+event.position)
			dragging=false
			finish_drag()
func update_input() -> void:
	mouse_passthrough=arriving
func finish_drag() -> void:
	if item_id in ["toy_mouse","toy_ball"]:
		var velocity=Vector2.ZERO
		if Vector2(position).distance_to(press_position)<4:
			velocity.x=(1 if press_local.x<size.x*.5 else -1)*(210 if item_id=="toy_ball" else 170)
		elif not throw_samples.is_empty():
			var first=throw_samples[0]
			var seconds=maxf(.016,(Time.get_ticks_msec()-first.time)/1000.0)
			velocity.x=clampf((position.x-first.at.x)/seconds,-360,360)
		moved.emit()
		toy_launched.emit(velocity)
		layer_changed.emit()
		return
	if Vector2(position).distance_to(press_position)<6: activated.emit("default")
	else: moved.emit()
	layer_changed.emit()
func art_point(fraction: Vector2) -> Vector2:
	if mirrored: fraction.x=1.0-fraction.x
	return Vector2(position)+art_origin+sprite.texture.get_size()*sprite.scale*fraction
func set_food(texture: Texture2D,amount: float=1.0) -> void:
	if item_id!="table": return
	food_sprite.texture=texture
	food_sprite.visible=texture!=null and amount>.01
	if not food_sprite.visible: return
	food_sprite.position=art_point(Vector2(.68,.35))-Vector2(position)
	food_sprite.flip_h=mirrored
	food_sprite.scale=Vector2.ONE*minf(21.0/texture.get_width(),18.0/texture.get_height())*lerpf(.7,1.0,amount)
	food_sprite.modulate.a=amount
func set_active(value: bool) -> void:
	if active and not value: settle_time=.45
	if not active and value: effect_time=0.0
	active=value
	refresh_tint()
func set_drop_hover(value: bool) -> void:
	if drop_hover==value: return
	drop_hover=value
	refresh_tint()
func refresh_tint() -> void:
	if not is_instance_valid(sprite): return
	# Tint existing pixels so the shaped native window cannot clip a new halo.
	sprite.modulate=Color(1.0,.88,.63) if drop_hover else (Color(1.0,.94,.81) if item_id=="lamp" and active else Color.WHITE)
func move_dragged_to(cursor: Vector2) -> void:
	position=clamp_position(press_position+cursor-press_cursor)
	if floor_locked: position.y=floor_top
	if item_id in ["toy_mouse","toy_ball"]:
		var now=Time.get_ticks_msec()
		throw_samples.append({"at":Vector2(position),"time":now})
		while throw_samples.size()>2 and now-throw_samples[0].time>120: throw_samples.pop_front()
func _process(_delta: float) -> void:
	effect_time=effect_time+_delta if active else 0.0
	settle_time=maxf(0,settle_time-_delta)
	if is_instance_valid(sprite):
		if item_id in preload("res://scripts/v2_furniture_art.gd").IDS:
			sprite.texture=preload("res://scripts/v2_furniture_art.gd").sample(item_id,effect_time,active)
		sprite.position=art_origin+(sprite.texture.get_size()*sprite.scale*.5 if sprite.centered else Vector2.ZERO)
		sprite.rotation=roll_angle if item_id=="toy_ball" else 0
		if item_id=="toy_mouse" and roam_speed>0:
			sprite.position.y-=absf(sin(roam_time*11))*minf(.9,roam_speed/42.0)
		elif active and item_id in ["toy_ball","toy_mouse"]:
			sprite.position+=Vector2(sin(effect_time*3.2)*3,-absf(sin(effect_time*3.2))*3)
			sprite.rotation+=sin(effect_time*3.2)*.04
		elif (active or settle_time>0) and item_id=="toy_plush":
			var strength=1.0 if active else settle_time/.45
			sprite.rotation=sin(effect_time*3.0)*.035*strength
			sprite.position.y-=absf(sin(effect_time*3.0))*2*strength
		elif active and item_id=="alarm_clock" and effect_time<1.4:
			sprite.rotation=sin(effect_time*22)*.025
	if dragging and DisplayServer.get_name()!="headless":
		var still_down=bool(DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT)
		if still_down: move_dragged_to(Vector2(DisplayServer.mouse_get_position()))
		elif Time.get_ticks_msec()-pressed_at>100:
			# If release happened outside this native window, retain the last
			# position observed while held, not a later unrelated cursor position.
			dragging=false
			finish_drag()
	# Native window moves can raise a toy/furniture window without a click.
	# This covers falling arrivals, toy pursuit and drag movement alike.
	if visible and position!=last_layer_position:
		last_layer_position=position
		layer_changed.emit()
	update_input()

func ground_point() -> Vector2:
	return art_point(Vector2(.5,Catalog.ground_contact(sprite.texture)))
