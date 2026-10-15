extends Node
const Main=preload("res://scripts/main.gd")
const State=preload("res://scripts/pet_state.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
const Smooth=preload("res://scripts/smooth_species_art.gd")
var app
var controls: Window
var label: Label
var picker: OptionButton
var selected=1
var baby=false
var modern=true
var looping=true
var free_play=false
var rest_age=0.0
var direction=1
var capture_running=false
var capture_frames=[]
var capture_results=[]
var capture_enabled=false
var capture_age=0.0
var capture_timer=0.0
var capture_index=0
var capture_images=[]
var trial_version=5
var capture_folder="walk-native"
var review_stride_fraction=3.0
var capture_interval=1.0/60.0
var capture_prop=""
var capture_legacy_walks=false
var dining_review
var hold_review

class PreviewState extends State:
	func load_game() -> void:
		guide_seen=true
		selected=1
		for i in range(16):
			growth[str(i)]=36
			play_affection[str(i)]=70
		if FileAccess.file_exists("user://interior-layout.json"):
			var data=JSON.parse_string(FileAccess.get_file_as_string("user://interior-layout.json"))
			if data is Dictionary:
				load_furniture(data.get("furniture",data))
				activity_space=preload("res://scripts/living_space.gd").clean(data.get("activity_space"))
	func save_game() -> void:
		# Preview progress is still isolated; only the user's furniture persists.
		var file=FileAccess.open("user://interior-layout.json.tmp",FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify({"version":2,"furniture":furniture,"activity_space":activity_space}))
			file.close()
			DirAccess.rename_absolute("user://interior-layout.json.tmp","user://interior-layout.json")
	func reward_activity(_species: int,_action: String) -> void: pass

func _ready() -> void:
	free_play=OS.get_cmdline_user_args().has("--free-play")
	if free_play: looping=false
	capture_legacy_walks=OS.get_cmdline_user_args().has("--capture-legacy-walks")
	trial_version=int(ProjectSettings.get_setting("testing/walk_trial_version",5))
	if OS.get_cmdline_user_args().has("--walk-v6"): trial_version=6
	if OS.get_cmdline_user_args().has("--walk-v7"): trial_version=7
	if OS.get_cmdline_user_args().has("--walk-v8"): trial_version=8
	if OS.get_cmdline_user_args().has("--walk-v10"): trial_version=10
	if OS.get_cmdline_user_args().has("--walk-v11"): trial_version=11
	if OS.get_cmdline_user_args().has("--walk-v12"): trial_version=12
	if OS.get_cmdline_user_args().has("--walk-v13"): trial_version=13
	if OS.get_cmdline_user_args().has("--walk-v14"): trial_version=14
	if trial_version>=12: selected=2
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--species="):
			selected=clampi(int(argument.trim_prefix("--species=")),0,15)
		if argument.begins_with("--capture-stride-fraction="):
			review_stride_fraction=clampf(float(argument.trim_prefix("--capture-stride-fraction=")),.05,3.0)
	Smooth.select_version(trial_version)
	preload("res://scripts/rabbit_pilot_art.gd").select_version(9)
	app=Main.new()
	app.state=PreviewState.new()
	add_child(app)
	# Main runs the package audit instead of creating props in this mode.
	# Do not start the interactive preview against that intentionally empty world.
	if OS.get_cmdline_user_args().has("--check-package"): return
	app.friend_changed.connect(on_friend_changed)
	controls=Window.new()
	controls.visible=false
	controls.force_native=true
	controls.title="복슬복슬펫 · 동물별 부드러운 걷기"
	if trial_version>=7: controls.title="복슬복슬펫 · 수달 발걸음 수정 시범"
	if trial_version>=11: controls.title="복슬복슬펫 · 수달 새끼·성체 걷기 시범"
	if trial_version>=12: controls.title="복슬복슬펫 · 전체 동물 걷기 점검"
	controls.size=Vector2i(610,214) if free_play else Vector2i(650,320)
	if free_play: controls.title="복슬복슬펫 · 함께하는 하루"
	controls.position=DisplayServer.screen_get_usable_rect().position+Vector2i(40,40)
	controls.always_on_top=true
	controls.close_requested.connect(func(): get_tree().quit())
	add_child(controls)
	var font=SystemFont.new()
	font.font_names=PackedStringArray(["Malgun Gothic"])
	controls.theme=preload("res://scripts/cozy_ui.gd").theme()
	controls.theme.default_font=font
	controls.theme.default_font_size=14
	var bg=ColorRect.new()
	bg.color=Color("faf8f3")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	controls.add_child(bg)
	var column=VBoxContainer.new()
	column.position=Vector2(12,12)
	column.add_theme_constant_override("separation",12)
	controls.add_child(column)
	label=Label.new()
	label.add_theme_color_override("font_color",Color("513a29"))
	column.add_child(label)
	var ages=HBoxContainer.new()
	column.add_child(ages)
	picker=OptionButton.new()
	for i in range(Catalog.NAMES.size()):
		var stages: Dictionary=Smooth.data(i).get("stages",{})
		var stage_note=""
		if trial_version>=12:
			if i==0: stage_note=" · 새끼·성체 깡총걸음"
			elif stages.is_empty(): stage_note=" · 새 걷기 준비 중"
			elif not stages.has("baby"): stage_note=" · 성체 새 걷기"
			elif not stages.has("adult"): stage_note=" · 새끼 새 걷기"
		picker.add_item(Catalog.NAMES[i] if free_play else Catalog.NAMES[i]+stage_note)
	picker.select(selected)
	picker.disabled=trial_version>=7 and trial_version<12
	picker.item_selected.connect(func(i): selected=i; select_pet())
	ages.add_child(picker)
	if trial_version<7 or trial_version>=11:
		button(ages,"새끼",func(): baby=true;select_pet())
		button(ages,"성체",func(): baby=false;select_pet())
	var actions=HBoxContainer.new()
	column.add_child(actions)
	button(actions,"새 걷기 60장",func(): modern=true;select_pet())
	button(actions,"이전 수달 시범" if trial_version>=7 and trial_version<12 else "이전 걷기 비교",func(): modern=false;select_pet())
	button(actions,"걷기 반복",func():looping=true;start_walk())
	button(actions,"멈추기",stop_walk)
	if trial_version>=12:
		button(actions,"물 마시기",func():start_dining("water"))
		button(actions,"먹기",func():start_dining("bowl"))
	var play_actions=HBoxContainer.new()
	column.add_child(play_actions)
	button(play_actions,"자유롭게 지내기",start_free_play)
	button(play_actions,"내 공간",func(): app.activity(32))
	button(play_actions,"함께하기",func(): app.pet.menu.section=0; app.pet.open_menu())
	button(play_actions,"성장·선물",func(): app.pet.menu.section=3; app.pet.open_menu())
	var hint=Label.new()
	hint.text="동물과 나이를 골라 확인하세요. 새끼·성체는 같은 색을 기준으로 제작했어요.\n저장된 성장·해금 기록에 영향을 주지 않는 동작 확인판입니다."
	if trial_version>=7: hint.text="수달 성체의 짧은 발걸음 수정 시범입니다.\n새 걷기와 이전 수달 시범을 같은 화면에서 비교할 수 있어요."
	if trial_version>=11: hint.text="같은 색과 통통한 체형으로 만든 새끼·성체 수달입니다.\n나이를 골라 걷기와 정지 자세를 확인하세요."
	if trial_version>=12: hint.text="동물과 나이를 골라 걷기·정지를 확인하세요.\n준비 중인 동물은 기존 모습을 보여 줍니다."
	if trial_version>=14: hint.text="16종 모두 새 걷기를 적용했어요. 토끼는 깡총걸음이에요.\n동물과 나이를 골라 걷기·정지를 확인하세요."
	hint.add_theme_color_override("font_color",Color("715b49"))
	column.add_child(hint)
	actions.visible=not free_play
	hint.visible=not free_play
	for i in range(1,ages.get_child_count()): ages.get_child(i).visible=not free_play
	var more=HBoxContainer.new()
	column.add_child(more)
	button(more,"동작 점검 ▾",func():
		actions.visible=not actions.visible
		hint.visible=actions.visible
		for i in range(1,ages.get_child_count()): ages.get_child(i).visible=actions.visible
		controls.size=Vector2i(650,320) if actions.visible else Vector2i(610,214))
	var preview_note=Label.new()
	preview_note.text="미리보기 · 모든 생활 이용 가능"
	preview_note.add_theme_font_size_override("font_size",12)
	preview_note.add_theme_color_override("font_color",Color("817d73"))
	more.add_child(preview_note)
	controls.show()
	select_pet()
	if OS.get_cmdline_user_args().has("--capture-holds"):
		hold_review=preload("res://scripts/hold_motion_review.gd").new()
		hold_review.run.call_deferred(self)
	elif OS.get_cmdline_user_args().has("--capture-walks"): capture_all.call_deferred()
	elif OS.get_cmdline_user_args().has("--capture-dining"):
		dining_review=preload("res://scripts/dining_motion_review.gd").new()
		dining_review.run.call_deferred(self)

func button(row: HBoxContainer,text: String,callback: Callable) -> void:
	var b=Button.new()
	b.text=text
	b.pressed.connect(callback)
	row.add_child(b)

func on_friend_changed(species: int) -> void:
	# The pet's own right-click menu must update this preview too.
	if species==selected: return
	selected=species
	baby=app.state.growth_stage(species)==0
	select_pet.call_deferred()

func select_pet() -> void:
	if trial_version>=7 and trial_version<12:
		selected=1
		if trial_version<11: baby=false
		var previous_version=(5 if baby else 10) if trial_version>=11 else 6
		Smooth.select_version(trial_version if modern else previous_version)
	elif trial_version>=12:
		Smooth.select_version(trial_version if modern else 5)
	app.state.growth[str(selected)]=0 if baby else 36
	# Remember the selected playback mode, not the previously selected animal.
	app.rabbit_pilot_mode=modern
	app.choose_friend(selected)
	var m=app.pet.motion
	m.cancel_play()
	m.autonomy=false
	m.resting=true
	m.joy_left=0
	m.voice_left=0
	if not free_play: m.outfit_style=0
	m.smooth_walk_enabled=modern or trial_version>=7
	if selected==14 and not modern: m.smooth_walk_enabled=false
	if capture_legacy_walks:
		m.smooth_walk_enabled=false
		m.rabbit_pilot=false
	# Keep DesktopPet's stationary transparent canvas in the preview too.
	m.elapsed=0
	m.walk_phase=0
	app.pet.view.warmed_art=""
	app.pet.view.prewarm_current_art()
	var usable=DisplayServer.screen_get_usable_rect()
	m.move_to(Vector2(usable.position)+Vector2(usable.size.x*.45,usable.size.y*.58))
	app.pet.title=Catalog.NAMES[selected]+" · "+("새끼" if baby else "성체")+" 걷기 확인"
	label.text=Catalog.NAMES[selected]+" · "+("새끼" if baby else "성체")+" · "+("새 전신 60프레임" if Smooth.enabled(m) or m.rabbit_pilot else "기존 동작")
	if trial_version>=7: label.text="수달 성체 · "+("짧은 보폭 수정 시범" if modern else "이전 시범 · 발 교차 비교")
	if trial_version>=11: label.text="수달 "+("새끼" if baby else "성체")+" · "+("통통걸음 60프레임" if modern else "이전 걷기 비교")
	if trial_version>=12: label.text=Catalog.NAMES[selected]+" · "+("새끼" if baby else "성체")+" · "+("새 걷기 60프레임" if (modern and (Smooth.enabled(m) or m.rabbit_pilot)) else "기존 걷기")
	picker.select(selected)
	rest_age=0
	if free_play: start_free_play()
	elif looping: start_walk()

func start_free_play() -> void:
	free_play=true
	looping=false
	var m=app.pet.motion
	m.cancel_play()
	m.autonomy=true
	m.resting=false
	m.rest_left=.8
	m.tool_interest_left=5.0
	app.queue_welcome_tools()
	label.text=Catalog.NAMES[selected]+"  ·  오늘도 함께해요"

func start_walk() -> void:
	free_play=false
	var m=app.pet.motion
	m.autonomy=false
	if m.smooth_walk_cycle.active or m.pilot_hop.active: return
	m.cancel_play()
	m.phase="wander"
	m.resting=true
	m.joy_left=0
	m.travel_speed=0
	var stride=24.0
	if Smooth.enabled(m): stride=float(Smooth.spec(m).stride)*110*Catalog.HEIGHTS[selected]*m.growth_scale/float(Smooth.spec(m).reference_height)
	elif m.rabbit_pilot:
		var hop=preload("res://scripts/rabbit_pilot_art.gd").data().stages["baby" if baby else "adult"]
		stride=m.pilot_hop.stride_length(m,hop)
	else:
		var nominal=m.SPEEDS[selected]*lerpf(.72,1.0,clampf(inverse_lerp(.62,1.0,m.growth_scale),0,1))
		stride=maxf(16.0,nominal*preload("res://scripts/gait_profile.gd").STRIDE_PERIOD[selected])
	var distance=stride*review_stride_fraction
	# The interactive rabbit preview needs visible desktop travel, not a tiny
	# three-hop oscillation. Capture tools retain their requested stride length.
	if m.rabbit_pilot and not capture_running: distance=maxf(160.0,distance)
	m.target=(m.feet+Vector2(direction*distance,0)).clamp(m.bounds.position,m.bounds.end)
	direction=-direction
	rest_age=0

func stop_walk() -> void:
	free_play=false
	looping=false
	var m=app.pet.motion
	m.autonomy=false
	m.resting=true
	m.target=m.smooth_walk_cycle.destination if m.smooth_walk_cycle.active else (m.pilot_hop.destination if m.pilot_hop.active else m.feet)

func start_dining(id: String) -> void:
	if capture_running: return
	stop_walk()
	if is_instance_valid(app.furniture_room) and app.furniture_room.pieces.has("table"):
		app.furniture_room.use_piece("table","drink" if id=="water" else "eat")
		return
	var m=app.pet.motion
	while m.smooth_walk_cycle.active or m.pilot_hop.active:
		await get_tree().process_frame
		if m!=app.pet.motion: return
	var prop=app.props[id]
	var stride=16.0
	if Smooth.enabled(m): stride=m.smooth_walk_cycle.stride_length(m,Smooth.spec(m))
	var desired=(m.feet+Vector2(stride*1.25,0)).clamp(m.bounds.position,m.bounds.end)
	prop.position+=Vector2i(desired-app.pet_dining_point(prop))
	prop.show()
	m.visit(app.pet_dining_point(prop),"drink" if id=="water" else "eat",id)

func _process(delta: float) -> void:
	if not is_instance_valid(app) or not is_instance_valid(app.pet): return
	var m=app.pet.motion
	if looping and not capture_running and m.phase=="idle" and not m.held:
		rest_age+=delta
		if rest_age>1.3: start_walk()
	if capture_enabled:
		capture_age+=delta
		capture_timer+=delta
		if capture_timer>=capture_interval:
			capture_timer=fmod(capture_timer,capture_interval)
			capture_frame()

func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	if not capture_enabled: return
	var m=app.pet.motion
	var sample=app.pet.view.generated_sample
	var name="%s/%s-%s-%04d.png"%[capture_folder,Catalog.IDS[selected],"baby" if baby else "adult",capture_index]
	var image=app.pet.get_texture().get_image()
	capture_images.append({"image":image,"file":name})
	var record={"file":name,"time":capture_age,"index":sample.index,"action":sample.action,"bank":sample.get("bank","legacy"),"scale":[app.pet.view.sprite.scale.x,app.pet.view.sprite.scale.y],"feet":[m.feet.x,m.feet.y],"window":[app.pet.position.x,app.pet.position.y],"speed":m.travel_speed,"phase":m.phase,"cycle_phase":m.walk_phase,"stride_active":m.smooth_walk_cycle.active}
	if capture_legacy_walks: record.bank="walk" if sample.action=="walk" else sample.action
	if not capture_prop.is_empty():
		var prop=app.props[capture_prop]
		var prop_name=name.trim_suffix(".png")+"-prop.png"
		capture_images.append({"image":prop.get_texture().get_image(),"file":prop_name})
		var mouth=m.feet+app.pet.view.mouth_offset()
		record.merge({"prop_file":prop_name,"prop_window":[prop.position.x,prop.position.y],"prop_anchor":[prop.feet_point().x,prop.feet_point().y],"mouth_world":[mouth.x,mouth.y],"target":[m.target.x,m.target.y],"action_elapsed":m.elapsed,"rotation":app.pet.view.sprite.rotation})
	capture_frames.append(record)
	capture_index+=1

func capture_all() -> void:
	var return_species=selected
	var requested_direction=0
	var include_stop=OS.get_cmdline_user_args().has("--capture-transitions")
	if include_stop: capture_folder="walk-native-transitions"
	if review_stride_fraction!=3.0: capture_folder="walk-native-short-stride-%03d"%roundi(review_stride_fraction*100)
	if OS.get_cmdline_user_args().has("--capture-arrival-review"): capture_folder+="-arrival"
	var species_filter: Array[int]=[]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-direction="):
			requested_direction=clampi(int(argument.trim_prefix("--capture-direction=")),-1,1)
		if argument.begins_with("--capture-output="):
			var folder_name=argument.trim_prefix("--capture-output=")
			if folder_name.is_valid_filename(): capture_folder=folder_name
		if argument.begins_with("--capture-species="):
			for value in argument.trim_prefix("--capture-species=").split(","):
				species_filter.append(int(value))
	capture_running=true
	looping=false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://")+capture_folder)
	for species in range(16):
		if not species_filter.is_empty() and not species_filter.has(species): continue
		for age in ["baby","adult"]:
			var available=preload("res://scripts/rabbit_pilot_art.gd").data().stages if species==0 else Smooth.data(species).get("stages",{})
			if not capture_legacy_walks and not available.has(age): continue
			selected=species
			baby=age=="baby"
			modern=true
			select_pet()
			await get_tree().create_timer(.7).timeout
			capture_frames=[]
			capture_images=[]
			capture_age=0
			capture_timer=0
			capture_index=0
			capture_enabled=true
			if requested_direction!=0: direction=requested_direction
			start_walk()
			var capture_cycles=(3.5 if include_stop else 2.1) if review_stride_fraction==3.0 else ceilf(review_stride_fraction)+.5
			var playback_cycle=preload("res://scripts/gait_profile.gd").PERIOD[species] if capture_legacy_walks else float(available[age].cycle_seconds if species==0 else Smooth.spec(app.pet.motion).cycle_seconds)
			await get_tree().create_timer(playback_cycle*capture_cycles).timeout
			capture_enabled=false
			for item in capture_images:
				item.image.save_png(ProjectSettings.globalize_path("res://")+item.file)
			capture_images.clear()
			var expected_indices=range(0,32,2) if capture_legacy_walks and species==14 else range(32 if capture_legacy_walks else 60)
			var bank="rabbit-frame-pilot-v9" if species==0 else "walk-v%d"%Smooth.asset_version(species)
			capture_results.append({"species":Catalog.IDS[species],"stage":age,"frames":capture_frames,"expected_walk_frames":expected_indices.size(),"expected_indices":expected_indices,"playback_cycle_seconds":playback_cycle,"asset_bank":"legacy-v4-original-only" if capture_legacy_walks and species==14 else ("legacy-v4" if capture_legacy_walks else bank)})
			print("WALK_NATIVE_CAPTURE ",Catalog.IDS[species]," ",age," ",capture_frames.size())
	var report=FileAccess.open(ProjectSettings.globalize_path("res://")+capture_folder+"-report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_driver_name(),"requested_stride_fraction":review_stride_fraction,"requested_direction":requested_direction,"results":capture_results},"\t"))
	report.close()
	print("ALL_WALK_NATIVE_CAPTURE_DONE ",capture_results.size())
	if OS.get_cmdline_user_args().has("--capture-quit"):
		get_tree().quit()
		return
	capture_running=false
	selected=return_species
	baby=false
	looping=true
	select_pet()
