extends Node2D

const Art=preload("res://scripts/animal_catalog.gd")
const BaseArt=preload("res://scripts/base_art.gd")
const Baby=preload("res://scripts/baby_art.gd")
const BabyMeal=preload("res://scripts/baby_meal.gd")
const BabyWalk=preload("res://scripts/baby_walk.gd")
const GeneratedArt=preload("res://scripts/generated_species_art.gd")
const EmotionArt=preload("res://scripts/emotion_art.gd")
const ExpressionBehavior=preload("res://scripts/expression_behavior.gd")
const DizzyArt=preload("res://scripts/dizzy_art.gd")
const Presentation=preload("res://scripts/character_presentation.gd")
var generated_sample: Dictionary={}
var generated_last_action=""
var generated_transition=""
var generated_transition_time=0.0
var baby_walk: Array=[]
const RaccoonPalette=preload("res://scripts/raccoon_palette.gd")
const Metrics=preload("res://scripts/texture_metrics.gd")
const CharacterSize=preload("res://scripts/character_size.gd")
const VisualStyle=preload("res://scripts/pet_visual_style.gd")
const Special=preload("res://scripts/shared_special.gd")
var adult_special: Array=[]
var adult_special_bounds=Rect2i()
const Interactions=preload("res://scripts/prop_interactions.gd")
var interaction_cache: Dictionary={}
var baby_frames: Array=[]
var baby_extra: Array=[]
const Consumption=preload("res://scripts/consumption_art.gd")
const Food=preload("res://scripts/food_catalog.gd")
const Decor=preload("res://scripts/decor_art.gd")
const Profiles=preload("res://scripts/companion_profiles.gd")
const Habits=preload("res://scripts/habit_art.gd")
const Carry=preload("res://scripts/carry_art.gd")
const Sleep=preload("res://scripts/sleep_art.gd")
const Reactions=preload("res://scripts/reaction_art.gd")
var reaction_frames: Array=[]
var sleep_frames: Array=[]
var sleep_bounds=Rect2i()
var carry_frames: Array=[]
var carry_bounds=Rect2i()
var habit_frames: Array=[]
const WINDOW_SIZE=Vector2(256,224)
const FEET=Vector2(128,190)
var motion
var ball_only=false
var sprite: Sprite2D
var resource
var gait_weight=0.0
var presentation_delta=0.0
var settle_offset=Vector3.ZERO
var previous_gait=Vector3.ZERO
var was_walking=false
var window_subpixel=Vector2.ZERO
var voice_font: SystemFont
var outfit_layer
var dizzy_effects
var warmed_art=""
var lifestyle_prop: Sprite2D
var scene_front: Sprite2D

func _ready() -> void:
	voice_font=SystemFont.new()
	voice_font.font_names=PackedStringArray(["Malgun Gothic"])
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	if ball_only: return
	sprite=Sprite2D.new()
	sprite.centered=false
	var generated_material=ShaderMaterial.new()
	generated_material.shader=preload("res://scripts/animal_blend.gdshader")
	sprite.material=generated_material
	add_child(sprite)
	lifestyle_prop=Sprite2D.new()
	lifestyle_prop.z_index=4
	lifestyle_prop.visible=false
	sprite.add_child(lifestyle_prop)
	scene_front=Sprite2D.new()
	scene_front.centered=false
	scene_front.material=preload("res://scripts/furniture_catalog.gd").material()
	scene_front.z_index=5
	scene_front.visible=false
	add_child(scene_front)
	outfit_layer=preload("res://scripts/outfit_layer.gd").new()
	outfit_layer.view=self
	add_child(outfit_layer)
	dizzy_effects=preload("res://scripts/dizzy_effects.gd").new()
	dizzy_effects.view=self
	dizzy_effects.z_index=20
	add_child(dizzy_effects)
	prewarm_current_art()
	return

func prewarm_current_art() -> void:
	if ball_only: return
	var key: String="%d/%s"%[motion.species,GeneratedArt.stage_name(motion)]
	if warmed_art==key: return
	warmed_art=key
	for cel in preload("res://scripts/soft_roster_art.gd").prewarm(motion):
		Metrics.used_rect(cel)
		preload("res://scripts/animation_outline.gd").local_hull(cel)

func refresh(delta: float=0.0) -> void:
	presentation_delta=delta
	if not ball_only:
		show_generated_species()
		show_lifestyle_prop()
		if outfit_layer: outfit_layer.queue_redraw()
		queue_redraw()
		return
	if not ball_only: sprite.material.set_shader_parameter("baby_meal",false)
	var baby_stage=false
	if not ball_only: baby_stage=motion.growth_stage==0 if motion.growth_stage>=0 else motion.growth_scale<.7
	if not ball_only and motion.phase=="prop_use" and show_prop_interaction(baby_stage):
		apply_growth(); queue_redraw()
		return
	if not ball_only and baby_stage and baby_frames.size()==8:
		show_baby()
		apply_growth(); queue_redraw()
		return
	if not ball_only and adult_special.size()==4 and motion.phase=="idle" and not motion.carried and motion.landing_left<=0:
		show_crisp_idle()
		apply_growth(); queue_redraw()
		return
	if not ball_only and adult_special.size()==4 and Special.pose(motion)>=0:
		show_consistent_social_pose()
		apply_growth(); queue_redraw()
		return
	if not ball_only and motion.phase=="react" and reaction_frames.size()==64:
		show_reaction()
		apply_growth(); queue_redraw()
		return
	if not ball_only and motion.phase=="doze" and sleep_frames.size()==4:
		show_sleep_frame()
		apply_growth(); queue_redraw()
		return
	if not ball_only and (motion.carried or motion.landing_left>0) and carry_frames.size()==4:
		show_carry_frame()
		apply_growth(); queue_redraw()
		return
	if not ball_only and motion.phase=="signature" and habit_frames.size()==8:
		show_habit_frame()
		apply_growth(); queue_redraw()
		return
	if not ball_only:
		var walking=motion.phase in ["wander","chase","return","visit"] and not motion.held
		if motion.phase=="signature" and motion.species==2 and motion.elapsed<1.5: walking=true
		var bank=2 if motion.phase=="eat" else (1 if motion.phase=="drink" else 0)
		if motion.species>=8 and motion.phase=="pet": bank=3
		var frames: Array=resource.frames[bank]
		var animated=walking or bank>0
		var cycle=Art.CYCLE_SECONDS[motion.species] if walking else (3.7 if bank in [1,2] else 2.4)
		var phase=fposmod(motion.elapsed/cycle*frames.size(),frames.size()) if animated else 0.0
		if walking and motion.phase!="signature": phase=motion.walk_phase*frames.size()
		var index=floori(phase)
		var next=(index+1)%frames.size() if animated else index
		var blend=0.0 # Independent raster poses must not overlap into dark double silhouettes.
		if bank in [1,2]:
			next=index
			blend=0.0
		var new_meal=motion.species>=8 and bank in [1,2]
		if new_meal:
			var sample=Consumption.sample(motion.species,bank,motion.elapsed)
			index=int(sample.x)
			next=int(sample.y)
			blend=sample.z
		sprite.texture=frames[index]
		var dimensions=sprite.texture.get_size()*(Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]/sprite.texture.get_height())
		if not animated: dimensions*=Vector2(1+sin(motion.elapsed*TAU/4.8)*.004,1-sin(motion.elapsed*TAU/4.8)*.004)
		var at=FEET-Vector2(dimensions.x*.5,dimensions.y)
		if motion.facing<0:
			at.x+=dimensions.x
			dimensions.x=-dimensions.x
		sprite.position=at
		sprite.scale=dimensions/sprite.texture.get_size()
		if motion.phase=="look":
			sprite.position.x+=sin(motion.elapsed*1.8)*2
		elif motion.phase=="sniff": sprite.position.y+=absf(sin(motion.elapsed*3))*2
		elif motion.phase=="stretch":
			var stretch=sin(clampf(motion.elapsed/3,0,1)*PI)
			sprite.scale*=Vector2(1-stretch*.025,1+stretch*.04)
			sprite.position.y-=absf(dimensions.y)*stretch*.04
		elif motion.phase=="doze":
			sprite.scale.y*=.98+sin(motion.elapsed*1.1)*.01
		# Reuse the restaurant's gentle petting sway, squash and lift.
		sprite.rotation=0
		if motion.joy_left>0 or motion.phase in ["groom","cuddle"]:
			var age=(1.8-motion.joy_left)/1.8*2.0 if motion.joy_left>0 else fposmod(motion.elapsed,2)
			var amount=sin(age/2.0*PI)
			sprite.rotation=sin(age*5)*.035*amount*(1 if motion.species%2==0 else -1)
			sprite.position.y-=sin(age*PI)*1.3*amount
			sprite.scale*=Vector2(1+sin(age*6)*.012*amount,1-sin(age*6)*.012*amount)
		sprite.material.set_shader_parameter("next_frame",frames[next])
		sprite.material.set_shader_parameter("frame_mix",blend)
		sprite.material.set_shader_parameter("modern_meal",new_meal)
		var drinking_water=new_meal and bank==1 and motion.visit_id=="water"
		var has_food=bank in [1,2] and motion.food_id>=0 and motion.visit_id in ["bowl","meal","snack","hand_feed"]
		has_food=has_food or drinking_water
		sprite.material.set_shader_parameter("has_meal",has_food)
		if has_food:
			var texture=Decor.icon("water") if drinking_water else Food.icon_for(motion.species,motion.food_id)
			var rect=Food.hand_rect(motion.species,bank,index).lerp(Food.hand_rect(motion.species,bank,next),blend)
			var width=rect.z*1.08
			var height=width*absf(dimensions.x)/dimensions.y/(float(texture.get_width())/texture.get_height())
			# The meal shader can only draw inside the animal sprite's UV rectangle.
			# Fit both axes before positioning, including tall drinks and cakes.
			var fit=minf(1.0,minf(.94/width,.92/height))
			if new_meal: fit=minf(fit,.17/height)
			width*=fit
			height*=fit
			var meal_x=clampf(rect.x+(rect.z-width)*.5,.02,.98-width)
			var meal_y=clampf(rect.y+rect.w-height,.02,.98-height)
			sprite.material.set_shader_parameter("menu_texture",texture)
			sprite.material.set_shader_parameter("old_rect",rect)
			sprite.material.set_shader_parameter("prop_rect",Vector4(meal_x,meal_y,width,height))
			sprite.material.set_shader_parameter("food_bite",bank==2)
			sprite.material.set_shader_parameter("bite_color",Color("e9bd79"))
	apply_growth(); queue_redraw()

func show_generated_species() -> void:
	generated_sample=preload("res://scripts/soft_roster_art.gd").sample(motion)
	sprite.texture=generated_sample.texture
	preload("res://scripts/animal_tone.gd").apply(sprite.material,sprite.texture)
	sprite.rotation=0
	var factor=Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]/generated_sample.height*motion.growth_scale
	var expression=motion.phase=="dizzy" or (motion.phase=="react" and motion.reaction in EmotionArt.KINDS) or (motion.held and not motion.pointer_grab and not motion.carried and motion.joy_left>0)
	var fixed_cels=generated_sample.get("pilot",false) or generated_sample.get("smooth_walk",false) or generated_sample.get("fixed_cels",false)
	var pose={"scale":Vector2.ONE,"anchor":generated_sample.get("anchor",Vector2(128,232))} if fixed_cels else Presentation.pose(motion.species,generated_sample,expression)
	sprite.scale=Vector2(factor*motion.facing,factor)*pose.scale
	sprite.position=FEET-pose.anchor*sprite.scale
	if generated_sample.get("pilot",false): sprite.position+=generated_sample.get("root_offset",Vector2.ZERO)*sprite.scale
	sprite.material.set_shader_parameter("next_frame",generated_sample.get("next_texture",sprite.texture))
	sprite.material.set_shader_parameter("frame_mix",float(generated_sample.get("frame_mix",0.0)))
	sprite.material.set_shader_parameter("fur_match",false)
	sprite.material.set_shader_parameter("has_meal",false)
	sprite.material.set_shader_parameter("baby_meal",false)
	sprite.material.set_shader_parameter("meal_opacity",1.0)
	var water=motion.phase=="drink" and motion.visit_id in ["water","home_water"]
	var serving=motion.phase in ["eat","drink"] and not water and motion.food_id>=0 and motion.visit_id in ["bowl","meal","snack","hand_feed","home_food"]
	var toy=motion.phase=="prop_use" and motion.visit_id=="plant"
	if (serving and not generated_sample.get("embedded_food",false)) or toy:
		var meal: Texture2D=Decor.icon("plant",motion.species) if toy else Food.icon_for(motion.species,motion.food_id)
		var hand: Vector2=generated_sample.hand
		var width=34.0
		var height=minf(47.0,width*meal.get_height()/float(meal.get_width()))
		var rect=Vector4((hand.x-width*.45)/256.0,(hand.y-height*.55)/256.0,width/256.0,height/256.0)
		if serving and motion.phase=="eat":
			var food_pose=preload("res://scripts/eating_timing.gd").food_pose(generated_sample,meal,motion.elapsed)
			rect=food_pose.rect
			hand=food_pose.grip
			sprite.material.set_shader_parameter("meal_opacity",food_pose.opacity)
		sprite.material.set_shader_parameter("has_meal",true)
		sprite.material.set_shader_parameter("baby_meal",motion.phase!="eat")
		sprite.material.set_shader_parameter("modern_meal",true)
		sprite.material.set_shader_parameter("menu_texture",meal)
		sprite.material.set_shader_parameter("old_rect",rect)
		sprite.material.set_shader_parameter("prop_rect",rect)
		sprite.material.set_shader_parameter("baby_grip",Vector4(hand.x/256.0,hand.y/256.0,9.0/256.0,10.0/256.0))
		sprite.material.set_shader_parameter("food_bite",motion.phase!="drink")
	if motion.phase=="drink" and motion.visit_id=="home_water" and not generated_sample.get("embedded_food",false):
		var cup=preload("res://scripts/furniture_catalog.gd").texture("water-cup")
		if cup!=null:
			var cup_pose=preload("res://scripts/eating_timing.gd").cup_pose(generated_sample,cup,motion.elapsed)
			sprite.material.set_shader_parameter("has_meal",true)
			sprite.material.set_shader_parameter("baby_meal",false)
			sprite.material.set_shader_parameter("modern_meal",true)
			sprite.material.set_shader_parameter("food_bite",false)
			sprite.material.set_shader_parameter("menu_texture",cup)
			sprite.material.set_shader_parameter("meal_opacity",cup_pose.opacity)
			sprite.material.set_shader_parameter("old_rect",cup_pose.rect)
			sprite.material.set_shader_parameter("prop_rect",cup_pose.rect)
	# Generated full-character cels still need a small whole-body weight shift.
	# Without it the window travels while the body stays mechanically level,
	# which makes an otherwise valid walk cycle read as skating.
	if not generated_sample.get("soft_roster",false): CharacterSize.apply(self)
	if not fixed_cels: apply_weight_motion()
	apply_generated_action_motion()
	if motion.visit_id=="home_sofa" and motion.phase=="relax":
		var seated=smoothstep(0.0,.5,motion.elapsed)*smoothstep(0.0,.5,motion.action_left)
		sprite.position.y-=18*seated
	if generated_sample.get("home_animation",false):
		var lift={"home_sofa":18.0,"home_reading_chair":22.0,"home_daybed":28.0,"home_bathtub":24.0,"home_window_seat":18.0}.get(motion.visit_id,0.0)
		if generated_sample.get("life_animation",false): lift=motion.soft_scene_lift
		var settled=smoothstep(0.0,.6,motion.elapsed)*smoothstep(0.0,.6,motion.action_left)
		sprite.position.y-=lift*settled
	sprite.position+=window_subpixel
	if generated_sample.get("adventure_animation",false):
		if generated_sample.has("roll_center"):
			var angle=float(generated_sample.roll_angle)
			var center=FEET+Vector2(0,-float(generated_sample.roll_radius)*absf(sprite.scale.y))
			sprite.rotation=angle
			sprite.position=center-(Vector2(generated_sample.roll_center)*sprite.scale).rotated(angle)
		else: sprite.position.y-=float(generated_sample.get("flight_lift",0))
	if generated_sample.get("run_hop",false):
		sprite.position.y-=float(generated_sample.lift)*factor
	elif motion.phase=="daily_action" and motion.daily.action=="jump":
		var p=clampf(motion.daily.clock/1.25,0,1)
		var lift=sin(clampf((p-.12)/.72,0,1)*PI)*15.0*motion.growth_scale
		sprite.position.y-=maxf(0,lift)

func apply_generated_action_motion() -> void:
	if generated_sample.get("soft_roster",false):
		if generated_sample.get("soft_interaction",false) and motion.carried:
			# Whole-character pendulum around the actual clicked point. Limbs
			# and face motion come exclusively from the generated full cels.
			var age: float=maxf(0,motion.carry_elapsed-motion.carry_started_at)
			var angle: float=sin(age*TAU/2.4)*.028*smoothstep(0,.24,age)
			var pivot: Vector2=sprite.transform*motion.soft_grab_point
			sprite.rotation=angle
			sprite.position=pivot-(motion.soft_grab_point*sprite.scale).rotated(angle)
		return
	if generated_sample.is_empty(): return
	if ExpressionBehavior.active(motion):
		var gesture=ExpressionBehavior.pose(motion)
		apply_dizzy_transform(gesture.angle,gesture.offset,Vector2.ONE)
		return
	if motion.carried:
		if motion.is_struggling():
			var age=float(generated_sample.get("hold_loop_age",motion.struggle_age()))
			var amount=smoothstep(0.0,.22,age)
			var angle=sin(age*TAU/1.4)*.065*amount
			# One rigid pendulum around the held upper body; the generated cels
			# supply the kicks. No anatomical transforms or pulsing body scale.
			var grip=sprite.transform*generated_sample.get("grip",Vector2(128,130))
			sprite.position=grip+(sprite.position-grip).rotated(angle)
			sprite.rotation=angle
		return
	if motion.held:
		return
	if motion.phase=="idle" and not motion.hold_release.is_empty() and generated_sample.get("hold_visual",false):
		# A protest can now be released between 2 and 3 seconds without a fall.
		# Preserve its angle on that release too, then settle it gently.
		var inherited=float(motion.hold_release.get("angle",0.0))*(1.0-smoothstep(0.0,.18,motion.hold_release.elapsed))
		var grip=sprite.transform*generated_sample.get("grip",Vector2(128,130))
		sprite.position=grip+(sprite.position-grip).rotated(inherited)
		sprite.rotation=inherited
		return
	if motion.phase=="drop":
		var progress=clampf(motion.elapsed/maxf(.01,motion.drop_duration),0,1)
		var inherited=float(motion.hold_release.get("angle",0.0))*(1.0-smoothstep(0.0,.16,motion.elapsed))
		var grip=sprite.transform*generated_sample.get("grip",Vector2(128,130))
		sprite.position=grip+(sprite.position-grip).rotated(inherited)
		sprite.rotation=inherited
		apply_dizzy_transform(sin(progress*PI)*.09*motion.facing,Vector2.ZERO,Vector2.ONE)
		return
	if motion.phase=="dizzy":
		if motion.landing_left>0:
			var progress=clampf(1.0-motion.landing_left/motion.DIZZY_LANDING,0.0,1.0)
			var squash=sin(clampf(progress/.5,0,1)*PI) if progress<.5 else 0.0
			var rebound=sin(clampf((progress-.5)/.5,0,1)*PI) if progress>=.5 else 0.0
			apply_dizzy_transform(sin(progress*PI)*.07*motion.facing,Vector2(0,squash*3-rebound*6),Vector2.ONE)
		else:
			var age=maxf(0.0,motion.elapsed-motion.DIZZY_LANDING)
			var fade=clampf((motion.DIZZY_DURATION-motion.elapsed)/1.0,0.0,1.0)
			var sway=sin(age*TAU*1.04)
			apply_dizzy_transform(sway*.12*fade,Vector2(sway*6*fade,-absf(sin(age*TAU*2.08))*2*fade),Vector2.ONE)
		return
	if generated_sample.action=="jump":
		var spec=GeneratedArt.data(motion.species).stages[generated_sample.stage].sequences.jump
		var phase=fposmod(motion.elapsed/maxf(.01,float(spec.duration)),1.0)
		var arc=pow(maxf(0.0,sin(phase*PI)),1.12)
		var jump_height=lerpf(18.0,30.0,sqrt(clampf(motion.growth_scale,0.0,1.0)))
		sprite.position.y-=arc*jump_height

func apply_dizzy_transform(angle: float,offset: Vector2,stretch: Vector2) -> void:
	var pivot=Transform2D(angle,stretch,0.0,Vector2.ZERO)
	sprite.position=FEET+pivot*(sprite.position-FEET)+offset
	sprite.rotation+=angle
	sprite.scale*=stretch

func mouth_offset() -> Vector2:
	if not generated_sample.is_empty():
		return sprite.transform*generated_sample.mouth-FEET
	var height=Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]*motion.growth_scale
	return Vector2(motion.facing*8,-height*.55)

func show_adult_special(index: int) -> void:
	var sample=Special.sample(motion)
	var texture: Texture2D=adult_special[index]
	var factor=Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]/maxf(1,adult_special_bounds.size.y)
	sprite.texture=texture
	sprite.rotation=0
	sprite.scale=Vector2(factor*motion.facing,factor)
	sprite.position=FEET-Vector2(texture.get_width()*.5,adult_special_bounds.end.y)*sprite.scale
	sprite.material.set_shader_parameter("has_meal",false)
	sprite.material.set_shader_parameter("frame_mix",sample.z)
	sprite.material.set_shader_parameter("next_frame",adult_special[int(sample.y)])

func accepts_prop_grab(point: Vector2) -> bool:
	if motion.species!=9 or motion.visit_id!="plant": return true
	var area=Metrics.used_rect(sprite.texture)
	var start=sprite.position.x+(area.position.x+area.size.x*.66)*sprite.scale.x
	return point.x>=start-6

func show_prop_interaction(baby: bool) -> bool:
	var key=str(baby)+motion.visit_id
	if not interaction_cache.has(key):
		var sequence=Interactions.frames(motion.species,baby,motion.visit_id)
		if motion.species==4: RaccoonPalette.register(sequence,reaction_frames[0])
		if sequence.size()!=4: return false
		interaction_cache[key]={"frames":sequence,"bounds":Interactions.sequence_bounds(sequence)}
	var entry=interaction_cache[key]
	var texture: Texture2D=entry.frames[Interactions.pose(motion)]
	var used: Rect2i=entry.bounds
	var factor=minf(Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]*1.35/maxf(1,used.size.y),184.0/maxf(1,used.size.x))
	sprite.texture=texture
	sprite.rotation=0
	sprite.scale=Vector2.ONE*factor
	sprite.position=FEET-Vector2(used.position.x+used.size.x*.5,used.end.y)*factor
	sprite.material.set_shader_parameter("has_meal",false)
	sprite.material.set_shader_parameter("frame_mix",0.0)
	sprite.material.set_shader_parameter("next_frame",texture)
	return true

func show_reaction() -> void:
	var row=int(Reactions.ROWS.get(motion.reaction,0))
	# This generated sheet placed the nest and gift rows in the opposite order.
	if motion.species==3 and row in [5,6]: row=11-row
	var plan: Array=[0,1,2,3,4,5,6,7]
	if motion.reaction=="inspect":
		row=2
		plan=[0,2,3,3,4,4,2,0]
	if motion.reaction=="pet":
		if motion.affection<6: plan=[0,1,2,3,2,1,7]
		elif motion.affection>=18: plan=[0,1,2,3,4,4,5,4,5,6,7]
		elif motion.reaction_variant==1: plan=[0,1,2,3,4,3,5,6,7]
	var frame_phase=clampf(motion.reaction_time/motion.reaction_duration*plan.size(),0,plan.size()-.001)
	var slot=floori(frame_phase)
	var index=int(plan[slot])
	var next=int(plan[mini(slot+1,plan.size()-1)])
	var blend=0.0
	if motion.reaction=="anticipate" and motion.reaction_time>.5:
		var offset=motion.cursor_position-motion.feet
		index=5 if offset.length()<110 else (3 if offset.x*motion.facing<0 else 4)
		next=index
		blend=0
	var neutral: Rect2i=Reactions.bounds[motion.species]
	var texture: Texture2D=reaction_frames[row*8+index]
	var factor=minf(Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]/maxf(1,neutral.size.y),174.0/maxf(1,neutral.size.x))
	sprite.texture=texture
	sprite.rotation=0
	sprite.scale=Vector2(factor*motion.facing,factor)
	sprite.position=FEET-Vector2(texture.get_width()*.5,neutral.end.y)*sprite.scale
	sprite.material.set_shader_parameter("has_meal",false)
	sprite.material.set_shader_parameter("next_frame",reaction_frames[row*8+next])
	sprite.material.set_shader_parameter("frame_mix",blend)

func show_sleep_frame() -> void:
	var index=1
	var next=2
	var blend=(1-cos(motion.elapsed*TAU/3.6))*.5
	if motion.elapsed<.7:
		index=0
		next=1
		blend=smoothstep(.2,.7,motion.elapsed)
	elif not motion.stay_after_visit and motion.action_left<.8:
		index=2
		next=3
		blend=1-smoothstep(.15,.8,motion.action_left)
	var factor=minf(Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]*(.65 if motion.species==0 else .85)/maxf(1,sleep_bounds.size.y),170.0/maxf(1,sleep_bounds.size.x))
	var texture: Texture2D=sleep_frames[index]
	var anchor=Vector2(texture.get_width()*.5,sleep_bounds.end.y)
	sprite.texture=texture
	sprite.rotation=0
	sprite.scale=Vector2(factor*motion.facing,factor)
	sprite.position=FEET-anchor*sprite.scale
	sprite.material.set_shader_parameter("has_meal",false)
	sprite.material.set_shader_parameter("next_frame",sleep_frames[next])
	sprite.material.set_shader_parameter("frame_mix",blend)

func show_carry_frame() -> void:
	var index=3
	if motion.carried:
		index=0 if motion.carry_elapsed<.18 else 1+int((motion.carry_elapsed-.18)/.3)%2
	var texture: Texture2D=carry_frames[index]
	var factor=Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]/maxf(1,carry_bounds.size.y)
	var direction=motion.facing
	# First sheet's alternating pose was drawn facing the other direction.
	if motion.species<4 and index==2: direction=-direction
	var anchor=Vector2(texture.get_width()*.5,carry_bounds.end.y)
	sprite.texture=texture
	sprite.rotation=0
	sprite.scale=Vector2(factor*direction,factor)
	sprite.position=FEET-anchor*sprite.scale
	sprite.material.set_shader_parameter("has_meal",false)
	sprite.material.set_shader_parameter("next_frame",texture)
	sprite.material.set_shader_parameter("frame_mix",0.0)

func show_habit_frame() -> void:
	var phase=clampf(motion.elapsed/Profiles.HABIT_SECONDS[motion.species]*8,0,7.999)
	var index=mini(7,floori(phase))
	var next=mini(7,index+1)
	var texture: Texture2D=habit_frames[index]
	var neutral: Rect2i=Habits.neutral_bounds[motion.species]
	var scale_factor=Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]/maxf(1,neutral.size.y)
	var anchor=Vector2(neutral.position.x+neutral.size.x*.5,neutral.end.y)
	sprite.texture=texture
	sprite.rotation=0
	sprite.scale=Vector2(scale_factor*motion.facing,scale_factor)
	sprite.position=FEET-anchor*sprite.scale
	sprite.material.set_shader_parameter("has_meal",false)
	sprite.material.set_shader_parameter("next_frame",habit_frames[next])
	sprite.material.set_shader_parameter("frame_mix",smoothstep(.78,1,phase-index))

func _draw() -> void:
	if not ball_only and motion.is_struggling():
		draw_voice_bubble("내려줄래?",smoothstep(0.0,.2,motion.struggle_age()))
	elif not ball_only and ExpressionBehavior.active(motion):
		var age=motion.reaction_time
		var opacity=smoothstep(0,.15,age)*(1.0-smoothstep(1.1,1.6,age))
		if opacity>0: draw_voice_bubble(motion.reaction_words if not motion.reaction_words.is_empty() else ExpressionBehavior.WORDS[motion.reaction],opacity)
	elif not ball_only and motion.voice_left>0 and not motion.carried and motion.phase not in ["drop","dizzy"]:
		var words=motion.voice_text if not motion.voice_text.is_empty() else motion.VOICES[motion.species]
		draw_voice_bubble(words)
	if ball_only:
		var ball_art=Decor.icon("ball")
		if ball_art:
			var ball_size=ball_art.get_size()
			ball_size*=28.0/maxf(ball_size.x,ball_size.y)
			draw_texture_rect(ball_art,Rect2((Vector2(32,32)-ball_size)*.5,ball_size),false)
			return
		draw_circle(Vector2(16,16),10,Color("be715f"))
		draw_arc(Vector2(16,16),6,-PI*.8,PI*.1,20,Color("fce6b9"),3,true)
		return
	if motion.phase=="prop_use" and motion.species==9 and motion.visit_id=="plant":
		draw_string(ThemeDB.fallback_font,Vector2(18,18),"오른쪽 매듭을 잡아당겨요",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("fff3d5"))
		draw_line(Vector2(72,174),Vector2(132,174),Color("705d49"),4,true)
		draw_line(Vector2(72,174),Vector2(72+60*motion.prop_strength,174),Color("efc778"),4,true)
	if motion.phase=="doze":
		var age=fposmod(motion.elapsed,4.2)
		if age<2.0:
			var at=dizzy_effects.orbit_layout().center+Vector2(14,-age*4)
			draw_string(voice_font,at,"z",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(VisualStyle.MIST,sin(age/2.0*PI)*.6))
	if motion.joy_left>0 and not ExpressionBehavior.active(motion):
		for i in range(1):
			var center=dizzy_effects.orbit_layout().center+Vector2(0,-(1.8-motion.joy_left)*5)
			var points=PackedVector2Array()
			for n in range(33):
				var t=n*TAU/32
				points.append(center+Vector2(16*pow(sin(t),3),-(13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t)))*.21)
			draw_colored_polygon(points,Color(VisualStyle.ROSE,minf(.7,motion.joy_left)))

func visible_pet_bounds() -> Rect2:
	if sprite==null or sprite.texture==null:
		return Rect2(FEET-Vector2(40,80),Vector2(80,80))
	var used=Metrics.used_rect(sprite.texture)
	if not used.has_area():
		return Rect2(FEET-Vector2(40,80),Vector2(80,80))
	var points=[
		sprite.transform*Vector2(used.position),
		sprite.transform*Vector2(used.end.x,used.position.y),
		sprite.transform*Vector2(used.position.x,used.end.y),
		sprite.transform*Vector2(used.end)
	]
	var left=float(points[0].x)
	var right=left
	var top=float(points[0].y)
	var bottom=top
	for point in points:
		left=minf(left,point.x)
		right=maxf(right,point.x)
		top=minf(top,point.y)
		bottom=maxf(bottom,point.y)
	return Rect2(left,top,maxf(1,right-left),maxf(1,bottom-top))

func visible_head_bounds() -> Rect2:
	if sprite==null or sprite.texture==null: return visible_pet_bounds()
	var points=sprite.transform*preload("res://scripts/animation_outline.gd").local_hull(sprite.texture)
	var top=INF
	var bottom=-INF
	for point in points:
		top=minf(top,point.y)
		bottom=maxf(bottom,point.y)
	var left=INF
	var right=-INF
	for point in points:
		if point.y<=top+(bottom-top)*.4:
			left=minf(left,point.x)
			right=maxf(right,point.x)
	if left==INF: return visible_pet_bounds()
	return Rect2(left,top,maxf(1,right-left),(bottom-top)*.4)

func voice_bubble_layout(words: String) -> Dictionary:
	var pet=visible_head_bounds()
	var font_size=13
	var width=clampf(voice_font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+24,48,188)
	var height=28.0
	# Baby artwork is shorter, so its bubble follows its real head instead of
	# remaining at the adult's fixed top-of-window position.
	var canvas=get_viewport_rect().size
	var center_x=clampf(pet.get_center().x,width*.5+6-position.x,canvas.x-position.x-width*.5-6)
	var safe_top=4.0-position.y
	var safe_bottom=maxf(safe_top,canvas.y-position.y-height-12)
	var area_y=clampf(pet.position.y-height-22,safe_top,safe_bottom)
	var area=Rect2(center_x-width*.5,area_y,width,height)
	var tail_x=clampf(pet.get_center().x,area.position.x+16,area.end.x-16)
	var tip_y=minf(pet.position.y-3,area.end.y+5)
	return {"area":area,"tail_x":tail_x,"tip_y":tip_y,"pet":pet}

func draw_voice_bubble(words: String,opacity: float=1.0) -> void:
	var layout=voice_bubble_layout(words)
	var area: Rect2=layout.area
	var tail_x: float=layout.tail_x
	var tip_y: float=layout.tip_y
	var fill=VisualStyle.PAPER
	var border=VisualStyle.LINE
	fill.a=opacity
	border.a=opacity
	var tail=PackedVector2Array([
		Vector2(tail_x-4,area.end.y-1),Vector2(tail_x+4,area.end.y-1),Vector2(tail_x,tip_y)
	])
	draw_colored_polygon(tail,border)
	var bubble=StyleBoxFlat.new()
	bubble.bg_color=fill
	bubble.border_color=border
	bubble.set_border_width_all(1)
	bubble.set_corner_radius_all(9)
	draw_style_box(bubble,area)
	draw_colored_polygon(PackedVector2Array([
		Vector2(tail_x-3,area.end.y-2),Vector2(tail_x+3,area.end.y-2),Vector2(tail_x,tip_y-1)
	]),fill)
	var ink=VisualStyle.INK
	ink.a=opacity
	draw_string(voice_font,area.position+Vector2(12,19),words,HORIZONTAL_ALIGNMENT_CENTER,area.size.x-24,13,ink)

func show_baby() -> void:
	var index=0
	var moving=motion.phase in ["wander","chase","return","visit"] and not motion.held
	if moving and not motion.carried and motion.landing_left<=0 and baby_walk.size()==8:
		show_baby_walk()
		return
	if motion.carried or motion.landing_left>0: index=6
	elif motion.phase=="doze": index=7
	elif motion.phase=="eat": index=3
	elif motion.phase=="drink": index=4
	elif moving: index=1+int(motion.walk_phase*2)%2
	elif motion.phase in ["pet","cuddle","groom","signature"] or motion.joy_left>0: index=5 if int(motion.elapsed*2)%3!=0 else 0
	elif motion.phase=="react":
		index=5 if motion.reaction in ["pet","yum","greet","gift","full","askplay"] else 0
	var extra=-1
	if not motion.carried and motion.landing_left<=0 and not moving and baby_extra.size()==8:
		var t=motion.reaction_time if motion.phase=="react" else motion.elapsed
		if motion.phase=="eat":
			var bite_time=fposmod(t*.65,2.4)
			extra=1 if (bite_time>.55 and bite_time<.85) or (bite_time>1.12 and bite_time<1.48) else 0
		elif motion.phase=="drink": extra=2+int(t*1.5)%2
		elif Special.pose(motion,true)>=0: extra=4+Special.pose(motion,true)
	var texture: Texture2D=baby_extra[extra] if extra>=0 else baby_frames[index]
	var next_extra=extra
	var blend=0.0
	if extra>=0:
		if motion.phase in ["eat","drink"]:
			next_extra=(1-extra) if motion.phase=="eat" else (5-extra)
			blend=0.0 # Hold clean poses; dissolving two drawings duplicates eyes and paws.
		else:
			var sample=Special.sample(motion,true)
			next_extra=4+int(sample.y)
			blend=0.0
	var next_texture: Texture2D=baby_extra[next_extra] if next_extra>=0 else texture
	var neutral: Rect2i=Metrics.used_rect(baby_extra[5]) if extra>=0 else Baby.bounds[motion.species]
	var factor=Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]/maxf(1,neutral.size.y)
	var direction=motion.facing
	# This atlas drew the opposite walking step mirrored for its last four species.
	if extra<0 and motion.species>=12 and index==2: direction=-direction
	sprite.texture=texture
	sprite.rotation=0
	sprite.scale=Vector2(factor*direction,factor)
	sprite.position=FEET-Vector2(texture.get_width()*.5,neutral.end.y)*sprite.scale
	if index==7:
		sprite.scale.y*=1+sin(motion.elapsed*TAU/3.8)*.012
		sprite.position.y=FEET.y-neutral.end.y*sprite.scale.y
	sprite.material.set_shader_parameter("next_frame",next_texture)
	sprite.material.set_shader_parameter("frame_mix",blend)
	var water=motion.phase=="drink" and motion.visit_id=="water"
	var serving=motion.phase in ["eat","drink"] and motion.food_id>=0 and motion.visit_id in ["bowl","meal","snack","hand_feed"]
	sprite.material.set_shader_parameter("has_meal",water or serving)
	if water or serving:
		var meal=Decor.icon("water") if water else Food.icon_for(motion.species,motion.food_id)
		var placement=BabyMeal.placement(motion.species,maxi(extra,0),texture,meal)
		if next_extra>=0:
			var next_placement=BabyMeal.placement(motion.species,next_extra,next_texture,meal)
			placement.rect=placement.rect.lerp(next_placement.rect,blend)
			placement.grip=placement.grip.lerp(next_placement.grip,blend)
		var rect: Vector4=placement.rect
		sprite.material.set_shader_parameter("baby_meal",true)
		sprite.material.set_shader_parameter("baby_grip",placement.grip)
		sprite.material.set_shader_parameter("modern_meal",true)
		sprite.material.set_shader_parameter("menu_texture",meal)
		sprite.material.set_shader_parameter("old_rect",rect)
		sprite.material.set_shader_parameter("prop_rect",rect)
		sprite.material.set_shader_parameter("food_bite",motion.phase=="eat")

func show_baby_walk() -> void:
	var phase=motion.walk_phase*8.0
	var index=floori(phase)%8
	var texture: Texture2D=baby_walk[index]
	var neutral=Metrics.used_rect(baby_walk[0])
	var factor=Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]/maxf(1,neutral.size.y)
	sprite.texture=texture
	sprite.rotation=0
	sprite.scale=Vector2(factor*motion.facing,factor)
	sprite.position=FEET-Vector2(texture.get_width()*.5,neutral.end.y)*sprite.scale
	sprite.material.set_shader_parameter("has_meal",false)
	sprite.material.set_shader_parameter("next_frame",baby_walk[(index+1)%8])
	# Long dissolves duplicate eyes and paws instead of adding a real pose.
	# Hold the authored drawing, with only a brief transition at the boundary.
	sprite.material.set_shader_parameter("frame_mix",0.0)

func apply_growth() -> void:
	if ball_only or sprite==null: return
	if motion.species==4: RaccoonPalette.apply(sprite.material,sprite.texture)
	stabilize_pet_pose()
	apply_weight_motion()
	# Keep the feet fixed so all original actions and mouse outlines agree.
	sprite.position=FEET+(sprite.position-FEET)*motion.growth_scale
	sprite.scale*=motion.growth_scale

func apply_weight_motion() -> void:
	var walking=motion.phase in ["wander","chase","return","visit"] and not motion.held and not motion.carried
	var profile=preload("res://scripts/gait_profile.gd")
	var target_weight=clampf(motion.travel_speed/maxf(1.0,nominal_speed()),0.0,1.0) if walking else 0.0
	if presentation_delta>0:
		gait_weight=lerpf(gait_weight,target_weight,1.0-exp(-14.0*presentation_delta))
	else:
		gait_weight=target_weight
	var pose=profile.pose(motion.species,motion.walk_phase,gait_weight) if walking else Vector3.ZERO
	if was_walking and not walking: settle_offset=previous_gait
	if not walking:
		settle_offset*=exp(-18.0*presentation_delta) if presentation_delta>0 else 0.0
		pose=settle_offset
	if motion.carried or motion.held or motion.phase in ["prop_use","eat","drink","doze"]:
		pose=Vector3.ZERO
		settle_offset=Vector3.ZERO
	if motion.phase=="idle" and motion.growth_stage==0:
		pose.z+=sin(motion.elapsed*TAU/4.2)*.004
	if motion.phase=="rub":
		pose.y=sin(motion.social_contact*TAU)*.085
		pose.x=-absf(sin(motion.social_contact*PI))*2
		pose.z=-.025*absf(sin(motion.social_contact*TAU))
	if motion.phase=="eat" and not motion.carried:
		# Reach, take three small bites, swallow, then settle.
		var cycle=fposmod(motion.elapsed,3.2)/3.2
		var reach=smoothstep(0.0,.16,cycle)*(1.0-smoothstep(.72,.90,cycle))
		var chew=sin(clampf(inverse_lerp(.16,.68,cycle),0,1)*TAU*3.0) if cycle>=.16 and cycle<.68 else 0.0
		var swallow=sin(clampf(inverse_lerp(.68,.84,cycle),0,1)*PI) if cycle>=.68 and cycle<.84 else 0.0
		pose.x=reach*1.6-absf(chew)*1.0-swallow*.7
		pose.y=motion.facing*(reach*.022+chew*.008)
		pose.z=-absf(chew)*.008+swallow*.006
	elif motion.phase=="drink" and not motion.carried:
		# Lower toward the pond, lap three times, swallow, and rise.
		var cycle=fposmod(motion.elapsed,3.2)/3.2
		var lower=smoothstep(0.0,.20,cycle)*(1.0-smoothstep(.78,.96,cycle))
		var lap=sin(clampf(inverse_lerp(.20,.72,cycle),0,1)*TAU*3.0) if cycle>=.20 and cycle<.72 else 0.0
		var swallow=sin(clampf(inverse_lerp(.72,.86,cycle),0,1)*PI) if cycle>=.72 and cycle<.86 else 0.0
		pose.x=lower*8.0+absf(lap)*2.0-swallow*1.2
		pose.y=motion.facing*(lower*.14+lap*.009)
		pose.z=-lower*.07+swallow*.012
	# Transform around the feet, not the sprite's top-left corner.
	var pivot=Transform2D(pose.y,Vector2.ONE,0.0,Vector2.ZERO)
	sprite.position=FEET+pivot*(sprite.position-FEET)+Vector2(0,pose.x)
	sprite.rotation+=pose.y
	previous_gait=pose
	was_walking=walking

func nominal_speed() -> float:
	return motion.SPEEDS[motion.species]*lerpf(.72,1.0,clampf(inverse_lerp(.62,1.0,motion.growth_scale),0,1))

func stabilize_pet_pose() -> void:
	if not (motion.phase=="pet" or (motion.phase=="react" and motion.reaction=="pet")): return
	# Petting is an upright expression, not the crouch/jump special sequence.
	# Match visible artwork rather than each sheet's transparent canvas padding.
	var used=Metrics.used_rect(sprite.texture)
	if not used.has_area(): return
	var height=Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]
	var factor=height/float(used.size.y)
	sprite.rotation=0
	sprite.scale=Vector2(factor*motion.facing,factor)
	sprite.position=FEET-Vector2(used.position.x+used.size.x*.5,used.end.y)*sprite.scale
	sprite.material.set_shader_parameter("next_frame",sprite.texture)
	sprite.material.set_shader_parameter("frame_mix",0.0)

func show_crisp_idle() -> void:
	# Keep idle and petting in the same clean cartoon artwork family.
	# The old restaurant walking thumbnail has soft, baked-in raster edges.
	var texture: Texture2D=reaction_frames[0] if reaction_frames.size()==64 else adult_special[1]
	var used=Metrics.used_rect(texture)
	var factor=Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]/maxf(1,used.size.y)
	var breath=sin(motion.elapsed*TAU/4.8)*.003
	sprite.texture=texture
	sprite.rotation=0
	sprite.scale=Vector2(factor*motion.facing*(1+breath),factor*(1-breath))
	sprite.position=FEET-Vector2(used.position.x+used.size.x*.5,used.end.y)*sprite.scale
	sprite.material.set_shader_parameter("next_frame",texture)
	sprite.material.set_shader_parameter("frame_mix",0.0)
	sprite.material.set_shader_parameter("has_meal",false)

func show_consistent_social_pose() -> void:
	if reaction_frames.size()!=64:
		show_adult_special(Special.pose(motion))
		return
	# Idle, attention and social gestures share the same palette and body model.
	# The four-pose special sheet depicts a different, much darker character.
	var inspecting=motion.phase in ["look","sniff","inspect"] or (motion.phase=="react" and motion.reaction in ["inspect","anticipate"])
	var greeting=motion.phase=="react" and motion.reaction=="greet"
	var row=2 if inspecting else (0 if greeting else 4)
	var t=motion.reaction_time if motion.phase=="react" else motion.elapsed
	var plan=[0,1,2,3,2,1,0,0] if inspecting else [0,1,2,3,3,2,1,0]
	var frame=int(t*2.2)%plan.size()
	var texture: Texture2D=reaction_frames[row*8+plan[frame]]
	var neutral=Metrics.used_rect(reaction_frames[0])
	var factor=Art.DISPLAY_HEIGHT*Art.HEIGHTS[motion.species]/maxf(1,neutral.size.y)
	sprite.texture=texture
	sprite.rotation=0
	sprite.scale=Vector2(factor*motion.facing,factor)
	sprite.position=FEET-Vector2(texture.get_width()*.5,neutral.end.y)*sprite.scale
	sprite.material.set_shader_parameter("has_meal",false)
	sprite.material.set_shader_parameter("next_frame",texture)
	sprite.material.set_shader_parameter("frame_mix",0.0)

func show_lifestyle_prop() -> void:
	if not is_instance_valid(lifestyle_prop): return
	lifestyle_prop.hide()
	scene_front.hide()
	if motion.phase=="home_use" and motion.visit_id=="home_bathtub":
		scene_front.texture=preload("res://scripts/v2_furniture_art.gd").bath_front()
		scene_front.position=motion.soft_scene_origin-motion.feet+FEET
		scene_front.scale=motion.soft_scene_scale
		scene_front.flip_h=motion.soft_scene_mirrored
		preload("res://scripts/furniture_catalog.gd").apply_style(scene_front.material,motion.soft_scene_style,"bathtub")
		scene_front.modulate.a=smoothstep(0,.65,motion.elapsed)*smoothstep(0,.65,motion.action_left)
		scene_front.show()
	if not motion.soft_toy_prop.is_empty() and generated_sample.get("life_animation",false):
		lifestyle_prop.texture=preload("res://scripts/furniture_catalog.gd").texture(motion.soft_toy_prop)
		lifestyle_prop.position=generated_sample.hand+Vector2(sin(motion.elapsed*2)*1.5,0)
		lifestyle_prop.scale=Vector2.ONE*minf(42.0/lifestyle_prop.texture.get_width(),40.0/lifestyle_prop.texture.get_height())
		lifestyle_prop.rotation=sin(motion.elapsed*2)*.06
		lifestyle_prop.modulate.a=smoothstep(.3,.8,motion.elapsed)*smoothstep(.3,.8,motion.action_left)
		if motion.visit_id=="basket":
			var source=sprite.to_local(to_global(motion.soft_scene_origin-motion.feet+FEET))
			var reach=smoothstep(.9,2.2,motion.elapsed)*smoothstep(.2,1.4,motion.action_left)
			lifestyle_prop.position=source.lerp(generated_sample.hand,reach)
			lifestyle_prop.modulate.a=smoothstep(.7,.95,motion.elapsed)*smoothstep(.15,.3,motion.action_left)
		lifestyle_prop.show()
		return
	if motion.phase!="home_use": return
	var kind: String=preload("res://scripts/home_animation.gd").KINDS.get(motion.visit_id,"")
	# The full-body drinking cels already contain the held mug.
	if kind=="tea" and generated_sample.get("embedded_food",false): return
	var id: String={"read":"reading-book","tea":"water-cup","music":"music"}.get(kind,"")
	if id.is_empty(): return
	var texture: Texture2D=preload("res://scripts/v2_shared_art.gd").texture(id)
	if texture==null: return
	lifestyle_prop.texture=texture
	lifestyle_prop.modulate=Color.WHITE
	lifestyle_prop.rotation=0.0
	lifestyle_prop.scale=Vector2.ONE*(46.0/texture.get_width())
	lifestyle_prop.position=generated_sample.hand
	if kind=="tea":
		var phase: float=clampf(motion.elapsed/7.2,0,1)
		var lift: float=smoothstep(.06,.28,phase)*(1.0-smoothstep(.72,.92,phase))
		lifestyle_prop.position=generated_sample.hand.lerp(generated_sample.mouth+Vector2(0,12),lift)
	elif kind=="music":
		lifestyle_prop.scale=Vector2.ONE*(26.0/texture.get_width())
		lifestyle_prop.position=generated_sample.mouth+Vector2(40,-26+sin(motion.elapsed*2.0)*3)
	lifestyle_prop.show()
