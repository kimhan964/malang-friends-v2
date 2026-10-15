extends SceneTree
const Tone=preload("res://scripts/animal_tone.gd")
const Art=preload("res://scripts/generated_species_art.gd")
const Home=preload("res://scripts/home_animation.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
var errors=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport=SubViewport.new()
	viewport.size=Vector2i(1536,4096)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var row=0
	for species in range(16):
		for age in ["baby","adult"]:
			var m=Motion.new()
			m.species=species
			m.growth_stage=0 if age=="baby" else 2
			var idle=preload("res://scripts/rabbit_pilot_art.gd").frames(age,"idle")[0] if species==0 else preload("res://scripts/smooth_species_art.gd").frames(species,age,"idle")[0]
			var home=Home.frames(m,"rest")
			var pet=Art.frames(species,age,"pet")
			var struggle=preload("res://scripts/struggle_art.gd").frames(species,age)
			var angry=preload("res://scripts/emotion_art.gd").texture(species,age,"angry")
			var walk=preload("res://scripts/rabbit_pilot_art.gd").frames(age,"walk") if species==0 else preload("res://scripts/smooth_species_art.gd").frames(species,age,"walk")
			var samples=[idle,walk[walk.size()/2],home[home.size()/2],pet[pet.size()/2],angry,struggle[struggle.size()/2]]
			for bank in [walk,home,pet,struggle]:
				var first=Tone.calibrations.get(bank[0].get_instance_id(),{})
				for frame in bank:
					if Tone.calibrations.get(frame.get_instance_id(),{})!=first: errors.append("bank changes tone per frame")
			for column in range(samples.size()):
				var tex=samples[column]
				if not Tone.calibrations.has(tex.get_instance_id()): errors.append("uncalibrated %d/%s/%d"%[species,age,column])
				for calibrated in [false,true]:
					var sprite=Sprite2D.new()
					sprite.centered=false
					sprite.texture=tex
					sprite.scale=Vector2.ONE*.5
					sprite.position=Vector2(column*256+(128 if calibrated else 0),row*128)
					var material=ShaderMaterial.new()
					material.shader=preload("res://scripts/animal_blend.gdshader")
					material.set_shader_parameter("next_frame",tex)
					sprite.material=material
					if calibrated: Tone.apply(material,tex)
					viewport.add_child(sprite)
			row+=1
	if OS.get_cmdline_user_args().has("--capture"):
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var picture=viewport.get_texture().get_image()
		picture.save_png("user://animal-tone-review.png")
		picture.get_region(Rect2i(0,128,1536,128)).save_png("user://rabbit-adult-tone-review.png")
	print("ANIMAL TONE 16 SPECIES BOTH AGES: ","PASS" if errors.is_empty() else errors)
	quit(0 if errors.is_empty() else 1)
