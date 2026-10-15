extends Window
const NativeMouse=preload("res://scripts/native_mouse.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
class QuietView extends View:
	func prewarm_current_art() -> void: pass

var app
var input_bridge=preload("res://scripts/typing_input.gd").new()
var paused=false
var total=0
var pulse_age=1.0
var side=1.0
var pending=false
var root: Node2D
var pivot: Node2D
var view
var typing_sprite: Sprite2D
var typing_frames: Array[Texture2D]=[]
var typing_images: Array[Image]=[]
var typing_index=0
var hit_image: Image
var status: Label
var activity_detail: Label
var keys: Array[Panel]=[]
var input_lights: Array[StyleBoxFlat]=[]
var light_levels: Array[float]=[]
var light_index=-1
var corner_menu: PopupMenu
var size_menu: PopupMenu
var friend_menu: PopupMenu
var menu: PopupMenu
var screen_rect=Rect2i()
var check_screen=0.0

func _init() -> void:
	visible=false
	force_native=true
	borderless=true
	transparent=true
	transparent_bg=true
	always_on_top=true
	unfocusable=true
	unresizable=true
	title="복슬복슬펫 · 타자 모드"

func _ready() -> void:
	gui_embed_subwindows=false
	theme=app.app_theme
	root=Node2D.new()
	add_child(root)
	pivot=Node2D.new()
	root.add_child(pivot)
	var m=Motion.new()
	m.species=app.pet.species
	m.rabbit_pilot=m.species==0
	m.smooth_walk_enabled=m.species>0
	m.growth_stage=app.pet.motion.growth_stage
	m.growth_scale=app.pet.motion.growth_scale
	m.outfit_style=app.pet.motion.outfit_style
	m.outfit_color=app.pet.motion.outfit_color
	m.phase="idle"
	m.facing=1
	view=QuietView.new()
	view.motion=m
	pivot.add_child(view)
	view.position=-View.FEET
	view.refresh()
	hit_image=view.sprite.texture.get_image()
	var used=Vector2(hit_image.get_used_rect().size)*view.sprite.scale.abs()
	var readable=clampf(70.0/maxf(1.0,used.y),1.0,1.6)
	readable=minf(readable,154.0/maxf(1.0,used.x))
	pivot.scale=Vector2.ONE*readable
	# A fixed complete cel keeps silhouette, clothes and face stable on each tap.
	var board=Panel.new()
	board.position=Vector2(35,209)
	board.size=Vector2(150,36)
	board.add_theme_stylebox_override("panel",panel_style("ece6db",12))
	root.add_child(board)
	for i in range(8):
		var key=Panel.new()
		key.position=Vector2(44+i*16,217)
		key.size=Vector2(13,17)
		key.add_theme_stylebox_override("panel",panel_style("fffcf5",4))
		root.add_child(key)
		keys.append(key)
	var typing_art="res://assets/typing-rabbit-v1" if m.species==0 else "res://assets/typing-animals-v1/"+Catalog.IDS[m.species]
	if preload("res://scripts/asset_images.gd").exists(typing_art+"/idle.png"):
		for pose in ["idle","left","right"]:
			var cel=Image.new()
			if preload("res://scripts/asset_images.gd").decode_into(cel,typing_art+"/"+pose+".png")!=OK:
				typing_frames.clear()
				typing_images.clear()
				break
			if not typing_images.is_empty() and cel.get_size()!=typing_images[0].get_size():
				push_error("Typing animation canvas mismatch: "+typing_art+"/"+pose)
				typing_frames.clear()
				typing_images.clear()
				break
			typing_images.append(cel)
			typing_frames.append(ImageTexture.create_from_image(cel))
		if typing_frames.size()==3:
			view.hide()
			board.hide()
			for key in keys: key.hide()
			typing_sprite=Sprite2D.new()
			typing_sprite.centered=false
			typing_sprite.texture=typing_frames[0]
			typing_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			typing_sprite.position=Vector2(10,57)
			typing_sprite.scale=Vector2.ONE*(200.0/typing_images[0].get_width())
			root.add_child(typing_sprite)
	var stats_panel=Panel.new()
	stats_panel.position=Vector2(14,4)
	stats_panel.size=Vector2(192,50)
	stats_panel.add_theme_stylebox_override("panel",panel_style("f5f0e7",12))
	stats_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(stats_panel)
	status=Label.new()
	status.position=Vector2(24,6)
	status.size=Vector2(146,25)
	status.add_theme_font_size_override("font_size",17)
	status.add_theme_color_override("font_color",Color("6d7665"))
	status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(status)
	activity_detail=Label.new()
	activity_detail.position=Vector2(24,32)
	activity_detail.size=Vector2(174,18)
	activity_detail.add_theme_font_size_override("font_size",10)
	activity_detail.add_theme_color_override("font_color",Color("77746c"))
	activity_detail.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	activity_detail.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(activity_detail)
	var settings=Button.new()
	settings.text="···"
	settings.add_theme_stylebox_override("normal",panel_style("ece6db",8))
	settings.add_theme_stylebox_override("hover",panel_style("dce5d2",8))
	settings.add_theme_stylebox_override("pressed",panel_style("cbd9c0",8))
	settings.add_theme_color_override("font_color",Color("6d7665"))
	settings.position=Vector2(176,7)
	settings.size=Vector2(28,28)
	settings.focus_mode=Control.FOCUS_NONE
	settings.tooltip_text="데스크톱 펫 모드 · 위치 · 크기 · 입력 일시정지"
	settings.pressed.connect(open_menu)
	root.add_child(settings)
	var light_tray=Panel.new()
	light_tray.position=Vector2(22,254)
	light_tray.size=Vector2(176,28)
	light_tray.add_theme_stylebox_override("panel",panel_style("f5f0e7",8))
	light_tray.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(light_tray)
	for i in range(8):
		var light=Panel.new()
		light.position=Vector2(32+i*20,260)
		light.size=Vector2(16,16)
		light.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var style=panel_style("e4e2d8",3)
		style.set_border_width_all(1)
		style.border_color=Color("d3d5c8")
		style.shadow_size=3
		style.shadow_color=Color(0.6,0.76,0.42,0)
		light.add_theme_stylebox_override("panel",style)
		root.add_child(light)
		input_lights.append(style)
		light_levels.append(0.0)
	menu=PopupMenu.new()
	menu.id_pressed.connect(menu_action)
	add_child(menu)
	corner_menu=PopupMenu.new()
	corner_menu.name="Corners"
	size_menu=PopupMenu.new()
	size_menu.name="Sizes"
	friend_menu=PopupMenu.new()
	friend_menu.name="Friends"
	for submenu in [corner_menu,size_menu,friend_menu]:
		submenu.id_pressed.connect(menu_action)
		menu.add_child(submenu)
	window_input.connect(on_input)
	close_requested.connect(func(): app.set_play_mode("living"))
	place()
	show()
	input_bridge.start()
	NativeMouse.apply(self,false,true)

static func panel_style(color: String,radius: int) -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=Color(color)
	style.set_corner_radius_all(radius)
	return style

func place() -> void:
	screen_rect=app.usable_screen()
	var zoom=[.85,1.0,1.2][app.state.typing_size]
	root.scale=Vector2.ONE*zoom
	size=Vector2i(Vector2(220,288)*zoom)
	var corner=app.state.typing_corner
	position=screen_rect.position+Vector2i(12,12)
	if corner in [1,3]: position.x=screen_rect.end.x-size.x-12
	if corner in [2,3]: position.y=screen_rect.end.y-size.y-12
	position=position.clamp(screen_rect.position,(screen_rect.end-size).max(screen_rect.position))

func _process(delta: float) -> void:
	var presses=input_bridge.poll() if not paused else 0
	app.typing_activity.update(Time.get_ticks_msec(),presses,not paused and input_bridge.connected)
	total=app.typing_activity.total
	if presses>0: pending=true
	# Do not reset the pose on every fast keystroke: complete each short beat.
	pulse_age+=delta
	if pending and pulse_age>=.22:
		pending=false
		pulse_age=0
		side=-side
	var beat=sin(clampf(pulse_age/.22,0,1)*PI)
	pivot.position=Vector2(110+side*beat*.7,216+beat*2.2)
	pivot.rotation=side*beat*.018
	for i in range(keys.size()):
		keys[i].modulate=Color("bbccb1") if beat>.1 and i==(2 if side<0 else 5) else Color.WHITE
	refresh_activity_display()
	update_input_lights(delta,presses)
	if typing_sprite:
		# Complete generated cels: the keyboard and head stay anchored; only paws change.
		typing_index=(1 if side<0 else 2) if pulse_age<.17 else 0
		typing_sprite.texture=typing_frames[typing_index]
	var point=(Vector2(DisplayServer.mouse_get_position()-position))/root.scale
	var visible_sprite=typing_sprite if typing_sprite else view.sprite
	var active_image=typing_images[typing_index] if typing_sprite else hit_image
	var rect=visible_sprite.get_rect()
	var local=visible_sprite.get_global_transform().affine_inverse()*(Vector2(DisplayServer.mouse_get_position()-position))
	var on_pet=rect.has_point(local) and active_image.get_pixelv(Vector2i(local)).a>.1
	var hits=on_pet or Rect2(14,4,192,50).has_point(point) or menu.visible
	NativeMouse.apply(self,not hits)
	check_screen+=delta
	if check_screen>1:
		check_screen=0
		if screen_rect!=app.usable_screen(): place()

func update_input_lights(delta: float, presses: int) -> void:
	for i in range(light_levels.size()):
		light_levels[i]=maxf(0.0,light_levels[i]-delta/.32)
	# Light feedback follows input immediately, independently of the paw animation beat.
	for _press in range(mini(presses,input_lights.size())):
		light_index=(light_index+1)%input_lights.size()
		light_levels[light_index]=1.0
	for i in range(input_lights.size()):
		input_lights[i].bg_color=Color("e4e2d8").lerp(Color("b8d58a"),light_levels[i])
		input_lights[i].border_color=Color("d3d5c8").lerp(Color("8eac67"),light_levels[i])
		input_lights[i].shadow_color=Color(.6,.76,.42,light_levels[i]*.35)

func refresh_activity_display() -> void:
	status.text="APM %d"%app.typing_activity.apm if input_bridge.connected and not paused else "APM —"
	if paused:
		activity_detail.text="잠시 쉬는 중 · 활동 "+app.typing_activity.time_text()
	elif not input_bridge.connected:
		activity_detail.text="연결 끊김 · 메뉴에서 다시 시작" if not input_bridge.error.is_empty() else "입력 연결 중…"
	else:
		activity_detail.text="활동 %s · %s회"%[app.typing_activity.time_text(),compact_count(total)]

static func compact_count(value: int) -> String:
	if value>=100000000: return "%.1f억"%(value/100000000.0)
	if value>=10000: return "%.1f만"%(value/10000.0)
	return str(value)

func on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT: open_menu()

func open_menu() -> void:
	menu.clear()
	corner_menu.clear()
	size_menu.clear()
	friend_menu.clear()
	menu.add_item("데스크톱 펫 모드로 돌아가기",0)
	menu.add_item("입력 반응 다시 시작" if paused or not input_bridge.connected else "입력 반응 일시정지",1)
	menu.add_separator()
	menu.add_submenu_item("화면 구석", "Corners")
	for i in range(4):
		corner_menu.add_check_item(["왼쪽 위","오른쪽 위","왼쪽 아래","오른쪽 아래"][i],10+i)
		corner_menu.set_item_checked(corner_menu.item_count-1,i==app.state.typing_corner)
	menu.add_submenu_item("크기", "Sizes")
	for i in range(3):
		size_menu.add_check_item(["작게","보통","크게"][i],20+i)
		size_menu.set_item_checked(size_menu.item_count-1,i==app.state.typing_size)
	menu.add_submenu_item("친구 바꾸기", "Friends")
	for i in range(Catalog.IDS.size()):
		if is_instance_valid(app.commerce_access) and not app.commerce_access.permits(i): continue
		friend_menu.add_check_item(Catalog.NAMES[i],100+i)
		friend_menu.set_item_checked(friend_menu.item_count-1,i==app.state.selected)
	menu.add_separator()
	menu.add_item("실시간 APM · 최근 3초 속도 × 20",90)
	menu.set_item_disabled(menu.item_count-1,true)
	menu.add_item("활동 시간 · 30초 무입력부터 제외",91)
	menu.set_item_disabled(menu.item_count-1,true)
	menu.add_item("이번 실행의 누적 · %d회"%app.typing_activity.total,92)
	menu.set_item_disabled(menu.item_count-1,true)
	menu.add_item("오늘은 안녕",99)
	menu.position=DisplayServer.mouse_get_position()
	menu.popup()

func menu_action(id: int) -> void:
	if id==0: app.set_play_mode("living")
	elif id==1:
		app.typing_activity.suspend(Time.get_ticks_msec())
		if paused or not input_bridge.connected:
			paused=false
			input_bridge.start()
		else:
			paused=true
			input_bridge.stop()
		pending=false
	elif id==99: app.shutdown()
	elif id>=100:
		app.choose_friend.call_deferred(id-100)
	elif id>=10 and id<14:
		app.state.typing_corner=id-10
		place()
		app.state.save_game()
	elif id>=20 and id<23:
		app.state.typing_size=id-20
		place()
		app.state.save_game()

func _exit_tree() -> void:
	input_bridge.stop()
