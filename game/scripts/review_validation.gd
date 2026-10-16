extends Node
var app
var item=3
var checks=[]
var failed=false
var viewport: SubViewport
var preview
func check(ok: bool,label: String) -> void:
	checks.append({"passed":ok,"check":label})
	if not ok: failed=true;push_error("REVIEW_FAILED "+label)
func folder() -> String:
	var path=OS.get_executable_path().get_base_dir().path_join("검수/순차수정/%02d"%item)
	DirAccess.make_dir_recursive_absolute(path);return path
func render_setup(m) -> void:
	if DisplayServer.get_name()=="headless": return
	viewport=SubViewport.new();viewport.size=Vector2i(256,224);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	preview=preload("res://scripts/desktop_pet_view.gd").new();preview.motion=m;viewport.add_child(preview)
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	preview.refresh(0)
	await RenderingServer.frame_post_draw
	var image: Image=viewport.get_texture().get_image()
	check(image.get_used_rect().has_area(),"nonempty rendered frame "+name)
	image.save_png(folder().path_join(name+".png"))
func hands() -> void:
	await app.choose_friend(3);app.pet.set_process(false)
	var m=app.pet.motion;m.autonomy=false;m.daily.enabled=false;m.cancel_play();m.growth_scale=1;m.growth_stage=2
	render_setup(m)
	for kind in ["sofa","bed","play","bath"]:
		var cels=preload("res://scripts/v2_life_art.gd").frames(3,kind)
		check(cels.size()==32,"life bank remains complete "+kind)
		for i in range(32):
			m.phase="home_use";m.visit_id={"sofa":"home_sofa","bed":"home_daybed","play":"home_toy_plush","bath":"home_bathtub"}[kind]
			m.elapsed=.65+float(i)/32.0*2.4;m.action_left=20
			app.pet.view.refresh(0)
			check(app.pet.view.generated_sample.bank=="life_"+kind,"correct whole-body bank %s/%d"%[kind,i])
			if i%8==0: await capture("life-%s-%02d"%[kind,i])
	for kind in preload("res://scripts/v2_daily_art.gd").KINDS:
		var cels=preload("res://scripts/v2_daily_art.gd").frames(3,kind)
		check(cels.size()==32,"daily bank remains complete "+kind)
		m.phase="idle";m.cancel_play();check(m.daily.start(m,kind),"daily starts "+kind)
		for i in range(32):
			m.daily.clock=float(i)/32.0*float(preload("res://scripts/v2_daily_art.gd").data(3).sequences[kind].duration)
			app.pet.view.refresh(0)
			check(app.pet.view.generated_sample.bank=="daily-"+kind,"correct daily bank %s/%d"%[kind,i])
			if i%8==0: await capture("daily-%s-%02d"%[kind,i])
func release_response() -> void:
	for species in range(16):
		for height in [5.0,40.0,180.0,400.0]:
			var m=preload("res://scripts/desktop_pet_motion.gd").new()
			m.species=species;m.autonomy=false;m.daily.enabled=false;m.floor_space=true;m.bounds=Rect2(100,480,800,40);m.feet=Vector2(400,500-height);m.target=m.feet
			m.begin_drop(true)
			m.advance(1.0/60)
			var pose=preload("res://scripts/v2_interaction_art.gd").sample(m)
			check(m.feet.y>500-height and pose.action=="landing","reacts on first released frame %d/%s"%[species,height])
			var elapsed=1.0/60
			while m.phase=="drop" and elapsed<1.1:m.advance(1.0/60);elapsed+=1.0/60
			check(m.phase=="dizzy" and m.feet.distance_to(Vector2(400,500))<.01,"lands without overshoot %d/%s"%[species,height])
			m.advance(.23)
			check(m.landing_left<=0,"impact responds within .23 seconds %d/%s"%[species,height])
			if height==5:check(elapsed<.12,"small release has no long air pause "+str(species))
func run() -> void:
	await get_tree().process_frame
	app.set_process(false);app.furniture_room.set_process(false);app.behavior_panel.set_process(false)
	for piece in app.furniture_room.pieces.values():piece.hide();piece.set_process(false)
	for prop in app.props.values():prop.hide();prop.set_process(false)
	match item:
		3: await hands()
		4: release_response()
		5: await gaits()
		6: await mouse_toy()
		7: await rabbit_size()
		8: await stable_surface()
		9: await plush_play()
		10: await alarm_clock()
		11: await targeted_walks()
		12: await ladder()
		13: await walking_speed()
		14: await plant_scale()
		15: await acorn_play()
		16: await fox_actions()
		19: await put_away()
		20:
			await hands();release_response();await gaits();await mouse_toy();await rabbit_size();await plush_play();await alarm_clock();await targeted_walks();await ladder();await plant_scale();await acorn_play();await fox_actions();await put_away()
		_: check(false,"unknown item "+str(item))
	FileAccess.open(folder().path_join("headless.json" if DisplayServer.get_name()=="headless" else "native.json"),FileAccess.WRITE).store_string(JSON.stringify({"item":item,"passed":not failed,"checks":checks},"\t"))
	print("REVIEW_VALIDATED item=",item," checks=",checks.size()," passed=",not failed)
	get_tree().quit(4 if failed else 0)

func mouse_toy() -> void:
	var piece=preload("res://scripts/furniture_window.gd").new();piece.item_id="toy_mouse";add_child(piece);piece.set_process(false)
	var region=piece.mouse_passthrough_polygon;var surface=piece.size;var poses={}
	for i in range(64):
		piece.toy_clock=(float(i)+.5)/64*.68;piece.roam_speed=42;piece._process(0)
		poses[piece.sprite.texture.get_instance_id()]=true
		check(piece.size==surface and piece.mouse_passthrough_polygon==region,"mouse canvas/input region stays stable "+str(i))
	check(poses.size()==64,"mouse uses 64 real motion cels")
	piece.hide();piece.queue_free()
func rabbit_size() -> void:
	var m=preload("res://scripts/desktop_pet_motion.gd").new();m.species=0;m.autonomy=false;m.daily.enabled=false;m.growth_scale=1;m.growth_stage=2
	check(is_equal_approx(preload("res://scripts/animal_catalog.gd").HEIGHTS[0],1.24),"rabbit is 24 percent larger across all actions")
	render_setup(m)
	for kind in ["idle","wander","home_use"]:
		m.phase=kind;m.visit_id="home_toy_plush";m.action_left=20;m.elapsed=2;m.voice_left=0;m.walk_phase=.25
		if DisplayServer.get_name()!="headless":await capture("rabbit-"+kind)
func stable_surface() -> void:
	var m=app.pet.motion;m.autonomy=false;m.daily.enabled=false;m.cancel_play();m.voice_left=0
	var surface=app.pet.size;var origin=app.pet.position;render_setup(m)
	if DisplayServer.get_name()!="headless": await get_tree().create_timer(.35).timeout
	for i in range(40):
		m.phase="wander";m.walk_phase=float(i)/40
		m.feet.x+=1.2;app.pet.view.position=m.feet-app.pet.View.FEET-Vector2(app.pet.position);app.pet.view.refresh(0)
		var through=i%2==0
		preload("res://scripts/native_mouse.gd").apply(app.pet,through)
		check(app.pet.size==surface and app.pet.position==origin,"walking never moves/resizes native surface "+str(i))
		if DisplayServer.get_name()!="headless":
			FileAccess.open(folder().path_join("probe.json"),FileAccess.WRITE).store_string(JSON.stringify({"index":i,"hwnd":DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE,app.pet.get_window_id()),"through":through}))
			var waiting=0.0
			while waiting<2.0:
				await get_tree().create_timer(.01).timeout;waiting+=.01
				if FileAccess.file_exists(folder().path_join("ack.json")):
					var ack=JSON.parse_string(FileAccess.get_file_as_string(folder().path_join("ack.json")))
					if ack!=null and int(ack.get("index",-1))==i:break
			check(waiting<2.0,"native input acknowledgement "+str(i))
			await capture("steady-%02d"%i)
func plush_play() -> void:
	await app.choose_friend(3);app.pet.set_process(false)
	var m=app.pet.motion;m.autonomy=false;m.daily.enabled=false;m.growth_scale=1;m.growth_stage=2
	app.state.home_owned.toy_plush=true;app.furniture_room.place("toy_plush",Vector2(400,500),false)
	m.visit_id="home_toy_plush";app.furniture_room.toy_play.arrived(app.furniture_room,m.visit_id);m.voice_left=0
	check(not app.furniture_room.pieces.toy_plush.visible,"world plush hidden while held")
	render_setup(m);var toss=0.0
	for i in range(60):
		m.elapsed=float(i)/60*24.4;m.action_left=24.4-m.elapsed
		var p=preload("res://scripts/play_choreography.gd").plush(m,Vector2(166,180));toss=maxf(toss,p.toss)
		if i%5==0:await capture("plush-%02d"%i)
	check(toss>.9,"plush includes small throw and catch")
	app.furniture_room.toy_play.cancel()
	check(app.furniture_room.pieces.toy_plush.visible and m.soft_toy_prop.is_empty(),"cancel restores one world plush")
func alarm_clock() -> void:
	app.state.home_owned.alarm_clock=true;app.furniture_room.place("alarm_clock",Vector2(400,400),false)
	var p=app.furniture_room.pieces.alarm_clock;p.set_process(false);p.set_active(true)
	var peak=0.0;var area=p.mouse_passthrough_polygon
	for i in range(120):
		p._process(1.0/60);peak=maxf(peak,absf(p.sprite.rotation))
		check(p.mouse_passthrough_polygon==area,"alarm effect uses steady input/draw canvas "+str(i))
	check(peak>.1,"alarm has visible bell shake")
	p.set_active(false);p._process(0);check(is_zero_approx(p.sprite.rotation),"alarm settles without permanent tilt")
	var m=app.pet.motion;m.cancel_play();m.visit_id="home_alarm_clock";m.phase="look";app.furniture_room.on_visit(m.visit_id)
	check(m.soft_alarm_time==0 and m.reaction=="surprised","pet reacts immediately to alarm")

func put_away() -> void:
	var room=app.furniture_room
	if not is_instance_valid(room.panel):room.build_panel()
	for id in ["acorn","basket"]:
		app.set_prop_visible(id,true);check(app.props[id].visible,"can take out "+id)
		room.prop_buttons[id].pressed.emit();check(not app.props[id].visible and id in app.state.hidden,"button puts away correct toy "+id)
		room.prop_buttons[id].pressed.emit();check(app.props[id].visible and id not in app.state.hidden,"button restores correct toy "+id)
	for id in ["toy_ball","toy_mouse","toy_plush"]:
		app.state.home_owned[id]=true;room.place(id,Vector2(400,400),false)
		var m=app.pet.motion;m.cancel_play();m.visit_id="home_"+id;room.toy_play.arrived(room,m.visit_id)
		room.remove_piece(id)
		check(not room.pieces.has(id) and not room.toy_play.busy(),"putting away cancels ongoing toy activity "+id)
		check(m.visit_id.is_empty(),"putting away clears pet target "+id)
		room.place(id,Vector2(400,400),false);check(room.pieces.has(id),"toy can be placed again "+id)
	var codex=preload("res://scripts/action_codex.gd").new();codex.state=app.state;add_child(codex);codex.build();codex.species=3;codex.rebuild()
	for button in codex.buttons:check(not button.tooltip_text.contains("프레임"),"codex tooltip has no frame counter")
	codex.queue_free()
func fox_actions() -> void:
	var m=preload("res://scripts/desktop_pet_motion.gd").new();m.species=5;m.autonomy=false;m.daily.enabled=false;m.growth_scale=1;m.growth_stage=2;m.voice_left=0
	render_setup(m)
	for kind in ["idle","pet","sleep","eat"]:
		m.phase={"idle":"idle","pet":"pet","sleep":"doze","eat":"eat"}[kind]
		for i in range(32):
			m.elapsed=(float(i)+.5)/32*float(preload("res://scripts/v2_basic_art.gd").data(5).sequences[kind].duration)
			var sample=preload("res://scripts/soft_roster_art.gd").sample(m)
			check(sample.bank==kind,"fox keeps correct complete-body state "+kind)
			if i%8==0:await capture("fox-%s-%02d"%[kind,i])
func acorn_play() -> void:
	var m=app.pet.motion;m.cancel_play();m.autonomy=false;m.daily.enabled=false;m.growth_scale=1;m.growth_stage=2;m.voice_left=0
	m.phase="prop_use";m.visit_id="acorn";m.action_left=18;render_setup(m)
	var poses={}
	for i in range(48):
		m.elapsed=float(i)/24;m.action_left=18-m.elapsed
		var sample=preload("res://scripts/soft_roster_art.gd").sample(m);poses[sample.index]=true
		check(sample.bank=="life_play","acorn uses complete play body "+str(i))
		if i%4==0:await capture("acorn-%02d"%i)
	check(poses.size()>20,"acorn has changing full-body poses")
func plant_scale() -> void:
	for scale in [.65,.7,1.0,1.2]:
		var s=preload("res://scripts/pet_state.gd").new();s.furniture={"plant_stand":[300,400,false,scale,0],"sofa":[100,400,false,1.0,0]}
		s.migrate_scale_defaults(0)
		check(is_equal_approx(s.furniture.plant_stand[3],.7 if scale==1 else scale),"plant migration preserves custom size "+str(scale))
		check(s.furniture.sofa[3]==1.0,"plant migration leaves other furniture size")
	app.state.home_owned.plant_stand=true;app.furniture_room.place("plant_stand",Vector2(400,400),false)
	var piece=app.furniture_room.pieces.plant_stand
	check(is_equal_approx(piece.user_scale,.7),"new plant starts at 70 percent")
	piece.set_user_scale(1.2);piece.menu_action(24)
	check(is_equal_approx(piece.user_scale,.7),"reset uses 70 percent")
func walking_speed() -> void:
	check(is_equal_approx(preload("res://scripts/animal_catalog.gd").WORLD_SPEED_MULTIPLIER/1.3,1.5),"walking speed exactly 1.5 times previous")
	await gaits()
func ladder() -> void:
	var m=app.pet.motion;m.cancel_play();m.autonomy=false;m.daily.enabled=false;m.growth_scale=1;m.growth_stage=2;m.voice_left=0
	app.state.home_owned.wall_shelf=true;app.furniture_room.place("wall_shelf",Vector2(400,200),false)
	m.phase="home_use";m.visit_id="home_wall_shelf";m.elapsed=0;m.action_left=41;m.feet=Vector2(450,650)
	app.furniture_room.shelf_ladder.begin(app.furniture_room);m.voice_left=0
	check(app.furniture_room.shelf_ladder.window.visible and m.soft_climb_height>0,"ladder appears at wall shelf")
	var floor=m.feet.y;render_setup(m)
	if is_instance_valid(viewport):
		viewport.size=Vector2i(512,600);preview.position=Vector2(128,350)
		var ladder_copy=Sprite2D.new();ladder_copy.centered=false;ladder_copy.texture=app.furniture_room.shelf_ladder.sprite.texture;ladder_copy.scale=app.furniture_room.shelf_ladder.sprite.scale;ladder_copy.position=preview.position+Vector2(128,190)-Vector2(app.furniture_room.shelf_ladder.window.size.x*.5,app.furniture_room.shelf_ladder.window.size.y);ladder_copy.z_index=-2;viewport.add_child(ladder_copy)
	for i in range(16):
		m.elapsed=float(i)/15*7.4
		var height=preload("res://scripts/shelf_ladder.gd").lift(m)
		check(height>=-.01 and height<=m.soft_climb_height+.01 and m.feet.y==floor,"climb has continuous visual height and grounded physics "+str(i))
		await capture("ladder-%02d"%i)
	m.elapsed=8;check(not preload("res://scripts/shelf_ladder.gd").active(m),"after descent switches to reading")
	check(preload("res://scripts/v2_daily_art.gd").sample(m).get("embedded_book",false),"reading uses one embedded book")
	m.cancel_play();app.furniture_room.shelf_ladder.advance(app.furniture_room)
	check(not app.furniture_room.shelf_ladder.window.visible and m.soft_climb_height==0,"cancel clears ladder and lift")
func targeted_walks() -> void:
	for species in [1,5,7]:
		var m=preload("res://scripts/desktop_pet_motion.gd").new();m.species=species;m.autonomy=false;m.daily.enabled=false;m.growth_scale=1;m.growth_stage=2;m.voice_left=0
		var spec=preload("res://scripts/smooth_species_art.gd").spec(m)
		check(spec.get("targeted_review",false),"dedicated grounded walk bank "+str(species))
		var frames=preload("res://scripts/smooth_species_art.gd").frames(species,"adult")
		for f in frames:check(f.get_image().get_used_rect().has_area(),"no blank walk cel "+str(species))
		render_setup(m)
		for i in range(12):
			m.phase="wander";m.walk_phase=(float(i)+.5)/12;await capture("%d-walk-%02d"%[species,i])
		if is_instance_valid(viewport):viewport.queue_free();await get_tree().process_frame
func gaits() -> void:
	for species in range(16):
		var m=preload("res://scripts/desktop_pet_motion.gd").new()
		m.species=species;m.autonomy=false;m.daily.enabled=false;m.floor_space=true;m.bounds=Rect2(100,480,1000,40);m.feet=Vector2(400,500);m.target=m.feet;m.growth_scale=1;m.growth_stage=2
		var metadata=preload("res://scripts/smooth_species_art.gd").spec(m)
		check(metadata.count>=72 and metadata.source_key_count>=6,"authored walk poses with complete intermediates "+str(species))
		var stride=m.smooth_walk_cycle.stride_length(m,metadata)
		var walk_speed=stride/float(metadata.cycle_seconds)
		m.daily.start(m,"run")
		var previous=m.feet.x;var peak=0.0;var distance=0.0;var seconds=0.0
		for i in range(600):
			if m.phase!="daily_action":break
			m.advance(1.0/120);seconds+=1.0/120
			distance+=absf(m.feet.x-previous);previous=m.feet.x
			if m.phase=="daily_action":
				var s=preload("res://scripts/v2_daily_art.gd").sample(m)
				peak=maxf(peak,float(s.get("lift",0)))
		check(peak>2,"run has airborne motion "+str(species))
		check(distance/maxf(seconds,.01)>walk_speed*1.1,"running travels faster than walking "+str(species))
		check(m.bounds.has_point(m.feet),"run stays inside activity space "+str(species))
		if species in [0,3,15] and DisplayServer.get_name()!="headless":
			render_setup(m);m.voice_left=0
			for i in range(8):
				m.phase="wander";m.walk_phase=float(i)/8;await capture("%d-walk-%02d"%[species,i])
			m.phase="idle";m.feet=Vector2(400,500);m.daily.start(m,"run");m.voice_left=0
			for i in range(8):
				m.daily.clock=float(i)/8*float(metadata.cycle_seconds)*.62;m.walk_phase=float(i)/8;await capture("%d-run-%02d"%[species,i])
			viewport.queue_free();await get_tree().process_frame
