extends RefCounted
## Existing complete-character expressions, with a 60-pose action timeline.
## No limb parts and no body stretching. Each species has its own tempo/weight.
const Emotions=preload("res://scripts/emotion_art.gd")
const Art=preload("res://scripts/generated_species_art.gd")
const Smooth=preload("res://scripts/smooth_species_art.gd")
const Rabbit=preload("res://scripts/rabbit_pilot_art.gd")
const Metrics=preload("res://scripts/texture_metrics.gd")
const Presentation=preload("res://scripts/character_presentation.gd")
const TEMPO=[1.0,1.05,.91,1.18,1.08,.97,1.24,1.19,1.02,.94,.90,1.28,.96,1.12,1.32,1.14]
const HOP=[9.0,4.5,7.0,2.5,4.0,6.0,3.0,2.0,4.0,7.5,5.0,2.5,6.5,5.5,1.5,3.5]
const TILT=[.06,.085,.07,.045,.055,.10,.05,.13,.11,.075,.06,.045,.09,.065,.10,.12]
const WORDS={"surprised":"깜짝이야","happy":"좋아","angry":"잠깐만","sleepy":"조금 졸려"}
const LABELS=["살짝 놀라기","기분 좋은 미소","잠깐 토라지기","나른하게 졸기"]
static var calibration={}

static func active(m) -> bool:
	return m.phase=="react" and m.reaction in Emotions.KINDS and not m.held

static func duration(species: int,kind: String) -> float:
	return float({"surprised":2.1,"happy":2.8,"angry":2.7,"sleepy":3.4}.get(kind,2.5))*TEMPO[species]

static func neutral_sample(m) -> Dictionary:
	var stage=Art.stage_name(m)
	if Smooth.enabled(m): return Smooth.sample(m,"idle")
	if m.rabbit_pilot and m.species==0: return Rabbit.sample(m,stage,"idle")
	return Art.sample_frame(m.species,stage,"idle",0)

static func sample(m) -> Dictionary:
	var neutral=neutral_sample(m)
	var stage=Art.stage_name(m)
	var tex=Emotions.texture(m.species,stage,m.reaction)
	if tex==null: return neutral
	var key="%d/%s/%s/%s"%[m.species,stage,m.reaction,str(neutral.height)]
	if not calibration.has(key):
		var used=Metrics.used_rect(tex)
		# The shared character-size pass owns scale for all actions. This module
		# supplies expression timing and ground registration only.
		calibration[key]={"height":float(neutral.height) if m.species==1 else 200.0,"anchor":Vector2(128,232) if m.species==1 else Vector2(128,used.end.y)}
	var spec=calibration[key]
	var phase=clampf(m.reaction_time/maxf(.01,m.reaction_duration),0,1)
	if phase<.08 or phase>.94:
		neutral.expression_behavior=true
		return neutral
	return {"texture":tex,"action":"expression","stage":stage,"index":mini(59,int(phase*60)),
		"height":spec.height,"anchor":spec.anchor,"fixed_cels":true,"expression_behavior":true,
		"bank":"expression-"+m.reaction,"regenerated_expression":m.species==1,"mouth":Vector2(138,126),"hand":Vector2(154,171)}

static func pulse(phase: float,start: float,end: float) -> float:
	if phase<=start or phase>=end: return 0.0
	return pow(sin((phase-start)/(end-start)*PI),2.0)

static func pose(m) -> Dictionary:
	var progress=clampf(m.reaction_time/maxf(.01,m.reaction_duration),0,1)
	# Interpolate neighboring authored timeline samples, so high refresh rate
	# monitors do not turn a gentle gesture into a 20Hz staircase.
	var index=progress*59.0
	var a=context_pose(m,floorf(index)/59.0)
	var b=context_pose(m,minf(59,ceilf(index))/59.0)
	return {"offset":a.offset.lerp(b.offset,index-floorf(index))*m.growth_scale*Vector2(m.facing,1)*.65*m.reaction_strength,"angle":lerpf(a.angle,b.angle,index-floorf(index))*m.facing*.7*m.reaction_strength}

static func context_pose(m,p: float) -> Dictionary:
	var pose=key_pose(m.species,m.reaction,p)
	var soft=pulse(p,.08,.94)
	var nod=pulse(p,.15,.48)+pulse(p,.55,.86)*.55
	match m.reaction_context:
		"pet","hand_feed","hello","set_down":
			pose={"offset":Vector2(3*soft,-1.5*soft),"angle":TILT[m.species]*.7*soft}
		"meal","favorite_meal":
			pose={"offset":Vector2(0,-2*nod),"angle":TILT[m.species]*.7*nod}
		"water","tea","rest","wake":
			pose={"offset":Vector2(-2*soft,2*soft),"angle":-TILT[m.species]*.6*soft}
		"read","garden":
			pose={"offset":Vector2(2*soft,0),"angle":TILT[m.species]*soft}
		"groom":
			pose={"offset":Vector2(0,-3*soft),"angle":-TILT[m.species]*.4*soft}
		"music":
			var sway=sin(p*TAU*2)*soft
			pose={"offset":Vector2(2*sway,0),"angle":TILT[m.species]*.6*sway}
	return pose

static func key_pose(species: int,kind: String,p: float) -> Dictionary:
	var offset=Vector2.ZERO
	var angle=0.0
	var tilt=float(TILT[species])
	match kind:
		"surprised":
			var recoil=pulse(p,.08,.48)
			offset=Vector2(-5*recoil,-minf(5,HOP[species]*.6)*recoil)
			angle=-tilt*.8*recoil+tilt*.3*pulse(p,.48,.83)
		"happy":
			var bounce=pulse(p,.12,.42)+pulse(p,.48,.78)*.72
			offset.y=-HOP[species]*bounce
			angle=tilt*.45*(pulse(p,.12,.42)-pulse(p,.48,.78))
		"angry":
			var stomp=pulse(p,.13,.31)+pulse(p,.38,.56)
			offset.y=-minf(3,HOP[species]*.45)*stomp
			angle=tilt*.55*pulse(p,.12,.62)-tilt*.9*pulse(p,.64,.94)
		"sleepy":
			var nod=pulse(p,.1,.47)+pulse(p,.49,.93)*1.25
			angle=tilt*nod
			offset=Vector2(-2*nod,2*nod)
	return {"offset":offset,"angle":angle}
