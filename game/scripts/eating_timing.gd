extends RefCounted
const SECONDS=5.5
# Mouth positions reviewed against the complete fourth eating cel, baby/adult
# separately. The previous generic anchors put food on several animals' eyes.
const BABY_MOUTHS=[Vector2(161,142),Vector2(174,113),Vector2(173,125),Vector2(165,135),Vector2(172,129),Vector2(170,128),Vector2(158,120),Vector2(155,130),Vector2(163,130),Vector2(173,123),Vector2(160,132),Vector2(153,126),Vector2(170,139),Vector2(158,133),Vector2(151,148),Vector2(155,120)]
const ADULT_MOUTHS=[Vector2(160,135),Vector2(172,107),Vector2(166,132),Vector2(181,154),Vector2(172,147),Vector2(170,134),Vector2(156,121),Vector2(153,125),Vector2(166,138),Vector2(160,133),Vector2(147,129),Vector2(164,124),Vector2(165,139),Vector2(149,131),Vector2(150,137),Vector2(157,116)]
static func mouth_point(species: int,stage: String,current: Vector2,reference: Array) -> Vector2:
	return (BABY_MOUTHS if stage=="baby" else ADULT_MOUTHS)[species]+current-Vector2(reference[0],reference[1])
static func progress(elapsed: float) -> float:
	return clampf(elapsed/SECONDS,0.0,.999999)
static func food_pose(sample: Dictionary,texture: Texture2D,elapsed: float) -> Dictionary:
	var phase=progress(elapsed)
	var lift=smoothstep(.015,.20,phase)
	var eaten=smoothstep(.25,.66,phase)
	var width=lerpf(32.0,19.0,eaten)
	var height=minf(32.0,width*texture.get_height()/float(texture.get_width()))
	var mouth: Vector2=sample.mouth
	var hand: Vector2=sample.hand
	var from=hand-Vector2(width*.5,height*.7)
	# A small portion meets the mouth, rather than a whole meal floating at
	# the belly. The original whole-character cels still supply the hands.
	var to=mouth-Vector2(width*.5,height*.15)
	var origin=from.lerp(to,lift)
	var opacity=smoothstep(.015,.08,phase)*(1.0-smoothstep(.65,.79,phase))
	return {"rect":Vector4(origin.x/256,origin.y/256,width/256,height/256),
		"opacity":opacity,"grip":hand.lerp(mouth+Vector2(0,height*.55),lift)}
static func cup_pose(sample: Dictionary,texture: Texture2D,elapsed: float) -> Dictionary:
	var phase=progress(elapsed)
	var width=32.0
	var height=minf(32,width*texture.get_height()/texture.get_width())
	var lift=smoothstep(.015,.20,phase)*(1.0-smoothstep(.72,.88,phase))
	var from: Vector2=sample.hand-Vector2(width*.5,height*.7)
	var to: Vector2=sample.mouth-Vector2(width*.5,height*.13)
	var origin=from.lerp(to,lift)
	return {"rect":Vector4(origin.x/256,origin.y/256,width/256,height/256),"opacity":smoothstep(.015,.07,phase)*(1-smoothstep(.82,.93,phase))}
