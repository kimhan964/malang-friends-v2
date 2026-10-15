extends RefCounted
# Coordinates follow the eight restaurant poses, in texture UV space.
const MOUTHS=[Vector2(.64,.45),Vector2(.63,.46),Vector2(.61,.45),Vector2(.63,.40),Vector2(.65,.45),Vector2(.60,.47),Vector2(.61,.49),Vector2(.61,.41)]
const SPEEDS=[2.8,2.6,2.2,3.5,2.7,3.1,3.6,2.9]
const EAT=[0,1,2,3,4,3,4,5,6,7,7]
const DRINK=[0,1,2,3,3,4,4,5,6,7,7]

static func sample(species: int, bank: int, elapsed: float) -> Vector3:
	var plan=DRINK if bank==1 else EAT
	var phase=fposmod(elapsed*.65/SPEEDS[species-8]*plan.size(),plan.size())
	var slot=floori(phase)
	# These independently drawn poses do not register pixel-for-pixel.
	# Hold each drawing cleanly instead of dissolving two faces/paws together.
	return Vector3(plan[slot],plan[slot],0.0)

static func hand_rect(species: int, bank: int, frame: int) -> Vector4:
	var lift=[0.0,.45,1.0,1.0,.95,.35,.15,0.0][clampi(frame,0,7)]
	var mouth=MOUTHS[species-8]
	var center=Vector2(mouth.x-.055,.72).lerp(mouth+Vector2(0,.07),lift)
	var width=.25 if bank==1 else .22
	return Vector4(center.x-width*.5,center.y-.075,width,.15)
