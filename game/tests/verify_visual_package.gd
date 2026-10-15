extends SceneTree
const View=preload("res://scripts/desktop_pet_view.gd")
const Effects=preload("res://scripts/dizzy_effects.gd")
const Behavior=preload("res://scripts/expression_behavior.gd")
func _initialize() -> void:
	var failures=[]
	var names=["pet_visual_style.gd","dizzy_effects.gd","expression_behavior.gd","desktop_pet_view.gd","character_size.gd","texture_metrics.gd","gait_profile.gd","rabbit_hop_motion.gd","desktop_pet_motion.gd","desktop_pet.gd","main.gd","species_walk_preview.gd","desktop_prop.gd"]
	names.append_array(["furniture_catalog.gd","furniture_window.gd","furniture_room.gd","eating_timing.gd","pet_state.gd","animal_blend.gdshader","rabbit_pilot_art.gd","generated_species_art.gd"])
	for id in ["sofa","table","shelf","lamp","water-cup"]:
		var asset="assets/furniture-v1/"+id+".png"
		if FileAccess.get_file_as_bytes("res://"+asset)!=FileAccess.get_file_as_bytes("C:/Users/rlagk/Documents/바탕화면 친구/"+asset): failures.append("furniture asset mismatch "+id)
	names.append("home_animation.gd")
	names.append_array(["native_mouse.gd","living_space.gd","friend_menu.gd","context_reactions.gd","cozy_ui.gd"])
	names.append_array(["outfit_layer.gd","outfit_mask.gdshader","smooth_species_art.gd","dining_species_art.gd"])
	for file in ["windows_mouse_passthrough.gdextension","LICENSE","bin/mouse_passthrough.windows.template_debug.x86_64.dll","bin/mouse_passthrough.windows.template_release.x86_64.dll"]:
		var asset="addons/windows_mouse_passthrough/"+file
		if FileAccess.get_file_as_bytes("res://"+asset)!=FileAccess.get_file_as_bytes("C:/Users/rlagk/Documents/바탕화면 친구/"+asset): failures.append("native mouse dependency mismatch "+file)
	for id in ["reading_chair","daybed","vanity","record_player","play_rug","window_seat"]:
		var asset="assets/furniture-v2/"+id+".png"
		if FileAccess.get_file_as_bytes("res://"+asset)!=FileAccess.get_file_as_bytes("C:/Users/rlagk/Documents/바탕화면 친구/"+asset): failures.append("new furniture mismatch "+id)
	for id in preload("res://scripts/animal_catalog.gd").IDS:
		for file in ["baby.png","adult.png","manifest.json"]:
			var asset="assets/home-v2/"+id+"/"+file
			if not FileAccess.file_exists("res://"+asset) or FileAccess.get_file_as_bytes("res://"+asset)!=FileAccess.get_file_as_bytes("C:/Users/rlagk/Documents/바탕화면 친구/"+asset): failures.append("home animation mismatch "+asset)
		for file in ["baby-play.png","adult-play.png"]:
			var asset="assets/home-v2/"+id+"/"+file
			if FileAccess.file_exists("C:/Users/rlagk/Documents/바탕화면 친구/"+asset) and FileAccess.get_file_as_bytes("res://"+asset)!=FileAccess.get_file_as_bytes("C:/Users/rlagk/Documents/바탕화면 친구/"+asset): failures.append("home repair mismatch "+asset)
	for name in names:
		var packed=FileAccess.get_file_as_bytes("res://scripts/"+name)
		var source=FileAccess.get_file_as_bytes("C:/Users/rlagk/Documents/바탕화면 친구/scripts/"+name)
		if packed!=source: failures.append("outdated or incomplete "+name)
	for id in ["tv","turntable"]:
		var asset="assets/furniture-v3/"+id+".png"
		if not FileAccess.file_exists("res://"+asset) or FileAccess.get_file_as_bytes("res://"+asset)!=FileAccess.get_file_as_bytes("C:/Users/rlagk/Documents/바탕화면 친구/"+asset): failures.append("new decor mismatch "+id)
	if Effects.MAX_PARTICLES!=8: failures.append("old effect palette")
	if Behavior.WORDS.happy!="좋아": failures.append("old dialogue")
	print("VISUAL_PACKAGE_VERIFIED scripts=",names.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
