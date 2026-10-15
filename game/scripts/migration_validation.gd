extends Node
const Furniture=preload("res://scripts/furniture_catalog.gd")
const Food=preload("res://scripts/food_catalog.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
const State=preload("res://scripts/pet_state.gd")
const Shared=preload("res://scripts/v2_shared_art.gd")
const Home=preload("res://scripts/home_animation.gd")
var app
var checks: Array=[]
var failed=false
func check(value: bool,label: String) -> bool:
	checks.append({"check":label,"passed":value})
	if not value:
		failed=true
		push_error("MIGRATION_CHECK_FAILED "+label)
	return value
func output() -> String:
	var path: String=OS.get_executable_path().get_base_dir().path_join("검수/이식")
	DirAccess.make_dir_recursive_absolute(path)
	return path
func capture(window: Window,label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image=window.get_texture().get_image()
	var used: Rect2i=image.get_used_rect()
	if check(used.has_area(),"native render "+label):
		image.get_region(used.grow(4).intersection(Rect2i(Vector2i.ZERO,image.get_size()))).save_png(output().path_join(label+".png"))
func run() -> void:
	await get_tree().process_frame
	app.set_process(false)
	var room=app.furniture_room
	room.set_process(false)
	app.pet.set_process(false)
	for prop in app.props.values(): prop.hide()
	var m=app.pet.motion
	m.autonomy=false
	m.cancel_play()
	m.joy_left=0
	for id in Furniture.ITEMS:
		var tex: Texture2D=Furniture.texture(id)
		check(tex!=null,"furniture art "+id)
		if tex==null: continue
		check(Furniture.ground_contact(tex)>.85,"ground contact "+id)
		room.place(id,Vector2(app.usable_screen().position)+Vector2(180,300),false)
		if not check(room.pieces.has(id),"place "+id): continue
		var piece=room.pieces[id]
		for scale_value in [.6,1.0,1.6]:
			piece.set_user_scale(scale_value)
			piece.set_mirrored(true)
			check(piece.user_scale==scale_value and piece.mirrored,"scale and flip "+id+" "+str(scale_value))
		piece.set_user_scale(1.0)
		piece.set_mirrored(false)
		await capture(piece,"furniture-"+id)
		room.remove_piece(id)
		check(not room.pieces.has(id),"remove "+id)
		await get_tree().process_frame
	for id in ["acorn","toy-basket","carrot-plush","water-cup","reading-book","heart","music"]:
		check(Shared.texture(id)!=null,"shared prop "+id)
	for id in ["together","table","home","journal"]:
		check(preload("res://scripts/ui_icons.gd").texture(id)!=null,"menu icon "+id)
	for food in range(32): check(Food.icon(food)!=null,"food "+str(food))
	for species in range(16): check(Food.icon_for(species,Catalog.DEFAULT_MEALS[species])!=null,"default meal "+Catalog.IDS[species])
	var fresh=State.new()
	check(fresh.furniture_available("table") and not fresh.furniture_available("daybed"),"fresh home progression")
	fresh.play_affection={"0":12,"3":18}
	check(fresh.furniture_available("daybed") and not fresh.furniture_available("vanity"),"shared unlock at 30")
	for pair in [[0,0],[12,1],[36,2]]:
		fresh.growth={"0":pair[0]}
		check(fresh.growth_stage(0)==pair[1],"growth threshold "+str(pair[0]))
	# A dedicated fixture is the only save written by this validation.
	var fixture_path="user://v2-migration-validation-fixture.json"
	check(not FileAccess.file_exists(fixture_path),"fixture path unused")
	if not failed:
		fresh.save_path=fixture_path
		fresh.selected=15
		fresh.furniture={"sofa":[200,300,true,1.4,3]}
		fresh.furniture_styles={"sofa":{"color":3,"finish":2,"design":0}}
		fresh.home_initialized=true
		fresh.starter_layout_version=1
		fresh.save_game()
		var loaded=State.new()
		loaded.save_path=fixture_path
		loaded.load_game()
		var at: Array=loaded.furniture.get("sofa",[])
		check(not fresh.save_failed and loaded.selected==15 and at.size()==5 and at[0]==200 and at[1]==300 and at[2]==true and is_equal_approx(float(at[3]),1.4) and at[4]==3 and loaded.growth.get("0")==36,"save round trip")
		DirAccess.remove_absolute(fixture_path)
	var screen: Rect2i=app.usable_screen()
	for id in ["daybed","reading_chair","table","record_player"]:
		room.place(id,Vector2(screen.position)+Vector2(400,500),false)
		for other in room.pieces.values(): other.hide()
		room.pieces[id].show()
		var visit_id: String={"daybed":"home_daybed","reading_chair":"home_reading_chair","table":"home_tea","record_player":"home_record_player"}[id]
		for species in [3,0,15,7]:
			await app.choose_friend(species)
			app.pet.set_process(false)
			m=app.pet.motion
			m.autonomy=false
			m.joy_left=0
			m.feet=room.destination_point(visit_id)
			m.target=m.feet
			m.visit_id=visit_id
			m.phase="home_use"
			m.elapsed=1.2
			m.action_left=5
			m.voice_left=0
			app.pet.view.refresh()
			check(Home.available(m),"home available "+Catalog.IDS[species])
			var sample: Dictionary=app.pet.view.generated_sample
			check(sample.get("soft_roster",false),"home new skin "+Catalog.IDS[species]+" "+id)
			check(sample.bank=={"daybed":"life_bed","reading_chair":"idle","table":"eat","record_player":"pet"}[id],"home action "+Catalog.IDS[species]+" "+id)
			await capture(app.pet,"home-"+Catalog.IDS[species]+"-"+id)
			await capture(room.pieces[id],"home-prop-"+id)
		room.remove_piece(id)
	await app.choose_friend(3)
	app.pet.set_process(false)
	m=app.pet.motion
	m.autonomy=false
	var completed: Array=[]
	m.activity_finished.connect(func(id): completed.append(id))
	for action in ["eat","drink"]:
		m.cancel_play()
		m.phase=action
		m.visit_id="hand_feed" if action=="eat" else "home_water"
		m.food_id=Catalog.DEFAULT_MEALS[m.species]
		m.action_left=1.0
		m.elapsed=.5
		m.satiety=20
		m.hydration=20
		m.joy_left=0
		m.voice_left=0
		app.pet.view.refresh()
		await capture(app.pet,"care-"+action)
		for tick in range(12): m.advance(.1)
		check((m.satiety>25 if action=="eat" else m.hydration>25),"care stat "+action)
		check(("hand_feed" if action=="eat" else "home_water") in completed,"care completion "+action)
	m.cancel_play()
	m.can_follow=true
	m.cursor_position=m.feet+Vector2(160,0)
	var start: Vector2=m.feet
	check(m.start_social("follow"),"cursor follow starts")
	for tick in range(120): m.advance(1.0/60.0)
	check(m.feet.x>start.x+1,"cursor follow actual travel")
	m.cancel_play()
	m.feet.y=m.bounds.get_center().y-90
	m.begin_drop(false)
	for tick in range(90): m.advance(1.0/60.0)
	check(absf(m.feet.y-m.bounds.get_center().y)<1,"release returns to floor")
	for id in ["toy_ball","toy_mouse"]:
		room.place(id,Vector2(screen.position)+Vector2(500,screen.size.y-230),false)
		var play=room.toy_play
		m.cancel_play()
		m.feet=room.destination_point("home_"+id)
		m.visit_id="home_"+id
		check(play.arrived(room,"home_"+id),"toy inspect "+id)
		play.advance(room,2.41)
		check(play.stage=="follow","toy follow "+id)
		if play.stage=="follow":
			var target: Vector2=m.target
			m.feet=play.pet_start.lerp(play.pet_goal,.5)
			play.advance(room,.1)
			check(m.target==target,"toy stable target "+id)
			for tick in range(2400):
				m.advance(1.0/60.0)
				play.advance(room,1.0/60.0)
				if not play.busy(): break
			check(not play.busy(),"toy pursuit completes "+id)
		play.cancel()
		play.launch_user(room,id,Vector2(240,0))
		for tick in range(120): play.advance_user(room,1.0/60.0)
		check(not play.user_motion.is_empty() and play.user_motion.get("settled",false),"toy throw settles "+id)
		play.arrived(room,"home_"+id)
		for tick in range(180):
			play.advance_user(room,1.0/60.0)
			if not play.busy(): break
		check(not play.busy(),"toy throw inspect finishes "+id)
		play.cancel()
		room.remove_piece(id)
	app.pet.menu.prepare()
	for section in range(4):
		app.pet.menu.section=section
		app.pet.menu.rebuild()
		app.pet.menu.popup(Rect2i(screen.position+Vector2i(250,100),Vector2i(440,646)))
		await capture(app.pet.menu,"menu-"+str(section))
		app.pet.menu.hide()
	var file=FileAccess.open(output().path_join("migration-validation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"checks":checks,"mode":DisplayServer.get_name(),"save_scope":"isolated in-memory state and dedicated deleted fixture"},"\t"))
	print("MIGRATION_VALIDATED ",checks.size()," passed=",not failed)
	get_tree().quit(3 if failed else 0)
