extends Node
const Smooth=preload("res://scripts/smooth_species_art.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
var app
var records: Array=[]
func fail(message: String) -> void:
	push_error(message)
	get_tree().quit(3)
func capture(label: String) -> bool:
	app.pet.view.refresh()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var pet=app.pet
	var sample: Dictionary=pet.view.generated_sample
	if not sample.get("soft_roster",false):
		fail("Old skin route: "+label)
		return false
	var image: Image=pet.get_texture().get_image()
	var rect: Rect2i=image.get_used_rect()
	if not rect.has_area():
		fail("Empty native render: "+label)
		return false
	var out: String=OS.get_executable_path().get_base_dir().path_join("검수/전체동물")
	DirAccess.make_dir_recursive_absolute(out)
	image.get_region(rect.grow(4).intersection(Rect2i(Vector2i.ZERO,image.get_size()))).save_png(out.path_join(label+".png"))
	records.append({"species":Catalog.IDS[pet.species],"stage":Smooth.stage(pet.motion),"requested_phase":pet.motion.phase,"bank":sample.bank,"index":sample.index,"new_skin":true,"facing":pet.motion.facing,"native_size":[rect.size.x,rect.size.y],"file":label+".png","atlas_sha256":FileAccess.get_sha256(Smooth.asset_root(pet.species)+"walk.png")})
	return true
func run() -> void:
	await get_tree().process_frame
	for species in range(Catalog.IDS.size()):
		await app.choose_friend(species)
		if not is_instance_valid(app.pet) or app.pet.species!=species:
			fail("Selection failed: "+Catalog.IDS[species])
			return
		var pet=app.pet
		pet.set_process(false)
		var m=pet.motion
		m.autonomy=false
		m.resting=true
		m.held=false
		m.carried=false
		m.pointer_grab=false
		m.landing_left=0
		m.voice_left=0
		for stage in [0,2]:
			m.growth_stage=stage
			m.growth_scale=.93 if stage==0 else 1.0
			pet.view.prewarm_current_art()
			var metadata: Dictionary=Smooth.spec(m)
			if int(metadata.count)!=96 or not is_equal_approx(float(metadata.cycle_seconds),1.6*(2.0/3.0)/1.3):
				fail("Walk metadata mismatch")
				return
			for facing in [1,-1]:
				m.cancel_play()
				m.phase="wander"
				m.facing=facing
				m.joy_left=0
				for phase in [.125,.625]:
					m.walk_phase=phase
					var label: String="%s-%d-%d-%d"%[Catalog.IDS[species],stage,facing,int(phase*96)]
					if not await capture(label): return
					if app.pet.view.generated_sample.bank!="walk" or app.pet.view.generated_sample.index!=int(phase*96):
						fail("Walk frame routing mismatch")
						return
			m.facing=1
			for action in ["idle","pet","doze","eat"]:
				m.cancel_play()
				m.phase=action
				m.joy_left=0
				m.elapsed=.45
				m.action_left=30
				m.food_id=0
				m.visit_id="hand_feed" if action=="eat" else ""
				if action=="pet":
					m.cooldown=0
					pet.menu_action(0)
				if not await capture("%s-%d-%s"%[Catalog.IDS[species],stage,action]): return
				var expected_bank: String={"doze":"sleep"}.get(action,action)
				if app.pet.view.generated_sample.bank!=expected_bank:
					fail("Basic care bank mismatch: "+Catalog.IDS[species]+" "+action)
					return
			# Exercise the game's actual travel method, with its rendered scale.
			var start: Vector2=m.feet
			m.phase="wander"
			m.target=start+Vector2(300,0)
			m.smooth_walk_cycle.reset()
			for tick in range(96): m.advance_travel(float(metadata.cycle_seconds)/96.0,1.0)
			var expected: float=m.smooth_walk_cycle.stride_length(m,metadata)
			if absf(m.feet.x-start.x-expected)>.01:
				fail("Travel/cycle mismatch: "+Catalog.IDS[species])
				return
			m.feet=start
			m.target=start
			m.smooth_walk_cycle.reset()
		print("ROSTER_NATIVE_CHECKED ",Catalog.IDS[species])
	var out: String=OS.get_executable_path().get_base_dir().path_join("검수/native-validation.json")
	var file=FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":2,"full_game":true,"species_count":16,"records":records,"new_actions_for_14":"idle, pet, sleep, eat: 32 complete raster cels each; approved walks retained"},"\t"))
	print("ROSTER_NATIVE_VALIDATED ",records.size())
	get_tree().quit()
