extends RefCounted
const Keyed=preload("res://scripts/keyed_art.gd")
static var groups: Dictionary={}
static func frames(species: int, sleeping: bool) -> Array:
	var group=int((species-8)/4)
	if not groups.has(group):
		# Use the actual gutters: equal quarters include the previous animal's
		# feet above the next animal and cut some tails at column boundaries.
		var rows=[0,235,450,653,887] if group==0 else [0,220,445,662,887]
		var columns=[0,216,438,650,878,1098,1330,1555,1774]
		groups[group]=Keyed.cells("res://assets/habits/new-friends-%d.png"%group,8,4,false,rows,columns)
	var sheet: Array=groups[group]
	var start=((species-8)%4)*8+(4 if sleeping else 0)
	return sheet.slice(start,start+4)
