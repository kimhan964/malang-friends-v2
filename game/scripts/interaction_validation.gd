extends Node
const Catalog=preload("res://scripts/animal_catalog.gd")
const Smooth=preload("res://scripts/smooth_species_art.gd")
const Interactions=preload("res://scripts/v2_interaction_art.gd")
var app
var checks: Array=[]
var captures: Array=[]
var movement: Array=[]
var failed=false
func check(ok: bool,label: String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok:
		failed=true
		push_error("INTERACTION_CHECK_FAILED "+label)
func output() -> String:
	var path: String=OS.get_executable_path().get_base_dir().path_join("검수/상세모션")
	DirAccess.make_dir_recursive_absolute(path)
	return path
func capture(label: String,expected: String) -> void:
	app.pet.view.refresh()
	var sample: Dictionary=app.pet.view.generated_sample
	check(sample.get("soft_roster",false) and sample.bank==expected,"route "+label)
	check(is_equal_approx(absf(app.pet.view.sprite.scale.y),Catalog.DISPLAY_HEIGHT*Catalog.HEIGHTS[app.pet.motion.species]*app.pet.motion.growth_scale/float(sample.height)),"render size "+label)
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image: Image=app.pet.get_texture().get_image()
	var rect: Rect2i=image.get_used_rect()
	check(rect.has_area(),"native pixels "+label)
	if rect.has_area():
		image.get_region(rect.grow(4).intersection(Rect2i(Vector2i.ZERO,image.get_size()))).save_png(output().path_join(label+".png"))
		captures.append({"label":label,"bank":sample.bank,"index":sample.index,"size":[rect.size.x,rect.size.y],"scale":app.pet.view.sprite.scale.y})
func tick(seconds: float) -> void:
	var count: int=ceili(seconds*60)
	for i in range(count): app.pet.advance_frame(seconds/count)
func run() -> void:
	await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--record-interaction"):
		await record()
		return
	app.set_process(false)
	app.furniture_room.set_process(false)
	for prop in app.props.values(): prop.hide()
	for piece in app.furniture_room.pieces.values(): piece.hide()
	check(is_equal_approx(Catalog.DISPLAY_HEIGHT,110.0*2/3),"pet display 2/3")
	for species in range(16):
		await app.choose_friend(species)
		var pet=app.pet
		pet.set_process(false)
		var m=pet.motion
		m.autonomy=false
		m.voice_left=0
		m.food_id=-1
		for stage in [0,2]:
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1.0
			for facing in [1,-1]:
				m.cancel_play()
				m.held=false
				m.resting=true
				m.phase="idle"
				m.facing=facing
				m.elapsed=0
				m.joy_left=0
				m.feet=Vector2(m.bounds.get_center().x,m.bounds.get_center().y)
				m.target=m.feet
				pet.advance_frame(0)
				var stem: String="%s-%d-%d"%[Catalog.IDS[species],stage,facing]
				var metadata: Dictionary=Smooth.spec(m)
				var start: Vector2=m.feet
				m.phase="wander"
				m.target=m.feet+Vector2(facing*400,0)
				m.smooth_walk_cycle.reset()
				for i in range(96): m.advance_travel(float(metadata.cycle_seconds)/96,1.0)
				var new_speed: float=absf(m.feet.x-start.x)/float(metadata.cycle_seconds)
				var old_speed: float=float(metadata.stride)*Catalog.DISPLAY_HEIGHT*Catalog.HEIGHTS[species]*m.growth_scale/float(metadata.reference_height)/float(metadata.cycle_seconds)
				check(absf(new_speed/old_speed-1.0)<.0001,"complete authored stride at current pace "+stem)
				movement.append({"species":Catalog.IDS[species],"stage":stage,"facing":facing,"previous_pixels_per_second":old_speed,"pixels_per_second":new_speed,"ratio":new_speed/old_speed,"cycle_seconds":metadata.cycle_seconds})
				m.cancel_play()
				m.feet=start
				m.target=start
				m.facing=facing
				pet.advance_frame(0)
				var point=Vector2(128,150)
				check(pet.view.sprite.texture.get_image().get_pixelv(Vector2i(point)).a>.3,"opaque grab point "+stem)
				var screen_point: Vector2=Vector2(pet.position)+pet.view.position+pet.view.sprite.transform*point
				pet.begin_pointer(screen_point)
				pet.advance_frame(1.0/60.0)
				await capture(stem+"-touch","touch")
				pet.move_pointer(screen_point+Vector2(facing*55,-140),.08)
				tick(.45)
				check(m.carried and m.pointer_grab and m.held,"lift input "+stem)
				await capture(stem+"-carry","carry")
				var factor: float=absf(pet.view.sprite.scale.y)
				var expected_pivot: Vector2=pet.view.FEET+(m.soft_grab_point-Vector2(128,232))*Vector2(factor*facing,factor)
				check((pet.view.sprite.transform*m.soft_grab_point).distance_to(expected_pivot)<.01,"whole body grip pivot "+stem)
				tick(1.9)
				await capture(stem+"-struggle","struggle")
				tick(.9)
				pet.release_pointer()
				check(m.phase=="drop" and not m.held and not m.carried,"release starts fall "+stem)
				var old_y: float=m.feet.y
				tick(.06)
				check(m.feet.y>=old_y,"fall gravity "+stem)
				await capture(stem+"-fall","landing")
				for i in range(120):
					pet.advance_frame(1.0/60)
					if m.phase=="dizzy": break
				check(m.phase=="dizzy","fall reaches ground "+stem)
				tick(.12)
				await capture(stem+"-landing","landing")
				tick(.50)
				await capture(stem+"-dizzy","dizzy")
				var grounded: Vector2=m.feet
				check(absf(grounded.y-m.bounds.get_center().y)<1 if m.floor_space else absf(grounded.y-m.bounds.end.y)<1,"landing foot ground "+stem)
				tick(3.7)
				await capture(stem+"-recover","recover")
				check(m.feet.is_equal_approx(grounded),"wobble keeps root planted "+stem)
				tick(.55)
				check(m.phase!="dizzy" and m.phase!="drop" and not m.held,"recovered state "+stem)
				# A short gentle release has landing and recovery, but no swirl eyes.
				m.cancel_play()
				m.feet=grounded-Vector2(0,20)
				m.begin_drop(false)
				for i in range(120):
					pet.advance_frame(1.0/60)
					if m.phase=="dizzy": break
				check(not m.soft_dizzy_wobble and m.dizzy_duration<1.2,"gentle landing skips daze "+stem)
				tick(1.2)
				check(m.phase!="dizzy","gentle recovery completes "+stem)
				# Grabbing again interrupts the previous dizziness immediately.
				m.begin_dizzy()
				pet.view.refresh()
				pet.begin_pointer(Vector2(pet.position)+pet.view.position+pet.view.sprite.transform*point)
				pet.advance_frame(0)
				check(m.phase!="dizzy" and pet.view.generated_sample.bank=="touch","interrupt daze with grab "+stem)
				m.cancel_play()
		print("INTERACTION_NATIVE_CHECKED ",Catalog.IDS[species])
	var file=FileAccess.open(output().path_join("interaction-validation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"species":16,"display_scale":2.0/3,"world_speed_multiplier":Catalog.WORLD_SPEED_MULTIPLIER,"movement":movement,"checks":checks,"captures":captures,"mode":DisplayServer.get_name(),"save_scope":"in-memory validation state"},"\t"))
	print("INTERACTION_VALIDATED ",checks.size()," captures=",captures.size()," passed=",not failed)
	get_tree().quit(3 if failed else 0)

func record() -> void:
	app.set_process(false)
	app.furniture_room.set_process(false)
	for prop in app.props.values(): prop.hide()
	for piece in app.furniture_room.pieces.values(): piece.hide()
	await app.choose_friend(3)
	var pet=app.pet
	pet.set_process(false)
	var m=pet.motion
	m.cancel_play()
	m.autonomy=false
	m.resting=true
	m.growth_stage=2
	m.growth_scale=1.0
	m.voice_left=0
	m.joy_left=0
	m.facing=1
	m.feet=m.bounds.get_center()
	m.target=m.feet
	pet.advance_frame(0)
	var ground: Vector2=m.feet-Vector2(pet.position)
	var region=Rect2i(Vector2i(ground)-Vector2i(160,260),Vector2i(320,280))
	var screen_point: Vector2=Vector2(pet.position)+pet.view.position+pet.view.sprite.transform*Vector2(128,145)
	pet.begin_pointer(screen_point)
	var out: String=output().path_join("replay")
	DirAccess.make_dir_recursive_absolute(out)
	var frames: Array=[]
	for frame in range(270):
		if frame<96:
			var t: float=frame/30.0
			pet.move_pointer(screen_point+Vector2(32,-110)*smoothstep(0,.45,t),1.0/30)
		elif frame==96: pet.release_pointer()
		pet.advance_frame(1.0/30)
		m.voice_left=0
		pet.view.refresh()
		await RenderingServer.frame_post_draw
		var image: Image=pet.get_texture().get_image()
		image.get_region(region.intersection(Rect2i(Vector2i.ZERO,image.get_size()))).save_png(out.path_join("%03d.png"%frame))
		frames.append({"frame":frame,"time":frame/30.0,"phase":m.phase,"bank":pet.view.generated_sample.bank,"index":pet.view.generated_sample.index,"feet":[m.feet.x,m.feet.y]})
	var file=FileAccess.open(out.path_join("trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"method":"Native game advance_frame, actual begin/move/release_pointer replay, 30fps simulation capture","frames":frames},"\t"))
	print("INTERACTION_REPLAY_RECORDED ",frames.size())
	get_tree().quit()
