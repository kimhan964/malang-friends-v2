extends RefCounted

static func visible_ids(eligible: Array, focus: String="", secondary: String="") -> Array:
	var result: Array=[]
	for id in ["bowl","water"]:
		if id in eligible: result.append(id)
	for group in [["cushion","shelter","lamp"],["acorn","plant","basket"]]:
		if focus in group and focus in eligible:
			result.append(focus)
		elif secondary in group and secondary in eligible:
			result.append(secondary)
		else:
			for id in group:
				if id in eligible:
					result.append(id)
					break
	return result

static func capped_scale(kind: String, factor: float) -> float:
	var limit={"shelter":1.40,"cushion":1.18,"plant":.92,"lamp":.92,"basket":.86,"acorn":.90,"water":1.05,"bowl":.82}.get(kind,1.0)
	return clampf(factor,.45,limit)
