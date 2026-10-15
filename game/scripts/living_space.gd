extends RefCounted
const FLOOR="floor"
const DESKTOP="desktop"
static func clean(value) -> String:
	return DESKTOP if value==DESKTOP else FLOOR
static func bounds(screen: Rect2,mode: String) -> Rect2:
	var area=Rect2(screen.position+Vector2(128,190),(screen.size-Vector2(256,224)).max(Vector2.ONE))
	if mode==FLOOR:
		# A one-pixel lane keeps Rect2 containment and existing contact tests valid.
		area.position.y=area.end.y-1
		area.size.y=1
	return area
static func ground(screen: Rect2) -> float:
	return bounds(screen,FLOOR).get_center().y
