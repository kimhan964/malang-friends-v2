extends Node
## Uses the real native pet, movement, input and prop windows with isolated saves.
const Main=preload("res://scripts/main.gd")
const State=preload("res://scripts/pet_state.gd")
var app
var controls: Window
var label: Label
var baby=false
var pilot=true
var looping=true
var wait_left=0.0
var capture_left=0.0
var capture_time=0.0
var capture_age=0.0
var capture_count=0
var capture_stage="adult"
var captures=[]
var pending_action=""
var capture_action="walk"

class PilotState extends State:
	func load_game() -> void:
		guide_seen=true
		selected=0
		for i in range(16):
			growth[str(i)]=36
			play_affection[str(i)]=70
	func save_game() -> void: pass
	func reward_activity(_species: int,_action: String) -> void: pass

func _ready() -> void:
	preload("res://scripts/rabbit_pilot_art.gd").select_version(9)
	app=Main.new()
	app.rabbit_pilot_mode=pilot
	app.state=PilotState.new()
	add_child(app)
	controls=Window.new()
	controls.visible=false
	controls.force_native=true
	controls.title="토끼 · 낮은 통통걸음과 행동 시범"
	controls.size=Vector2i(660,255)
	controls.position=DisplayServer.screen_get_usable_rect().position+Vector2i(40,40)
	controls.always_on_top=true
	controls.close_requested.connect(func(): get_tree().quit())
	add_child(controls)
	var font=SystemFont.new()
	font.font_names=PackedStringArray(["Malgun Gothic"])
	controls.theme=Theme.new()
	controls.theme.default_font=font
	controls.theme.default_font_size=16
	controls.transparent_bg=false
	var background=ColorRect.new()
	background.color=Color("fff8ed")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	controls.add_child(background)
	controls.theme.set_color("font_color","Label",Color("523727"))
	for kind in ["normal","hover","pressed","focus"]:
		var style=StyleBoxFlat.new()
		style.bg_color=Color("cbd5a8" if kind=="pressed" else ("f2e9ce" if kind=="hover" else "fcf4df"))
		style.set_corner_radius_all(7)
		style.set_border_width_all(1)
		style.border_color=Color("d7c8a7")
		style.content_margin_left=10
		style.content_margin_right=10
		style.content_margin_top=5
		style.content_margin_bottom=5
		controls.theme.set_stylebox(kind,"Button",style)
	for kind in ["font_color","font_hover_color","font_pressed_color"]: controls.theme.set_color(kind,"Button",Color("523727"))
	var column=VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation",12)
	controls.add_child(column)
	label=Label.new()
	column.add_child(label)
	var ages=HBoxContainer.new()
	column.add_child(ages)
	var baby_button=add_button(ages,"새끼 토끼",func(): baby=true; select_stage())
	baby_button.disabled=not preload("res://scripts/rabbit_pilot_art.gd").data().stages.has("baby")
	add_button(ages,"성체 토끼",func(): baby=false; select_stage())
	var expanded_button=add_button(ages,"새 행동 60장",func(): preload("res://scripts/rabbit_pilot_art.gd").select_version(9); pilot=true; select_stage())
	expanded_button.disabled=not FileAccess.file_exists("res://assets/rabbit-frame-pilot-v9/manifest.json")
	add_button(ages,"승인된 걷기",func(): preload("res://scripts/rabbit_pilot_art.gd").select_version(8); pilot=true; select_stage())
	add_button(ages,"기존 걷기 비교",func(): pilot=false; select_stage())
	var actions=HBoxContainer.new()
	column.add_child(actions)
	add_button(actions,"걷기 반복",func(): looping=true; start_walk())
	add_button(actions,"멈추기",stop_walk)
	add_button(actions,"실제 걷기 기록",start_capture)
	var other_actions=HBoxContainer.new()
	column.add_child(other_actions)
	add_button(other_actions,"대기 · 눈깜빡임",func(): request_action("idle"))
	add_button(other_actions,"당근 먹기",func(): request_action("eat"))
	add_button(other_actions,"연못 물 마시기",func(): request_action("drink"))
	var hint=Label.new()
	hint.text="깡총걸음 1.5초 · 점프 높이만 조금 낮췄어요.\n다른 행동은 착지한 뒤 시작하고, 끝나면 기본 자세로 돌아와요."
	column.add_child(hint)
	controls.show()
	select_stage()
	if OS.get_cmdline_user_args().has("--capture-pilot"): start_capture()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-action="): start_action_capture(argument.trim_prefix("--capture-action="))

func add_button(row: HBoxContainer,text: String,callback: Callable) -> Button:
	var button=Button.new()
	button.text=text
	button.pressed.connect(callback)
	row.add_child(button)
	return button

func select_stage() -> void:
	app.state.growth["0"]=0 if baby else 36
	app.rabbit_pilot_mode=pilot
	app.choose_friend(0)
	var m=app.pet.motion
	m.rabbit_pilot=pilot
	m.autonomy=false
	m.resting=true
	m.joy_left=0
	m.voice_left=0
	m.outfit_style=0
	app.pet.view.warmed_art=""
	app.pet.view.prewarm_current_art()
	var usable=DisplayServer.screen_get_usable_rect()
	m.move_to(Vector2(usable.position)+Vector2(usable.size.x*.45,usable.size.y*.58))
	app.pet.title="[토끼 시범] "+("새끼" if baby else "성체")+" · "+("새 걷기" if pilot else "기존 걷기")
	var count=int(preload("res://scripts/rabbit_pilot_art.gd").data().stages["baby" if baby else "adult"].sequences.walk.count)
	label.text=("새끼 토끼" if baby else "성체 토끼")+" · "+("전신 %d프레임 · 낮은 통통걸음"%count if pilot else "기존 걷기")
	if looping: start_walk()
	app.pet.view.position=m.feet-app.pet.view.FEET-Vector2(app.pet.position) if pilot else Vector2.ZERO
	app.pet.view.refresh()

func start_walk() -> void:
	pending_action=""
	var m=app.pet.motion
	if pilot and m.pilot_hop.active: return
	m.cancel_play()
	m.phase="wander"
	m.resting=true
	m.joy_left=0
	m.pilot_was_traveling=false
	m.pilot_settle_left=0
	m.travel_speed=0
	var direction=-m.facing
	if wait_left==0: direction=1
	var half_stride=pilot_stride_pixels() if pilot else 20.0
	var distance=ceilf(72.0/half_stride)*half_stride
	m.target=(m.feet+Vector2(distance*direction,0)).clamp(m.bounds.position,m.bounds.end)
	wait_left=0

func request_action(action: String) -> void:
	preload("res://scripts/rabbit_pilot_art.gd").select_version(9)
	app.pet.motion.rabbit_pilot=true
	pilot=true
	app.pet.view.warmed_art=""
	app.pet.view.prewarm_current_art()
	pending_action=action
	stop_walk()

func begin_action(action: String) -> void:
	var m=app.pet.motion
	m.cancel_play()
	m.pilot_hop.reset()
	m.walk_phase=0
	m.pilot_settle_left=0
	m.pilot_start_left=0
	m.elapsed=0
	m.joy_left=0
	m.voice_left=0
	m.facing=1
	m.phase=action
	m.action_left=5.5
	if action=="eat": m.food_id=0
	m.visit_id="water" if action=="drink" else ""
	m.visit_reward=false
	if action=="drink" and app.props.has("water"):
		var pond=app.props.water
		pond.confirm_drop()
		pond.position=Vector2i(m.feet+Vector2(68,5)-pond.anchor_offset())
		pond.show()
	label.text="성체 토끼 · "+{"idle":"대기 · 부드러운 눈깜빡임","eat":"작은 당근 한입 먹기","drink":"연못에 숙여 물 마시기"}.get(action,action)

func stop_walk() -> void:
	looping=false
	var m=app.pet.motion
	if m.phase=="idle": return
	if pilot:
		m.target=m.pilot_hop.destination if m.pilot_hop.active else m.feet
		return
	# Brake through the usual travel path before collecting the feet.
	var distance=maxf(2,m.travel_speed*.28)
	m.target=m.feet+Vector2(m.facing*distance,0)
	m.phase="wander"

func pilot_stride_pixels() -> float:
	var m=app.pet.motion
	var spec=preload("res://scripts/rabbit_pilot_art.gd").data().stages["baby" if baby else "adult"]
	var art=preload("res://scripts/animal_catalog.gd")
	return m.pilot_hop.stride_length(m,spec)

func _process(delta: float) -> void:
	if not is_instance_valid(app) or not is_instance_valid(app.pet): return
	var m=app.pet.motion
	if not pending_action.is_empty() and m.phase=="idle" and not m.pilot_hop.active:
		var action=pending_action
		pending_action=""
		begin_action(action)
	if looping and m.phase=="idle" and not m.held and not m.carried:
		wait_left+=delta
		if wait_left>1.8:
			start_walk()
	if capture_left>0:
		capture_left-=delta
		capture_age+=delta
		capture_time+=delta
		var capture_interval=1.0/60.0 if int(preload("res://scripts/rabbit_pilot_art.gd").data().version)>=6 else .08
		if capture_time>=capture_interval:
			capture_time=fmod(capture_time,capture_interval)
			capture_frame()
		if capture_stage=="adult" and capture_left<12 and preload("res://scripts/rabbit_pilot_art.gd").data().stages.has("baby"):
			capture_stage="baby"
			baby=true
			select_stage()
		if capture_left<=0:
			var file=FileAccess.open(ProjectSettings.globalize_path("res://")+"rabbit-frame-playback-report.json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"native_game_windows":true,"asset_version":preload("res://scripts/rabbit_pilot_art.gd").data().version,"action":capture_action,"seconds":capture_age,"captures":captures},"\t"))
			print("PILOT_NATIVE_CAPTURE_DONE ",captures.size())

func start_capture() -> void:
	preload("res://scripts/rabbit_pilot_art.gd").select_version(9)
	capture_action="walk"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://")+"rabbit-frame-playback")
	pilot=true
	baby=false
	looping=true
	capture_stage="adult"
	capture_left=24 if preload("res://scripts/rabbit_pilot_art.gd").data().stages.has("baby") else 12
	capture_age=0
	capture_count=0
	captures=[]
	select_stage()

func start_action_capture(action: String) -> void:
	if action not in ["idle","eat","drink"]: return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://")+"rabbit-frame-playback")
	looping=false
	capture_left=0
	select_stage()
	# Let native windows and uploaded textures settle before measuring playback.
	await get_tree().create_timer(.7).timeout
	capture_action=action
	capture_stage="adult"
	capture_left=6.2
	capture_age=0
	capture_count=0
	captures=[]
	begin_action(action)

func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	if not is_instance_valid(app.pet): return
	var filename="rabbit-frame-playback/%04d.png"%capture_count
	var image=app.pet.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://")+filename)
	if capture_action=="drink" and app.props.has("water") and capture_count==0:
		app.props.water.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://")+"rabbit-frame-playback/pond.png")
	var m=app.pet.motion
	var sample=app.pet.view.generated_sample
	var local_root=m.feet-Vector2(app.pet.position)
	var pond_origin=app.props.water.position if app.props.has("water") else Vector2i.ZERO
	captures.append({"file":filename,"time":capture_age,"stage":capture_stage,"feet":[m.feet.x,m.feet.y],"window_origin":[app.pet.position.x,app.pet.position.y],"pond_origin":[pond_origin.x,pond_origin.y],"local_root":[local_root.x,local_root.y],"phase":m.phase,"speed":m.travel_speed,"gait":m.walk_phase,"bank":sample.get("bank","legacy"),"index":sample.index,"scale":[app.pet.view.sprite.scale.x,app.pet.view.sprite.scale.y]})
	capture_count+=1
