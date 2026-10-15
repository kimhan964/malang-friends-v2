extends RefCounted
const Keyed=preload("res://scripts/keyed_art.gd")
const NewFriends=preload("res://scripts/new_friend_art.gd")
static var sheets: Dictionary={}
static func frames(species: int) -> Array:
	if species>=8: return NewFriends.frames(species,false)
	var group=int(species/4)
	if not sheets.has(group):
		var rows=[0,320,620,938,1254] if group==0 else [0,302,620,933,1254]
		sheets[group]=Keyed.cells("res://assets/habits/carry-%d.png"%group,4,4,false,rows)
	var sheet: Array=sheets[group]
	return sheet.slice((species%4)*4,(species%4)*4+4)
