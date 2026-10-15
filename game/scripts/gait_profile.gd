extends RefCounted
# Keep the authored distance per stride; retime both travel and the drawn feet.
const TRAVEL_RATE=1.5
const STRIDE_PERIOD=[1.05,1.20,1.00,1.28,1.18,1.12,1.42,1.25,1.10,1.04,1.02,1.45,1.15,1.18,1.42,1.32]
const PERIOD=[1.80,2.20,2.00,2.30,2.20,2.05,2.40,2.30,2.10,2.05,2.00,2.40,2.10,2.20,2.45,2.25]
const MAX_WALK_MULTIPLIER=1.0
static func playback_cycle(species: int, authored_seconds: float) -> float:
	return maxf(authored_seconds,PERIOD[species])/TRAVEL_RATE
const LIFT=[1.5,.65,1.1,.35,.65,.85,.45,.55,.7,.9,.45,.4,.75,.7,.35,.5]
const SWAY=[.008,.012,.008,.012,.015,.008,.018,.025,.006,.012,.012,.022,.012,.012,.018,.035]
static func pose(species: int, phase: float, strength: float) -> Vector3:
	var step=phase*TAU
	# Compress during weight transfer; rise between foot contacts.
	return Vector3(-LIFT[species]*(1.0-cos(step*2.0))*.5,
		SWAY[species]*sin(step),0.0)*strength
