extends Node
var app
var checks=[]
var failed=false
func check(ok: bool,label: String) -> void:
	checks.append({"passed":ok,"check":label})
	if not ok: failed=true;push_error(label)
func run() -> void:
	print("TRIP_CHECK_STARTED")
	await get_tree().process_frame
	app.set_process(false);app.furniture_room.set_process(false);app.behavior_panel.set_process(false)
	for piece in app.furniture_room.pieces.values(): piece.hide();piece.set_process(false)
	for prop in app.props.values(): prop.hide();prop.set_process(false)
	var folder=OS.get_executable_path().get_base_dir().path_join("검수/순차수정/02-넘어지기")
	DirAccess.make_dir_recursive_absolute(folder)
	for species in range(16) if DisplayServer.get_name()=="headless" else [3]:
		await app.choose_friend(species);app.pet.set_process(false)
		print("TRIP_SPECIES ",species)
		var m=app.pet.motion;m.autonomy=false;m.daily.enabled=false;m.cancel_play();m.feet=m.bounds.get_center();m.phase="idle"
		var viewport: SubViewport
		var preview
		if DisplayServer.get_name()!="headless":
			viewport=SubViewport.new();viewport.size=Vector2i(256,224);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			add_child(viewport)
			preview=preload("res://scripts/desktop_pet_view.gd").new();preview.motion=m;viewport.add_child(preview)
		check(m.daily.start(m,"stumble"),"trip can start "+str(species))
		print("TRIP_ACTION_STARTED")
		var stages={};var max_angle=0.0
		for tick in range(84):
			if tick==0: print("TRIP_FIRST_FRAME_BEGIN")
			app.pet.advance_frame(1.0/30)
			if tick==0: print("TRIP_FIRST_FRAME_ADVANCED")
			var sample=app.pet.view.generated_sample
			if sample.get("trip",false):
				stages[sample.bank]=true;max_angle=maxf(max_angle,absf(app.pet.view.sprite.rotation))
				var rect=Rect2(preload("res://scripts/texture_metrics.gd").used_rect(app.pet.view.sprite.texture));var lowest=-INF
				for corner in preload("res://scripts/animation_outline.gd").local_hull(app.pet.view.sprite.texture): lowest=maxf(lowest,(app.pet.view.sprite.transform*corner).y)
				check(absf(lowest-app.pet.view.FEET.y)<.6,"trip stays grounded %d/%d"%[species,tick])
			if DisplayServer.get_name()!="headless":
				m.voice_left=0
				preview.refresh(0)
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(folder.path_join("trip-%03d.png"%tick))
		check(stages.size()==3 and max_angle>1.2,"trip falls, dazes and recovers "+str(species))
		m.advance(.1);check(m.phase=="idle","trip completes "+str(species))
		if is_instance_valid(viewport): viewport.queue_free()
	FileAccess.open(folder.path_join("headless.json" if DisplayServer.get_name()=="headless" else "native.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"checks":checks},"\t"))
	print("TRIP_VALIDATED ",checks.size()," passed=",not failed)
	get_tree().quit(4 if failed else 0)
