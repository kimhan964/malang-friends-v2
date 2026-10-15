extends Node
const View=preload("res://scripts/desktop_pet_view.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const Main=preload("res://scripts/main.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
const Food=preload("res://scripts/food_catalog.gd")
const Decor=preload("res://scripts/decor_art.gd")
const Emotions=preload("res://scripts/emotion_art.gd")
const Dizzy=preload("res://scripts/dizzy_art.gd")
const Outfits=preload("res://scripts/outfit_catalog.gd")
const State=preload("res://scripts/pet_state.gd")
func _ready() -> void: call_deferred("run")
func run() -> void:
	var packs=preload("res://scripts/animal_pack_manager.gd").new()
	add_child(packs)
	var failures=0
	var poses=0
	var natural_foods=0
	var outfit_options=0
	var outfit_images=0
	var emotion_images=0
	var dizzy_images=0
	var walk_images=0
	var new_walk_images=0
	var struggle_images=0
	var hold_transition_images=0
	var app=Main.new()
	app.free()
	var icon=Image.new()
	if preload("res://scripts/asset_images.gd").decode_into(icon,"res://assets/icon/pet-icon.png")!=OK: failures+=1
	for species in range(16):
		if not packs.available(species):
			var id: String=Catalog.IDS[species]
			var spec: Dictionary=packs.manifest.animals[id]
			if not packs.mount_verified(packs.local_root.path_join(str(spec.file)),id) and not packs.mount_verified(packs.pack_path(id),id):
				print("PACKAGE_NOT_INSTALLED=",id)
				continue # A small installation intentionally does not contain every pet.
		print("PACKAGE_SPECIES=",species)
		if Food.icon_for(species,Catalog.DEFAULT_MEALS[species])==null or Food.title_for(species,Catalog.DEFAULT_MEALS[species]).is_empty(): failures+=1
		else: natural_foods+=1
		for style in range(1,4):
			if Outfits.style_name(species,style).is_empty(): failures+=1
			else: outfit_options+=1
		var motion=Motion.new()
		motion.species=species
		motion.rabbit_pilot=species==0
		motion.smooth_walk_enabled=species>0
		motion.food_id=0
		var view=View.new()
		view.motion=motion
		add_child(view)
		for stage in [0,1,2]:
			motion.growth_stage=stage
			motion.growth_scale=State.GROWTH_SCALES[stage]
			if stage!=1:
				var stage_name="baby" if stage==0 else "adult"
				for name in preload("res://scripts/hold_transition_art.gd").NAMES:
					var bridge=preload("res://scripts/hold_transition_art.gd").frames(species,stage_name,name)
					if bridge.size()!=17: failures+=1
					else: hold_transition_images+=bridge.size()
				var struggle=preload("res://scripts/struggle_art.gd").frames(species,stage_name)
				if struggle.size()!=60: failures+=1
				else: struggle_images+=struggle.size()
				var camera=preload("res://scripts/hold_camera.gd").entries(species,stage_name)
				if camera.size()!=60: failures+=1
				for entry in camera:
					if not is_finite(float(entry.scale)) or entry.scale<.95 or entry.scale>1.05: failures+=1
				var new_walk=preload("res://scripts/rabbit_pilot_art.gd").frames(stage_name,"walk") if species==0 else preload("res://scripts/smooth_species_art.gd").frames(species,stage_name)
				if new_walk.size()!=60: failures+=1
				else: new_walk_images+=new_walk.size()
				for kind in Emotions.KINDS:
					var emotion=Emotions.texture(species,stage_name,kind)
					if emotion==null or emotion.get_size()!=Vector2(256,256): failures+=1
					else: emotion_images+=1
				for i in range(4):
					var dizzy=Dizzy.texture(species,stage_name,i)
					if dizzy==null or dizzy.get_size()!=Vector2(256,256): failures+=1
					else: dizzy_images+=1
				walk_images+=new_walk.size()
				for style in range(1,4):
					for color in range(6):
						var garment=view.outfit_layer.outfit_texture(species,stage_name,style,color)
						if garment==null or garment.get_width()!=256 or garment.get_height()!=256: failures+=1
						else: outfit_images+=1
			for action in ["idle","eat","drink","doze","playful","wander","look","react"]:
				motion.phase=action
				motion.reaction="greet"
				motion.elapsed=.4
				motion.reaction_time=.4
				poses+=1
				motion.walk_phase=.47
				motion.visit_id="hand_feed"
				view.refresh()
				if view.sprite.texture==null: failures+=1
		view.free()
	if Decor.icon("water")==null: failures+=1
	print("HOLD_TRANSITION_IMAGES=",hold_transition_images)
	if Decor.icon("acorn")==null or not State.PROPS.has("acorn"): failures+=1
	print("PACKAGE_POSES=",poses," NATURAL_FOODS=",natural_foods," OUTFITS=",outfit_options," OUTFIT_IMAGES=",outfit_images," EMOTION_IMAGES=",emotion_images," DIZZY_IMAGES=",dizzy_images," WALK_IMAGES=",walk_images," NEW_WALK_IMAGES=",new_walk_images," STRUGGLE_IMAGES=",struggle_images," FAILURES=",failures)
	get_tree().quit(0 if failures==0 else 1)
