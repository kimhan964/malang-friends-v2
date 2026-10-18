extends Node
const Art=preload("res://scripts/v2_daily_art.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
var app
var checks=[]
var failed=false
var captures=[]
func check(ok: bool,label: String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok: failed=true;push_error("DAILY_CHECK_FAILED "+label)
func output() -> String:
	var path=OS.get_executable_path().get_base_dir().path_join("검수/다양한행동")
	DirAccess.make_dir_recursive_absolute(path)
	return path
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image: Image=app.pet.get_texture().get_image()
	var rect=image.get_used_rect().grow(8).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	check(rect.has_area(),"native pixels "+label)
	if rect.has_area(): image.get_region(rect).save_png(output().path_join(label+".png"));captures.append(label)
func run() -> void:
	await get_tree().process_frame
	app.set_process(false);app.furniture_room.set_process(false);app.behavior_panel.set_process(false)
	if OS.get_cmdline_user_args().has("--menu-only"):
		app.behavior_panel.open()
		await RenderingServer.frame_post_draw
		app.behavior_panel.panel.get_texture().get_image().save_png(output().path_join("행동-선택창.png"))
		print("DAILY_MENU_VALIDATED")
		get_tree().quit();return
	for piece in app.furniture_room.pieces.values(): piece.hide()
	for prop in app.props.values(): prop.hide()
	if OS.get_cmdline_user_args().has("--replay-only"):
		await record()
		print("DAILY_REPLAY_VALIDATED")
		get_tree().quit();return
	for species in range(16):
		await app.choose_friend(species)
		app.pet.set_process(false)
		var m=app.pet.motion
		m.autonomy=false;m.resting=false;m.daily.enabled=false;m.held=false;m.carried=false
		m.cancel_play();m.voice_left=0;m.joy_left=0
		check(Art.data(species).get("sequences",{}).size()==8,"eight new authored actions "+Catalog.IDS[species])
		for kind in Art.KINDS:
			var frames=Art.frames(species,kind)
			check(frames.size()==32,"32 cels "+Catalog.IDS[species]+"/"+kind)
			for i in range(frames.size()):
				var used=frames[i].get_image().get_used_rect()
				check(used.has_area() and used.position.x>=0 and used.position.y>=0 and used.end.x<=256 and used.end.y<=256,"full cel %d/%s/%d"%[species,kind,i])
			check(m.daily.start(m,kind),"start "+Catalog.IDS[species]+"/"+kind)
			m.daily.clock=.8;m.elapsed=.8;m.voice_left=0
			for facing in [-1,1]:
				m.facing=facing
				app.pet.advance_frame(0)
				check(app.pet.view.generated_sample.bank=="daily-"+kind,"renderer selects "+Catalog.IDS[species]+"/"+kind)
				check(app.pet.view.generated_sample.frame_mix==0,"no double silhouette "+Catalog.IDS[species]+"/"+kind)
				await capture(Catalog.IDS[species]+"-"+kind+"-"+str(facing))
			for i in range(ceili(preload("res://scripts/daily_behaviors.gd").duration(kind)*60)+2):
				m.advance(1.0/60)
				if m.phase!="daily_action": break
			check(m.phase=="idle" and m.daily.action.is_empty(),"action returns idle "+Catalog.IDS[species]+"/"+kind)
		m.cancel_play();m.feet=Vector2(m.bounds.get_center().x,m.bounds.get_center().y);m.target=m.feet
		var before=m.feet
		check(m.daily.start(m,"run"),"run starts "+str(species))
		for i in range(60): m.advance(1.0/60)
		check(m.feet.distance_to(before)>15 and m.bounds.grow(1).has_point(m.feet),"run actual safe movement "+str(species))
		check(preload("res://scripts/soft_roster_art.gd").sample(m).bank=="daily-run","run retains approved stride "+str(species))
		m.cancel_play();m.daily.start(m,"jump");m.voice_left=0
		var ground=m.feet
		m.daily.clock=0;app.pet.advance_frame(0);var at=app.pet.view.sprite.position.y
		m.daily.clock=.57;app.pet.advance_frame(0)
		check(app.pet.view.sprite.position.y<at-4 and m.feet==ground,"small jump leaves floor anchor stable "+str(species))
		m.cancel_play();check(m.daily.action.is_empty(),"cancel clears action "+str(species))
		m.held=true;check(not m.daily.start(m,"sing"),"held blocks new action "+str(species));m.held=false
		m.carried=true;check(not m.daily.start(m,"work"),"carried blocks new action "+str(species));m.carried=false
		m.visit_id="home_water";m.phase="drink";m.elapsed=.8
		check(Art.active(m) and Art.sample(m).embedded_food,"drink contains exactly one mug "+str(species))
		m.cancel_play();m.autonomy=true;m.daily.cooldown=0;m.daily.enabled=true;m.energy=80;m.satiety=80;m.hydration=80
		m.advance(.1)
		check(m.phase=="daily_action","autonomous variety "+str(species))
		m.cancel_play();m.autonomy=false;m.daily.enabled=false
		print("DAILY_NATIVE_CHECKED ",Catalog.IDS[species])
	app.behavior_panel.open()
	check(app.behavior_panel.panel.visible,"action picker opens")
	check(not app.behavior_panel.typing and app.behavior_panel.bridge.helper_pid<0,"typing reaction starts only on user toggle")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		app.behavior_panel.panel.get_texture().get_image().save_png(output().path_join("행동-선택창.png"))
	app.behavior_panel.panel.hide()
	if OS.get_cmdline_user_args().has("--record-daily") and DisplayServer.get_name()!="headless": await record()
	var file=FileAccess.open(output().path_join("daily-validation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"checks":checks,"captures":captures},"\t"))
	print("DAILY_VALIDATED ",checks.size()," captures=",captures.size()," passed=",not failed)
	get_tree().quit(4 if failed else 0)
func record() -> void:
	for species in [3,0,15]:
		await app.choose_friend(species)
		app.pet.set_process(false)
		var m=app.pet.motion
		m.autonomy=false;m.daily.enabled=false;m.resting=false
		var path=output().path_join("replay-"+Catalog.IDS[species]);DirAccess.make_dir_recursive_absolute(path)
		for kind in ["sing","study","work","pajama"]:
			m.cancel_play();m.daily.start(m,kind);m.voice_left=0
			for tick in range(ceili(float(Art.data(species).sequences[kind].duration)*30)):
				app.pet.advance_frame(1.0/30)
				await RenderingServer.frame_post_draw
				var origin=Vector2i(m.feet)-Vector2i(85,110)
				var image: Image=app.pet.get_texture().get_image()
				var rect=Rect2i(origin-app.pet.position,Vector2i(170,140))
				image.get_region(rect).save_png(path.path_join(kind+"-%03d.png"%tick))
