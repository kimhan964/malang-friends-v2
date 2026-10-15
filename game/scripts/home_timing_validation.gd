extends Node
var app
var checks=[]
var failed=false
const Home=preload("res://scripts/home_animation.gd")
const Daily=preload("res://scripts/daily_behaviors.gd")
func check(ok: bool,label: String) -> void:
	checks.append({"passed":ok,"check":label})
	if not ok: failed=true;push_error(label)
func out() -> String:
	var path=OS.get_executable_path().get_base_dir().path_join("검수/생활시간과바구니")
	DirAccess.make_dir_recursive_absolute(path);return path
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var origin=Vector2i(app.pet.motion.feet)-Vector2i(130,155)
	var image=Image.create(300,200,false,Image.FORMAT_RGBA8);image.fill(Color("faf8f3"))
	var rect=Rect2i(origin,image.get_size())
	for window in [app.props.basket,app.pet]:
		var pic: Image=window.get_texture().get_image()
		var region=rect.intersection(Rect2i(window.position,pic.get_size()))
		if region.has_area(): image.blend_rect(pic,Rect2i(region.position-window.position,region.size),region.position-origin)
	image.save_png(out().path_join(name+".png"))
func run() -> void:
	await get_tree().process_frame
	app.set_process(false);app.furniture_room.set_process(false);app.behavior_panel.set_process(false)
	for piece in app.furniture_room.pieces.values(): piece.hide();piece.set_process(false)
	for prop in app.props.values(): prop.hide();prop.set_process(false)
	for species in range(16 if DisplayServer.get_name()=="headless" else 1):
		await app.choose_friend(species if DisplayServer.get_name()=="headless" else 3)
		app.pet.set_process(false)
		var m=app.pet.motion;m.autonomy=false;m.daily.enabled=false;m.resting=false
		for id in Home.KINDS:
			if id=="basket": continue
			m.cancel_play();m.feet=m.bounds.get_center();m.visit(m.feet,"home_use",id,true)
			m.advance(.01)
			var base=Home.base_duration(id)
			check(m.phase=="home_use" and absf(m.action_left-base*4)<.02,"duration initialized 4x %d/%s"%[m.species,id])
			m.advance(base+.1)
			check(m.phase=="home_use","remains active past previous end %d/%s"%[m.species,id])
			m.advance(base*3-.2)
			check(m.phase=="home_use","remains active until four durations %d/%s"%[m.species,id])
			m.advance(.2)
			check(m.phase=="idle","completes at four durations %d/%s"%[m.species,id])
		for kind in ["drink","sing","study","work","pajama","fight","sad","peek","happy"]:
			m.cancel_play();m.phase="idle";m.daily.start(m,kind)
			var base=float(Daily.DURATIONS[kind])
			m.advance(base+.1)
			check(m.phase=="daily_action","daily persists past prior duration %d/%s"%[m.species,kind])
			m.advance(base*3)
			check(m.phase=="idle","daily ends after 4x %d/%s"%[m.species,kind])
		# The longer toy hug must not be cut off by its separate controller.
		app.furniture_room.place("toy_plush",Vector2(700,400),false)
		m.cancel_play();m.visit_id="home_toy_plush";app.furniture_room.toy_play.arrived(app.furniture_room,m.visit_id)
		m.advance(6.2);app.furniture_room.toy_play.advance(app.furniture_room,6.2)
		check(m.phase=="home_use" and app.furniture_room.toy_play.busy(),"plush controller respects extended duration "+str(m.species))
		app.furniture_room.toy_play.cancel();m.cancel_play()
		var basket=app.props.basket;basket.show();basket.position=Vector2i(m.bounds.get_center())-Vector2i(0,86)
		app.use_desktop_prop("basket")
		for tick in range(1200):
			app.pet.advance_frame(1.0/60);app.advance_basket()
			if m.phase=="home_use": break
		check(m.phase=="home_use" and m.visit_id=="basket","basket click starts dedicated play "+str(m.species))
		check(absf(m.feet.x-basket.feet_point().x)>55,"animal stands beside basket "+str(m.species))
		var origin=m.soft_scene_origin
		for stamp in [.8,1.5,2.5,10.0,Home.duration("basket")-1.0]:
			m.elapsed=stamp;m.action_left=Home.duration("basket")-stamp
			app.advance_basket();app.pet.advance_frame(0)
			check(app.pet.view.generated_sample.bank=="life_play","basket uses whole-body play %d/%s"%[m.species,stamp])
			check(app.pet.view.lifestyle_prop.visible and not m.ball_visible,"basket toy replaces legacy ball request %d/%s"%[m.species,stamp])
			if DisplayServer.get_name()!="headless": await capture("basket-%s"%stamp)
		m.cancel_play();app.advance_basket();app.pet.advance_frame(0)
		check(not basket.wobbling and not app.pet.view.lifestyle_prop.visible,"basket cancellation cleans toy and wobble "+str(m.species))
		basket.hide()
	FileAccess.open(out().path_join("headless.json" if DisplayServer.get_name()=="headless" else "native.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"checks":checks},"\t"))
	print("HOME_TIMING_VALIDATED ",checks.size()," passed=",not failed)
	get_tree().quit(4 if failed else 0)
