extends SceneTree

const Catalog=preload("res://scripts/animal_catalog.gd")
const Emotions=preload("res://scripts/emotion_art.gd")
const Dizzy=preload("res://scripts/dizzy_art.gd")
const Decor=preload("res://scripts/decor_art.gd")
const Generated=preload("res://scripts/generated_species_art.gd")
const Motion=preload("res://scripts/desktop_pet_motion.gd")
const View=preload("res://scripts/desktop_pet_view.gd")
const State=preload("res://scripts/pet_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(Catalog.IDS.size()==16)
	var checked=0
	for species in range(Catalog.IDS.size()):
		for stage in ["baby","adult"]:
			for kind in Emotions.KINDS:
				var frame=Emotions.texture(species,stage,kind)
				assert(frame!=null,"missing expression %s/%s/%s"%[Catalog.IDS[species],stage,kind])
				assert(frame.get_size()==Vector2(256,256))
				var used=frame.get_image().get_used_rect()
				assert(used.has_area() and used.position.x>0 and used.position.y>0 and used.end.x<256 and used.end.y<256)
				checked+=1
	assert(checked==128)
	assert(Decor.icon("acorn")!=null)
	assert(State.PROPS.has("acorn"))
	assert(State.new().unlocked(0,"acorn"))
	var motion=Motion.new()
	motion.species=0
	motion.growth_stage=0
	motion.visit_id="acorn"
	motion.phase="prop_use"
	assert(Generated.action_for(motion)=="toy")
	motion.phase="react"
	motion.reaction="angry"
	motion.reaction_time=1.0
	motion.reaction_duration=2.5
	var view=View.new()
	view.motion=motion
	root.add_child(view)
	view.refresh()
	assert(view.sprite.texture==Emotions.texture(0,"baby","angry"))
	var dizzy_checked=0
	for species in range(Catalog.IDS.size()):
		for stage in ["baby","adult"]:
			for i in range(4):
				var dizzy=Dizzy.texture(species,stage,i)
				assert(dizzy!=null,"missing dizzy %s/%s/%d"%[Catalog.IDS[species],stage,i])
				assert(dizzy.get_size()==Vector2(256,256))
				dizzy_checked+=1
	assert(dizzy_checked==128)
	motion.phase="idle"
	motion.reaction=""
	motion.begin_dizzy()
	assert(motion.phase=="dizzy" and motion.landing_left>0)
	motion.advance(.5)
	view.refresh()
	assert(view.sprite.texture==Dizzy.texture(0,"baby",0))
	motion.advance(Motion.DIZZY_DURATION)
	assert(motion.phase=="idle")
	print("EMOTION_TOY_TEST_PASSED: %d expression and %d dizzy cels"%[checked,dizzy_checked])
	quit()
