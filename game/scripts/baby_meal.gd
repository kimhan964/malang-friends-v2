extends RefCounted
const Metrics=preload("res://scripts/texture_metrics.gd")
# Fingertip anchors in each pose's opaque bounds: eat up/down, drink up/down.
# These follow the authored extra atlases, including tails and long ears.
const HANDS=[
	[Vector2(.85,.62),Vector2(.70,.78),Vector2(.78,.60),Vector2(.70,.78)],
	[Vector2(.72,.51),Vector2(.61,.65),Vector2(.78,.49),Vector2(.64,.65)],
	[Vector2(.72,.56),Vector2(.61,.69),Vector2(.79,.55),Vector2(.65,.70)],
	[Vector2(.77,.62),Vector2(.72,.75),Vector2(.79,.60),Vector2(.73,.75)],
	[Vector2(.69,.57),Vector2(.64,.69),Vector2(.75,.48),Vector2(.67,.68)],
	[Vector2(.70,.57),Vector2(.65,.69),Vector2(.73,.54),Vector2(.68,.70)],
	[Vector2(.70,.48),Vector2(.74,.71),Vector2(.64,.49),Vector2(.72,.70)],
	[Vector2(.76,.56),Vector2(.73,.75),Vector2(.75,.55),Vector2(.73,.76)],
	[Vector2(.60,.61),Vector2(.52,.75),Vector2(.73,.59),Vector2(.63,.78)],
	[Vector2(.60,.59),Vector2(.47,.76),Vector2(.70,.55),Vector2(.63,.78)],
	[Vector2(.65,.61),Vector2(.55,.75),Vector2(.66,.61),Vector2(.63,.75)],
	[Vector2(.53,.57),Vector2(.48,.71),Vector2(.63,.54),Vector2(.56,.72)],
	[Vector2(.77,.58),Vector2(.65,.70),Vector2(.73,.57),Vector2(.74,.71)],
	[Vector2(.73,.58),Vector2(.65,.76),Vector2(.75,.58),Vector2(.73,.76)],
	[Vector2(.72,.60),Vector2(.65,.76),Vector2(.72,.60),Vector2(.71,.76)],
	[Vector2(.76,.49),Vector2(.88,.65),Vector2(.77,.48),Vector2(.91,.65)]
]
static func placement(species: int, pose: int, texture: Texture2D, meal: Texture2D) -> Dictionary:
	var body=Metrics.used_rect(texture)
	var extent=Vector2(texture.get_size())
	var hand=Vector2(body.position)+Vector2(body.size)*HANDS[species][clampi(pose,0,3)]
	var dimensions=meal.get_size()
	dimensions*=minf(body.size.x*.24/dimensions.x,body.size.y*.17/dimensions.y)
	# Rest the serving on the raised paw, or lower it with the resting paw.
	var origin=hand-Vector2(dimensions.x*.5,dimensions.y*.78)
	origin=origin.clamp(Vector2.ONE*2,extent-dimensions-Vector2.ONE*2)
	return {"rect":Vector4(origin.x/extent.x,origin.y/extent.y,dimensions.x/extent.x,dimensions.y/extent.y),
		"grip":Vector4(hand.x/extent.x,(hand.y+body.size.y*.02)/extent.y,body.size.x*.045/extent.x,body.size.y*.035/extent.y)}
