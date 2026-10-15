extends Node
var app
var failed=false
var checks=[]
func check(ok: bool,label: String) -> void:
	checks.append({"passed":ok,"check":label})
	if not ok: failed=true;push_error("DISCOVERY_CHECK_FAILED "+label)
func output() -> String:
	var path=OS.get_executable_path().get_base_dir().path_join("검수/해금과모험")
	DirAccess.make_dir_recursive_absolute(path);return path
func run() -> void:
	await get_tree().process_frame
	app.set_process(false);app.furniture_room.set_process(false);app.behavior_panel.set_process(false)
	var room=app.furniture_room
	check(room.pieces.has("bathtub") and app.state.home_owned.has("bathtub"),"actual bathtub introduced into existing starter home")
	room.place("bathtub",Vector2(600,400),false)
	for piece in room.pieces.values(): piece.hide();piece.set_process(false)
	for prop in app.props.values(): prop.hide()
	var fresh=preload("res://scripts/pet_state.gd").new()
	var info=preload("res://scripts/action_unlock_info.gd")
	for species in range(16):
		for row in preload("res://scripts/action_codex_data.gd").ROWS:
			for item in row[2]:
				var spec=preload("res://scripts/action_codex_data.gd").descriptor(species,item[0],item[1])
				if spec.is_empty(): continue
				if item.size()>3: spec.route=item[3]
				var detail=info.details(spec,fresh,species)
				check(not detail.how.is_empty() and not detail.status.is_empty(),"codex has route and condition %d/%s"%[species,spec.key])
	for pair in [[0,false,false],[7,false,false],[8,true,false],[19,true,false],[20,true,true]]:
		fresh.play_affection={"0":pair[0]}
		check(preload("res://scripts/behavior_unlocks.gd").available(fresh.home_points(),"roll")==pair[1],"roll actual unlock "+str(pair[0]))
		check(preload("res://scripts/behavior_unlocks.gd").available(fresh.home_points(),"fly")==pair[2],"flight actual unlock "+str(pair[0]))
	fresh.play_affection={}
	var bed_spec={"key":"life/bed","bank":"life","action":"bed"}
	check(not info.details(bed_spec,fresh,0).open and info.details(bed_spec,fresh,0).threshold==30,"bed uses existing 30 point unlock")
	fresh.home_owned.daybed=true
	check(info.details(bed_spec,fresh,0).open,"previously owned furniture stays unlocked")
	var tub_spec={"key":"life/bath","bank":"life","action":"bath"}
	check(info.details(tub_spec,fresh,0).open,"bathtub available from beginning")
	check(info.details({"key":"daily/pajama","bank":"daily","action":"pajama"},fresh,0).open,"night condition does not falsely lock direct pajama action")
	var tub=room.pieces.bathtub;tub.show()
	for species in range(1 if OS.get_cmdline_user_args().has("--quick") else 16):
		await app.choose_friend(species)
		app.pet.set_process(false)
		var m=app.pet.motion
		m.autonomy=false;m.daily.enabled=false;m.resting=false;m.cancel_play();m.joy_left=0
		for mode in ["click","drop"]:
			m.cancel_play();m.held=false;m.carried=false;m.voice_left=0
			tub.position.x=roundi(m.bounds.get_center().x-80);room.floor_piece(tub)
			var point=room.destination_point("home_bathtub")
			m.feet=point+Vector2(-90,0);m.target=m.feet
			if mode=="click":
				var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=Vector2(tub.size)*.5
				tub.handle_input(press)
				# Mouse-up may already have happened when the queued press is handled.
				tub._process(0)
				var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=press.position
				tub.handle_input(release)
			else:
				m.feet=tub.art_point(Vector2(.5,.55));m.held=true;m.carried=true;m.pointer_grab=true;app.pet.dragging=true
				app.pet.release_pointer()
			var entered=false
			for tick in range(1800):
				app.pet.advance_frame(1.0/60);room._process(1.0/60)
				if m.phase=="home_use" and m.visit_id=="home_bathtub": entered=true;break
			check(entered,"bath actual approach %d/%s"%[species,mode])
			if entered:
				for tick in range(75): app.pet.advance_frame(1.0/60);room._process(1.0/60)
				check(app.pet.view.generated_sample.bank=="life_bath","bath animation %d/%s"%[species,mode])
				check(tub.active and app.pet.view.scene_front.visible,"bath water and front rim %d/%s"%[species,mode])
				if DisplayServer.get_name()!="headless" and species in [0,3,15]:
					await RenderingServer.frame_post_draw
					var origin=tub.position-Vector2i(60,95);var result=Image.create(300,220,false,Image.FORMAT_RGBA8);result.fill(Color("faf8f3"));var rect=Rect2i(origin,result.get_size())
					for window in [tub,app.pet]:
						var image: Image=window.get_texture().get_image();var part=Rect2i(window.position,image.get_size()).intersection(rect)
						if part.has_area(): result.blend_rect(image,Rect2i(part.position-window.position,part.size),part.position-origin)
					result.save_png(output().path_join("bath-%d-%s.png"%[species,mode]))
		m.cancel_play()
		for drink_route in ["home_water","home_tea","daily"]:
			m.cancel_play();m.feet=m.bounds.get_center();m.target=m.feet;m.voice_left=0
			if drink_route=="daily": m.daily.start(m,"drink")
			else:
				m.phase="drink" if drink_route=="home_water" else "home_use"
				m.visit_id=drink_route;m.action_left=7.2;m.elapsed=0
			for tick in range(12):
				app.pet.advance_frame(1.0/12)
				check(app.pet.view.generated_sample.get("embedded_food",false),"drinking cel owns mug %d/%s/%d"%[species,drink_route,tick])
				check(not app.pet.view.lifestyle_prop.visible,"no duplicate prop mug %d/%s/%d"%[species,drink_route,tick])
				check(not app.pet.view.sprite.material.get_shader_parameter("has_meal"),"no duplicate shader mug %d/%s/%d"%[species,drink_route,tick])
			if DisplayServer.get_name()!="headless" and species==3:
				await RenderingServer.frame_post_draw
				var image: Image=app.pet.get_texture().get_image()
				var rect=image.get_used_rect().grow(8).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
				image.get_region(rect).save_png(output().path_join("single-cup-%s.png"%drink_route))
		m.cancel_play()
		if not OS.get_cmdline_user_args().has("--bath-only"):
			for kind in ["roll","fly"]:
				m.behavior_points=0
				check(not m.daily.start(m,kind),"locked action cannot be invoked %d/%s"%[species,kind])
				m.behavior_points=20;m.feet=m.bounds.get_center();m.target=m.feet
				check(m.daily.start(m,kind),"unlocked action starts %d/%s"%[species,kind])
				check(preload("res://scripts/adventure_art.gd").frames(species,kind).size()==32,"whole adventure cels %d/%s"%[species,kind])
				var before=m.feet
				for tick in range(90): m.advance(1.0/60)
				app.pet.advance_frame(0)
				check(app.pet.view.generated_sample.bank=="adventure-"+kind,"new adventure renderer %d/%s"%[species,kind])
				check(absf(m.feet.x-before.x)>5 and absf(m.feet.y-before.y)<1,"adventure movement and floor anchor %d/%s"%[species,kind])
				if kind=="fly": check(app.pet.view.generated_sample.flight_lift>50,"flight rises smoothly "+str(species))
				if DisplayServer.get_name()!="headless":
					await RenderingServer.frame_post_draw
					var image: Image=app.pet.get_texture().get_image();var rect=image.get_used_rect().grow(8).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
					image.get_region(rect).save_png(output().path_join("adventure-%d-%s.png"%[species,kind]))
				for tick in range(500): m.advance(1.0/60)
				check(m.phase=="idle" and m.daily.action.is_empty(),"adventure lands and finishes %d/%s"%[species,kind])
				m.cancel_play()
	if DisplayServer.get_name()!="headless":
		var book=preload("res://scripts/action_codex.gd").new();app.pet.add_child(book);book.state=app.state
		for points in [0,8,20]:
			app.state.play_affection={"3":points};book.open(3)
			var spec=preload("res://scripts/action_codex_data.gd").descriptor(3,"adventure","fly")
			book.select_action(spec,"대나무 프로펠러 비행","")
			await RenderingServer.frame_post_draw
			book.panel.get_texture().get_image().save_png(output().path_join("도감-교감-%d.png"%points))
		book.panel.hide()
		if OS.get_cmdline_user_args().has("--record-adventure"):
			await app.choose_friend(3);app.pet.set_process(false);var m=app.pet.motion;m.autonomy=false;m.daily.enabled=false;m.behavior_points=20
			for kind in ["roll","fly"]:
				m.cancel_play();m.feet=m.bounds.get_center();m.target=m.feet;m.daily.start(m,kind);m.voice_left=0
				var origin=Vector2i(m.feet)-Vector2i(160,180)
				for tick in range(120 if kind=="roll" else 180):
					app.pet.advance_frame(1.0/30)
					await RenderingServer.frame_post_draw
					var image: Image=app.pet.get_texture().get_image();var rect=Rect2i(origin-app.pet.position,Vector2i(460,230))
					image.get_region(rect).save_png(output().path_join(kind+"-%03d.png"%tick))
	var filename="quick-validation.json" if OS.get_cmdline_user_args().has("--quick") else "feature-validation.json"
	FileAccess.open(output().path_join(filename),FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"checks":checks},"\t"))
	print("BATH_E2E_VALIDATED ",checks.size()," passed=",not failed)
	get_tree().quit(4 if failed else 0)
