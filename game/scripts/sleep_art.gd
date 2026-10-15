extends RefCounted
const Keyed=preload("res://scripts/keyed_art.gd")
const NewFriends=preload("res://scripts/new_friend_art.gd")
static var sheets: Dictionary={}
static func frames(species: int) -> Array:
	if species>=8: return NewFriends.frames(species,true)
	var group=int(species/4)
	if not sheets.has(group): sheets[group]=Keyed.cells("res://assets/habits/sleep-%d.png"%group,4,4,false)
	var sheet: Array=sheets[group]
	return sheet.slice((species%4)*4,(species%4)*4+4)
