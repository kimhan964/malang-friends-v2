extends Node
const Art=preload("res://scripts/run_hop_art.gd")
var app
var checks=[]
var failed=false
var trace=[]
func check(value: bool,message: String) -> void:
	checks.append({"check":message,"passed":value})
	if not value: failed=true;push_error("RUN_HOP "+message)
func output() -> String:
	var path=OS.get_executable_path().get_base_dir().path_join("검수/토끼-달리기점프")
	DirAccess.make_dir_recursive_absolute(path)
	return path
func capture(name: String,origin: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var canvas=Image.create(460,190,false,Image.FORMAT_RGBA8);canvas.fill(Color("faf8f3"))
	canvas.fill_rect(Rect2i(0,151,460,1),Color("ded6ca"))
	var window=app.pet
	var image: Image=window.get_texture().get_image()
	var part=Rect2i(window.position,image.get_size()).intersection(Rect2i(origin,canvas.get_size()))
	if part.has_area(): canvas.blend_rect(image,Rect2i(part.position-window.position,part.size),part.position-origin)
	canvas.save_png(output().path_join(name+".png"))
func run() -> void:
	await get_tree().process_frame
	app.set_process(false);app.behavior_panel.set_process(false);app.furniture_room.set_process(false)
	for prop in app.props.values(): prop.hide();prop.set_process(false)
	for piece in app.furniture_room.pieces.values(): piece.hide();piece.set_process(false)
	await app.choose_friend(0)
	app.pet.set_process(false)
	var m=app.pet.motion
	m.autonomy=false;m.daily.enabled=false;m.resting=false;m.held=false;m.carried=false;m.energy=80;m.satiety=80;m.hydration=80
	for action in ["run","jump"]:
		check(Art.frames(0,action).size()==60,"60 playback cels "+action)
		for cel in Art.frames(0,action):
			var used=cel.get_image().get_used_rect()
			check(used.has_area() and used.position.x>0 and used.position.y>0 and used.end.x<256 and used.end.y<256,"cel fits "+action)
	for age in [.65,1.0]:
		for facing in [-1,1]:
			for action in ["run","jump"]:
				m.cancel_play();m.resting=false;m.soft_recover_left=0;m.joy_left=0
				m.growth_scale=age;m.growth_stage=0 if age<.7 else 2
				var rect: Rect2=m.bounds
				m.feet=Vector2(rect.get_center().x+(-80 if facing>0 else 80),rect.end.y-2)
				m.target=m.feet;m.facing=facing
				var before: Vector2=m.feet
				m.voice_left=0;app.pet.advance_frame(0)
				var idle_height=app.pet.view.sprite.texture.get_image().get_used_rect().size.y*absf(app.pet.view.sprite.scale.y)
				if age==1.0 and facing==1 and DisplayServer.get_name()!="headless": await capture(action+"-before",Vector2i(before)-Vector2i(150,150))
				check(m.daily.start(m,action),"start %s/%s/%s"%[action,age,facing])
				m.voice_left=0
				app.pet.advance_frame(0)
				var start_height=app.pet.view.sprite.texture.get_image().get_used_rect().size.y*absf(app.pet.view.sprite.scale.y)
				check(absf(start_height-idle_height)<idle_height*.15,"entry size agrees with idle")
				var origin=Vector2i(before)-Vector2i(150,150)
				var seen={};var first_scale=Vector2.ZERO;var last=before;var maximum_lift=0.0
				var captured=0
				for tick in range(600):
					app.pet.advance_frame(1.0/60)
					if m.phase!="daily_action": break
					var sample=app.pet.view.generated_sample
					check(sample.get("run_hop",false),"dedicated whole-body bank")
					seen[int(sample.index)]=true
					if first_scale==Vector2.ZERO:first_scale=app.pet.view.sprite.scale
					check(app.pet.view.sprite.scale.is_equal_approx(first_scale),"constant display scale")
					check(rect.grow(1).has_point(m.feet),"inside screen")
					check(is_equal_approx(m.feet.y,before.y),"floor anchor stable")
					var metadata=Art.spec(0,action)
					var phase=Art.phase_at(metadata,m.daily.clock)
					maximum_lift=maxf(maximum_lift,float(sample.lift)*absf(first_scale.y))
					if action=="jump":check(m.feet.is_equal_approx(before),"stationary hop")
					elif phase<float(metadata.launch) or phase>float(metadata.land)+.02:
						check(m.feet.distance_to(last)<.05,"planted feet stop world travel")
					last=m.feet
					if age==1.0 and facing==1:
						trace.append({"action":action,"tick":tick,"index":sample.index,"x":m.feet.x-before.x,"lift":maximum_lift,"phase":phase})
						if DisplayServer.get_name()!="headless":
							await capture(action+"-%03d"%tick,origin);captured+=1
				check(m.phase=="idle","returns idle after recovery")
				if age==1.0 and facing==1 and DisplayServer.get_name()!="headless": await capture(action+"-after",origin)
				check(seen.size()>=48,"detailed cel progression "+action)
				check(maximum_lift>1 and maximum_lift<11,"small visible flight "+action)
				if action=="run":check(m.feet.distance_to(before)>40*age,"actual running distance")
	# A tiny space cannot start a partly clipped stride.
	m.cancel_play();m.bounds=Rect2(300,300,32,50);m.feet=Vector2(316,345);m.daily.start(m,"run")
	check(m.daily.action=="happy","no room uses grounded happy response")
	m.bounds=app.pet.activity_bounds(app.pet.desktop_bounds())
	m.cancel_play();m.carried=true;check(not m.daily.start(m,"jump"),"held blocks hop");m.carried=false
	m.cancel_play();m.phase="wander";m.smooth_walk_cycle.active=true
	check(m.daily.start(m,"jump") and m.phase=="wander" and m.daily.queued=="jump","finish current walking stride before hop")
	m.daily.advance(m,.01);check(m.phase=="wander","queued hop waits for ground contact")
	m.smooth_walk_cycle.reset();m.phase="idle";m.daily.advance(m,.01)
	check(m.phase=="daily_action" and m.daily.action=="jump","queued hop begins on contact")
	m.cancel_play();check(m.daily.queued.is_empty(),"cancel clears queued hop")
	var book=preload("res://scripts/action_codex.gd").new();app.add_child(book);book.open(0)
	check(book.shown_actions==24,"rabbit codex has 24 actions")
	book.select_action(preload("res://scripts/action_codex_data.gd").descriptor(0,"locomotion","jump"),"제자리 폴짝","착지 후 발을 충분히 디뎌요")
	book.clock=.72;book.update_frame()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		book.panel.get_texture().get_image().save_png(output().path_join("도감-토끼.png"))
	FileAccess.open(output().path_join("validation.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"checks":checks,"trace":trace},"\t"))
	print("RUN_HOP_VALIDATED ",checks.size()," passed=",not failed)
	get_tree().quit(1 if failed else 0)
