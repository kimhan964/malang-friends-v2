extends RefCounted

const Keyed=preload("res://scripts/keyed_art.gd")
const ITEMS={"bowl":16,"water":17,"basket":18,"plant":19,"lamp":20,"ball":21}
static var icons: Array=[]
static var new_icons: Array=[]
static var species_icons: Dictionary={}
static var pond_icon: Texture2D
static var acorn_icon: Texture2D
static var cozy_icons: Dictionary={}

static func icon(kind: String, species: int=0) -> Texture2D:
	# No species-specific pixel furniture remains on any v2 visual path.
	if kind in ["cushion","shelter","lamp"]: return preload("res://scripts/furniture_catalog.gd").texture({"cushion":"daybed","shelter":"sofa","lamp":"lamp"}[kind])
	if kind in ["bowl","water"]: return preload("res://scripts/v2_shared_art.gd").texture("water-cup")
	if kind=="plant": return preload("res://scripts/v2_shared_art.gd").texture("carrot-plush")
	if kind=="acorn": return preload("res://scripts/v2_shared_art.gd").texture("acorn")
	if kind=="basket": return preload("res://scripts/v2_shared_art.gd").texture("toy-basket")
	if kind=="plant" and species==0: return preload("res://scripts/v2_shared_art.gd").texture("carrot-plush")
	if kind=="basket" or (kind=="plant" and species==0):
		var key="toy-basket" if kind=="basket" else "carrot-plush"
		if not cozy_icons.has(key):
			var image=Image.new()
			if preload("res://scripts/asset_images.gd").decode_into(image,"res://assets/decor-cozy-v2/"+key+".png")!=OK: return null
			cozy_icons[key]=ImageTexture.create_from_image(image.get_region(image.get_used_rect()))
		return cozy_icons[key]
	if kind=="acorn":
		if acorn_icon==null:
			var image=Image.new()
			if preload("res://scripts/asset_images.gd").decode_into(image,"res://assets/decor-cozy-v2/acorn-wobble-v2.png")==OK:
				acorn_icon=ImageTexture.create_from_image(image.get_region(image.get_used_rect()))
		return acorn_icon
	if kind=="water":
		if pond_icon==null:
			var image=Image.new()
			if preload("res://scripts/asset_images.gd").decode_into(image,"res://assets/decor/drinking-pond-v1.png")==OK:
				var used=image.get_used_rect()
				if used.has_area(): image=image.get_region(used)
				pond_icon=ImageTexture.create_from_image(image)
		return pond_icon
	if kind in ["plant","lamp"]:
		if not species_icons.has(kind):
			var path="res://assets/decor/species-%s.png"%("toys" if kind=="plant" else "comfort")
			species_icons[kind]=[]
			for frame in Keyed.AnimationRegions.frames(path,Keyed.pixels(path)):
				var image=frame.get_image()
				species_icons[kind].append(ImageTexture.create_from_image(image.get_region(image.get_used_rect())))
		return species_icons[kind][clampi(species,0,15)]
	if species>=8 and kind in ["cushion","shelter"]:
		# The generated rows are not equal-height: the house row starts near 600
		# and ends before the next row's tent poles at 910. Equal quarters clipped
		# roofs and included those poles as floating fragments below the houses.
		if new_icons.is_empty(): new_icons=Keyed.cells("res://assets/decor/new-friends-homes.png",4,4,true,[0,305,600,895,1254],[0,317,620,938,1254])
		return new_icons[species-8+(8 if kind=="shelter" else 0)] if new_icons.size()==16 else null
	var index=int(ITEMS.get(kind,-1))
	if kind=="cushion": index=clampi(species,0,7)
	if kind=="shelter": index=8+clampi(species,0,7)
	if index<0: return null
	if icons.is_empty(): icons=Keyed.cells("res://assets/decor/character-style-v2.png",4,6,true,[0,289,533,794,1058,1287,1536])
	return icons[index] if icons.size()==24 else null
