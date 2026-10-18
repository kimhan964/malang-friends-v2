extends Node
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Smooth=preload("res://scripts/smooth_species_art.gd")
const State=preload("res://scripts/pet_state.gd")
var app
var checks=[]
var traces=[]
var failed=false
func check(ok: bool,label: String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok:failed=true;push_error("SYSTEM_AUDIT_FAILED "+label)
func progress_at(spec: Dictionary,phase: float) -> float:
	if spec.get("continuous_stride",false):return phase
	var curve: Array=spec.get("travel_curve",[])
	if curve.size()<2:return phase
	var position=phase*(curve.size()-1)
	var first=mini(int(position),curve.size()-2)
	return lerpf(float(curve[first]),float(curve[first+1]),position-first)
func walking() -> void:
	for species in range(16):
		for stage in [0,2]:
			for direction in [-1,1]:
				for fps in [30,60,144]:
					var m=Motion.new();m.species=species;m.growth_stage=stage;m.growth_scale=.93 if stage==0 else 1.0
					m.smooth_walk_enabled=true;m.autonomy=false;m.daily.enabled=false
					m.bounds=Rect2(-10000,0,20000,400);m.feet=Vector2(0,200);m.target=Vector2(direction*9000,200);m.phase="wander"
					var spec=Smooth.spec(m);var stride=m.smooth_walk_cycle.stride_length(m,spec)
					var cycle=float(spec.cycle_seconds);var duration=cycle*4.37;var elapsed=0.0
					while elapsed<duration-.00000001:
						var dt=minf(1.0/fps,duration-elapsed);m.advance_travel(dt);elapsed+=dt
					var expected=stride*(4+progress_at(spec,.37))
					var error=absf(absf(m.feet.x)-expected)
					check(error<.025,"elapsed travel %d/%d/%d/%d error=%.4f"%[species,stage,direction,fps,error])
					check(absf(m.walk_phase-.37)<.001,"cycle remainder %d/%d/%d/%d"%[species,stage,direction,fps])
					traces.append({"species":species,"stage":stage,"direction":direction,"fps":fps,"expected":expected,"actual":absf(m.feet.x),"error":error})
		var edge=Motion.new();edge.species=species;edge.smooth_walk_enabled=true;edge.growth_stage=2;edge.growth_scale=1
		edge.autonomy=false;edge.daily.enabled=false;edge.bounds=Rect2(100,200,500,1);edge.feet=Vector2(580,200);edge.target=Vector2(600,200);edge.phase="visit";edge.visit_action="look"
		for tick in range(600):edge.advance(1.0/60)
		check(edge.feet.x<=600.001 and edge.feet.x>=100,"screen boundary "+str(species))
		check(edge.phase!="visit","edge visit completes "+str(species))
		var stalled=Motion.new();stalled.species=species;stalled.smooth_walk_enabled=true;stalled.growth_stage=2;stalled.growth_scale=1;stalled.autonomy=false;stalled.daily.enabled=false
		stalled.bounds=Rect2(-10000,0,20000,400);stalled.feet=Vector2(0,200);stalled.target=Vector2(9000,200);stalled.phase="wander"
		var stalled_spec=Smooth.spec(stalled);var stalled_stride=stalled.smooth_walk_cycle.stride_length(stalled,stalled_spec)
		stalled.advance_travel(float(stalled_spec.cycle_seconds)*2.37)
		check(absf(stalled.feet.x-stalled_stride*(2+progress_at(stalled_spec,.37)))<.01,"delayed frame consumes two contacts "+str(species))
		var previous=stalled.feet;stalled.cancel_play();stalled.phase="wander";stalled.target=previous-Vector2(800,0);stalled.advance(1.0/60)
		check(stalled.feet.x<previous.x and stalled.facing==-1,"interrupted walk reverses without stale destination "+str(species))
		var social=Motion.new();social.species=species;social.smooth_walk_enabled=true;social.growth_stage=2;social.growth_scale=1
		social.autonomy=false;social.daily.enabled=false;social.can_follow=true;social.bounds=Rect2(-10000,0,20000,400);social.feet=Vector2(0,200)
		social.cursor_position=Vector2(350,200);social.start_social("follow")
		for tick in range(600):
			social.cursor_position=social.feet+Vector2(350,0);social.advance(1.0/60)
		check(social.social_kind.is_empty(),"follow timeout ends at contact "+str(species))
		if preload("res://scripts/run_hop_art.gd").has_action(species,"run"):
			var queued=Motion.new();queued.species=species;queued.smooth_walk_enabled=true;queued.growth_stage=2;queued.growth_scale=1
			queued.autonomy=false;queued.daily.enabled=false;queued.bounds=Rect2(-10000,0,20000,400);queued.feet=Vector2(0,200);queued.target=Vector2(9000,200);queued.phase="wander"
			queued.advance(1.0/60);queued.daily.start(queued,"run")
			for tick in range(180):
				queued.advance(1.0/60)
				if queued.phase=="daily_action":break
			check(queued.phase=="daily_action","queued run starts after contact "+str(species))
func rewards() -> void:
	for pair in [["home_wall_shelf","home_read"],["home_fireplace","home_rest"]]:
		app.state.reward_times.clear();var before=app.state.home_points()
		var m=app.pet.motion;m.cancel_play();m.autonomy=false;m.daily.enabled=false;m.phase="home_use";m.visit_id=pair[0];m.action_left=.01
		m.advance(.02)
		check(app.state.home_points()==before+1,"completed care recorded "+pair[0])
func toys() -> void:
	var room=app.furniture_room;var m=app.pet.motion
	room.toy_play.cancel()
	for id in ["toy_mouse","toy_plush"]:app.state.home_owned[id]=true;room.place(id,Vector2(400,400),false)
	for piece in room.pieces.values():piece.hide();piece.set_process(false)
	for prop in app.props.values():prop.hide()
	var mouse=room.pieces.toy_mouse;mouse.show();mouse.position=Vector2i(440,430)
	var rug=room.pieces.play_rug;rug.show();rug.set_user_scale(1.6)
	# A floor covering under both possible legs is passable, even at large size.
	rug.position=mouse.position-Vector2i(200,100);rug.size=Vector2i(600,300)
	m.cancel_play();m.autonomy=false;m.feet=Vector2(430,m.bounds.get_center().y);m.visit_id="home_toy_mouse"
	var play=room.toy_play;play.id="toy_mouse";play.species=m.species;play.direction=1;play.stage="inspect"
	play.begin_follow(room)
	check(play.stage=="follow","toy pursuit crosses floor rug")
	play.cancel();rug.hide()
	var plush=room.pieces.toy_plush;plush.show();m.visit_id="home_toy_plush";play.arrived(room,m.visit_id)
	check(not plush.visible,"held plush hidden")
	m.cooldown=0;m.pet();play.advance(room,.01)
	check(plush.visible and not play.busy() and m.soft_toy_prop.is_empty(),"interrupted plush restored once")
	room.pieces.bathtub.show();room.use_piece("bathtub");m.feet=m.target
	for tick in range(6):m.advance(.02)
	check(m.phase=="home_use" and m.visit_id=="home_bathtub","bath arrival works")
	room.remove_piece("bathtub");check(m.visit_id.is_empty() and m.phase=="idle","removing active bath cancels action")
func storage() -> void:
	var path="user://audit-"+str(Time.get_ticks_usec())+".json"
	var s=State.new();s.save_path=path;s.selected=5;s.home_initialized=true;s.growth={"5":36};s.furniture={"sofa":[-120,320,true,.7,4]};s.save_game()
	s.selected=1;s.save_game()
	var loaded=State.new();loaded.save_path=path;loaded.load_game()
	check(not s.save_failed and loaded.selected==1 and loaded.furniture.sofa[0]==-120,"save round trip negative monitor and scale")
	FileAccess.open(path,FileAccess.WRITE).store_string("{truncated")
	var recovered=State.new();recovered.save_path=path;recovered.load_game()
	check(recovered.selected==5 and recovered.growth.get("5",0)==36,"truncated save recovers last good backup")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"scale_defaults_version":{},"selected":15,"growth":{"15":36},"furniture":{"plant_stand":[100,300,false,1.0,0]}}))
	var malformed=State.new();malformed.save_path=path;malformed.load_game()
	check(malformed.selected==15 and malformed.growth.get("15",0)==36,"malformed migration version keeps valid fields")
	var blocked=State.new();blocked.save_path=path+"/missing/save.json";blocked.save_game()
	check(blocked.save_failed,"unwritable path reports save failure")
	for suffix in ["",".tmp",".bak"]:DirAccess.remove_absolute(path+suffix)
func native_walks(folder: String) -> void:
	if DisplayServer.get_name()=="headless":return
	var viewport=SubViewport.new();viewport.size=Vector2i(320,224);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	for species in [3,5,1,15]:
		var m=Motion.new();m.species=species;m.smooth_walk_enabled=true;m.growth_stage=2;m.growth_scale=1;m.autonomy=false;m.daily.enabled=false
		m.bounds=Rect2(-1000,0,2000,400);m.feet=Vector2(0,200);m.target=Vector2(900,200);m.phase="wander"
		var view=preload("res://scripts/desktop_pet_view.gd").new();view.motion=m;viewport.add_child(view)
		var duration=float(Smooth.spec(m).cycle_seconds)*2;var index=0;var age=0.0
		while age<duration-.000001:
			var dt=minf(1.0/60,duration-age);m.advance(dt);age+=dt
			view.position=Vector2(70+m.feet.x,180)-view.FEET;view.refresh(dt)
			await RenderingServer.frame_post_draw
			var image=viewport.get_texture().get_image()
			check(image.get_used_rect().has_area(),"native walk %d/%d"%[species,index])
			image.save_png(folder.path_join("walk-%d-%03d.png"%[species,index]));index+=1
		viewport.remove_child(view);view.queue_free()
	viewport.queue_free()
func run() -> void:
	await get_tree().process_frame
	app.set_process(false);app.furniture_room.set_process(false);app.behavior_panel.set_process(false);app.pet.set_process(false)
	app.pet.motion.autonomy=false;app.pet.motion.daily.enabled=false
	walking();rewards();toys();storage()
	var folder=OS.get_executable_path().get_base_dir().path_join("검수/시스템-20261018")
	DirAccess.make_dir_recursive_absolute(folder)
	await native_walks(folder)
	FileAccess.open(folder.path_join("headless.json" if DisplayServer.get_name()=="headless" else "native.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"checks":checks,"walking":traces},"\t"))
	print("SYSTEM_AUDIT_VALIDATED checks=",checks.size()," passed=",not failed)
	get_tree().quit(4 if failed else 0)
