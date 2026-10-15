extends Node
const Catalog=preload("res://scripts/animal_catalog.gd")
const Furniture=preload("res://scripts/furniture_catalog.gd")
const Life=preload("res://scripts/v2_life_art.gd")
const Props=preload("res://scripts/v2_furniture_art.gd")
const State=preload("res://scripts/pet_state.gd")
var app
var checks: Array=[]
var captures: Array=[]
var failed=false
func check(ok: bool,label: String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok: failed=true;push_error("LIFE_CHECK_FAILED "+label)
func output() -> String:
	var path: String=OS.get_executable_path().get_base_dir().path_join("검수/생활놀이")
	DirAccess.make_dir_recursive_absolute(path)
	return path
func capture(piece: Window,label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var origin: Vector2i=piece.position-Vector2i(64,92)
	var rect=Rect2i(origin,Vector2i(340,240))
	var result=Image.create(340,240,false,Image.FORMAT_RGBA8)
	result.fill(Color("faf8f3"))
	for window in [piece,app.pet]:
		var image: Image=window.get_texture().get_image()
		var window_rect=Rect2i(window.position,image.get_size())
		var part: Rect2i=window_rect.intersection(rect)
		if part.has_area(): result.blend_rect(image,Rect2i(part.position-window.position,part.size),part.position-origin)
	result.save_png(output().path_join(label+".png"))
	captures.append(label)
func prepare(room,id: String) -> void:
	if not room.pieces.has(id): room.place(id,Vector2(app.usable_screen().position)+Vector2(380,450),false)
	for other in room.pieces.values(): other.hide();other.set_process(false)
	room.pieces[id].show()
func run() -> void:
	await get_tree().process_frame
	app.set_process(false)
	var room=app.furniture_room
	room.set_process(false)
	for prop in app.props.values(): prop.hide()
	if OS.get_cmdline_user_args().has("--record-life"):
		await record(room)
		return
	var fresh=State.new()
	check(fresh.furniture_available("bathtub") and fresh.furniture_available("toy_plush"),"new bath and plush available without save reset")
	fresh.load_furniture({"bathtub":[20,30,true,1.4,2],"toy_plush":[30,40,false,.7,1],"sofa":[1,2,true,1.2,3]})
	check(fresh.furniture.size()==3 and is_equal_approx(fresh.furniture.bathtub[3],1.4),"new furniture saved format retains old pieces")
	for id in Props.IDS:
		check(Props.frames(id).size()==32,"furniture frames "+id)
		check(Props.sample(id,.9,true).get_image().get_data()!=Props.sample(id,0,false).get_image().get_data(),"furniture motion pixels "+id)
	for species in range(16):
		await app.choose_friend(species)
		app.pet.set_process(false)
		var m=app.pet.motion
		m.autonomy=false;m.resting=true
		for action in ["sofa","bed","play","bath"]:
			check(Life.frames(species,action).size()==32 and Life.frames(species,action,true).size()==17,"whole character life bank "+Catalog.IDS[species]+" "+action)
		for id in ["sofa","daybed","bathtub","toy_plush"]:
			prepare(room,id)
			var piece=room.pieces[id]
			for facing in [1,-1]:
				piece.set_mirrored(facing<0)
				m.cancel_play();m.held=false;m.carried=false;m.joy_left=0
				m.visit_id="home_"+id;m.phase="home_use";m.elapsed=1.2
				m.action_left=5;m.feet=room.destination_point(m.visit_id);m.target=m.feet;m.facing=facing;m.voice_left=0
				room._process(0)
				piece._process(.9)
				app.pet.advance_frame(0)
				var action: String={"sofa":"sofa","daybed":"bed","bathtub":"bath","toy_plush":"play"}[id]
				check(app.pet.view.generated_sample.bank=="life_"+action,"home route "+Catalog.IDS[species]+" "+id+" "+str(facing))
				check(app.pet.view.sprite.scale.x*facing>0 and app.pet.view.sprite.rotation==0,"whole-body facing "+Catalog.IDS[species]+" "+id)
				if id=="bathtub": check(app.pet.view.scene_front.visible,"bath rim occlusion "+Catalog.IDS[species])
				await capture(piece,Catalog.IDS[species]+"-"+id+"-"+str(facing))
				m.elapsed=.2;app.pet.view.refresh()
				check(app.pet.view.generated_sample.get("life_transition",false),"enter poses "+Catalog.IDS[species]+" "+id)
				m.elapsed=5;m.action_left=.2;app.pet.view.refresh()
				check(app.pet.view.generated_sample.get("life_transition",false),"leave poses "+Catalog.IDS[species]+" "+id)
			m.phase="home_use";m.elapsed=1;m.action_left=.1;m.energy=20
			m.advance(.2)
			check(m.phase=="idle" and m.visit_id.is_empty(),"home completes "+Catalog.IDS[species]+" "+id)
			room._process(0)
			check(not piece.active,"furniture stops after use "+id)
			m.visit_id="home_"+id;m.phase="home_use";m.elapsed=2;m.action_left=5
			m.cancel_play();room._process(0);app.pet.view.refresh()
			check(not app.pet.view.scene_front.visible and not Life.active(m),"interruption clears life props "+id)
			if id in Props.IDS:
				for scale_value in [.6,1.0,1.6]:
					piece.set_user_scale(scale_value)
					m.phase="home_use";m.visit_id="home_"+id;m.elapsed=1.2;m.action_left=5
					m.feet=room.destination_point(m.visit_id);m.target=m.feet
					piece.set_appearance({"color":3,"finish":2,"design":0})
					room._process(0);app.pet.advance_frame(0)
					check(m.soft_scene_lift>0 and is_equal_approx(m.soft_scene_lift,(Furniture.ground_contact(piece.sprite.texture)-{"sofa":.76,"daybed":.64,"bathtub":.7}[id])*piece.sprite.texture.get_height()*piece.sprite.scale.y),"seat level follows furniture size "+id+" "+str(scale_value))
					if id=="bathtub": check(app.pet.view.scene_front.scale==piece.sprite.scale and m.soft_scene_style.color==3,"bath foreground size and style")
				piece.set_user_scale(1.0);piece.set_appearance({"color":0,"finish":0,"design":0})
				m.feet=room.destination_point("home_"+id);m.target=m.feet
				room._process(0);app.pet.advance_frame(0)
				var grip=Vector2(128,150)
				var pointer: Vector2=Vector2(app.pet.position)+app.pet.view.position+app.pet.view.sprite.transform*grip
				app.pet.begin_pointer(pointer);app.pet.advance_frame(0)
				var touched: Vector2=Vector2(app.pet.position)+app.pet.view.position+app.pet.view.sprite.transform*grip
				check(pointer.distance_to(touched)<.001,"touch preserves raised furniture pose "+Catalog.IDS[species]+" "+id)
				app.pet.move_pointer(pointer+Vector2(45,-90),.08);app.pet.advance_frame(0)
				var lifted: Vector2=Vector2(app.pet.position)+app.pet.view.position+app.pet.view.sprite.transform*m.soft_grab_point
				check(m.carried and lifted.distance_to(pointer+Vector2(45,-90))<.01,"furniture pickup stays at clicked point "+Catalog.IDS[species]+" "+id)
				m.cancel_play();app.pet.dragging=false
		for id in ["toy_ball","toy_mouse","toy_plush"]:
			prepare(room,id)
			m.cancel_play();m.held=false;m.carried=false;m.joy_left=0
			m.feet=room.destination_point("home_"+id);m.target=m.feet;m.visit_id="home_"+id
			var play=room.toy_play
			check(play.arrived(room,m.visit_id),"toy arrival "+Catalog.IDS[species]+" "+id)
			play.advance(room,1.0);app.pet.advance_frame(0)
			check(app.pet.view.generated_sample.bank=="life_play","toy contact pose "+Catalog.IDS[species]+" "+id)
			if id=="toy_plush":
				check(not room.pieces[id].visible and m.soft_toy_prop==id,"plush in paws "+Catalog.IDS[species])
				m.cancel_play();play.advance(room,.1)
				check(room.pieces[id].visible and m.soft_toy_prop.is_empty(),"plush returns after interruption "+Catalog.IDS[species])
			else:
				play.advance(room,1.41)
				check(play.stage=="follow" and m.phase=="visit","toy nudge then walk "+Catalog.IDS[species]+" "+id)
				var target: Vector2=m.target
				var before: Vector2i=room.pieces[id].position
				for tick in range(5000):
					m.advance(1.0/60);play.advance(room,1.0/60)
					if not play.busy(): break
				check(not play.busy(),"toy play completes "+Catalog.IDS[species]+" "+id)
				check(not m.soft_toy_contact,"toy pose resets "+Catalog.IDS[species]+" "+id)
			play.cancel()
		print("LIFE_NATIVE_CHECKED ",Catalog.IDS[species])
	# Actual throw friction, subpixel travel, stable goal and rolling.
	var m=app.pet.motion
	prepare(room,"toy_ball")
	m.cancel_play();m.held=false;m.carried=false
	room.toy_play.launch_user(room,"toy_ball",Vector2(240,0))
	var goal: Vector2=m.target
	var start: float=room.pieces.toy_ball.position.x
	for tick in range(30): room.toy_play.advance_user(room,1.0/60)
	check(room.pieces.toy_ball.position.x>start+30 and m.target==goal,"thrown ball travels toward stable destination")
	check(absf(room.pieces.toy_ball.roll_angle)>.1,"ball rotation follows actual distance")
	m.held=true;room.toy_play.advance_user(room,.1)
	check(not room.toy_play.busy(),"pickup cancels toy pursuit")
	var file=FileAccess.open(output().path_join("life-validation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"check_count":checks.size(),"checks":checks,"captures":captures},"\t"))
	print("LIFE_VALIDATED ",checks.size()," captures=",captures.size()," passed=",not failed)
	get_tree().quit(4 if failed else 0)
func record(room) -> void:
	var selected=3
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--record-species="): selected=Catalog.IDS.find(argument.trim_prefix("--record-species="))
	await app.choose_friend(maxi(0,selected))
	var pet=app.pet
	pet.set_process(false)
	var m=pet.motion
	m.autonomy=false;m.resting=true
	for id in ["sofa","daybed","bathtub","toy_plush","toy_ball"]:
		prepare(room,id)
		var piece=room.pieces[id]
		m.cancel_play();m.held=false;m.carried=false;m.voice_left=0;m.joy_left=0
		m.feet=room.destination_point("home_"+id);m.target=m.feet
		room.use_piece(id)
		var dir: String=output().path_join("replay-"+Catalog.IDS[m.species]+"-"+id)
		DirAccess.make_dir_recursive_absolute(dir)
		var trace: Array=[]
		var count: int=900 if id=="toy_ball" else ceili((preload("res://scripts/home_animation.gd").duration("home_"+id)+1.0)*30)
		for tick in range(count):
			pet.advance_frame(1.0/30)
			room._process(1.0/30)
			piece._process(1.0/30)
			pet.view.refresh()
			m.voice_left=0
			await RenderingServer.frame_post_draw
			var origin: Vector2i=piece.position-Vector2i(80,92)
			var result=Image.create(340,240,false,Image.FORMAT_RGBA8)
			result.fill(Color("faf8f3"))
			var rect=Rect2i(origin,result.get_size())
			for window in [piece,pet]:
				if not window.visible: continue
				var image: Image=window.get_texture().get_image()
				var part: Rect2i=Rect2i(window.position,image.get_size()).intersection(rect)
				if part.has_area() and window.visible: result.blend_rect(image,Rect2i(part.position-window.position,part.size),part.position-origin)
			result.save_png(dir.path_join("%03d.png"%tick))
			trace.append({"frame":tick,"time":tick/30.0,"phase":m.phase,"bank":pet.view.generated_sample.bank,"index":pet.view.generated_sample.index,"feet":[m.feet.x,m.feet.y],"toy_position":[piece.position.x,piece.position.y],"piece_visible":piece.visible,"plush_in_paws":not m.soft_toy_prop.is_empty()})
			if id=="toy_ball" and tick>90 and not room.toy_play.busy() and m.phase=="idle": break
		var file=FileAccess.open(dir.path_join("trace.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(trace,"\t"))
		room.toy_play.cancel()
		print("LIFE_REPLAY ",id)
	get_tree().quit()
