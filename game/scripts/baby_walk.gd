extends RefCounted
const Keyed=preload("res://scripts/keyed_art.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
static var cache: Dictionary={}
static func frames(species: int) -> Array:
	if not cache.has(species):
		var path="res://assets/walk/baby-%s.png"%Catalog.IDS[species]
		cache[species]=Keyed.AnimationRegions.frames(path,Keyed.pixels(path))
	return cache[species]
