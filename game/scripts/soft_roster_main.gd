extends "res://scripts/main.gd"
const SkinState=preload("res://scripts/pet_state.gd")
class ValidationState extends SkinState:
	func load_game() -> void:
		selected=3
		guide_seen=true
		home_initialized=true
		starter_layout_version=1
		for species in range(16): growth[str(species)]=36
		if OS.get_cmdline_user_args().has("--validate-migration") or OS.get_cmdline_user_args().has("--validate-life") or OS.get_cmdline_user_args().has("--validate-scene") or OS.get_cmdline_user_args().has("--validate-daily"):
			starter_layout_version=1
			play_affection={"3":200}
	func save_game() -> void: pass
func _ready() -> void:
	var pack: String=OS.get_executable_path().get_base_dir().path_join("animal-packs/pet-hedgehog.pck")
	if not ProjectSettings.load_resource_pack(pack,false):
		push_error("Local hedgehog pack missing")
		get_tree().quit(1)
		return
	var migration: bool=OS.get_cmdline_user_args().has("--validate-migration")
	var interaction: bool=OS.get_cmdline_user_args().has("--validate-interaction")
	var life: bool=OS.get_cmdline_user_args().has("--validate-life")
	var scene: bool=OS.get_cmdline_user_args().has("--validate-scene")
	var run_hop: bool=OS.get_cmdline_user_args().has("--validate-run-hop")
	var daily: bool=OS.get_cmdline_user_args().has("--validate-daily")
	var discovery: bool=OS.get_cmdline_user_args().has("--validate-discovery")
	var validating: bool=discovery or run_hop or daily or scene or life or OS.get_cmdline_user_args().has("--validate-roster") or migration or interaction
	if validating: state=ValidationState.new()
	super._ready()
	if validating:
		if discovery:
			if OS.get_cmdline_user_args().has("--system-audit"):
				var system_checker=preload("res://scripts/system_audit_validation.gd").new()
				system_checker.app=self
				add_child(system_checker);system_checker.run.call_deferred()
				return
			for argument in OS.get_cmdline_user_args():
				if argument.begins_with("--review="):
					var review_checker=preload("res://scripts/review_validation.gd").new()
					review_checker.app=self;review_checker.item=int(argument.trim_prefix("--review="))
					add_child(review_checker);review_checker.run.call_deferred()
					return
			if OS.get_cmdline_user_args().has("--trip"):
				var trip_checker=preload("res://scripts/trip_validation.gd").new()
				trip_checker.app=self
				add_child(trip_checker)
				trip_checker.run.call_deferred()
				return
			if OS.get_cmdline_user_args().has("--basket-layer"):
				var layer_checker=preload("res://scripts/basket_layer_validation.gd").new()
				layer_checker.app=self
				add_child(layer_checker)
				layer_checker.run.call_deferred()
				return
			if OS.get_cmdline_user_args().has("--home-timing"):
				var timing_checker=preload("res://scripts/home_timing_validation.gd").new()
				timing_checker.app=self
				add_child(timing_checker)
				timing_checker.run.call_deferred()
				return
			var discovery_checker=preload("res://scripts/discovery_validation.gd").new()
			discovery_checker.app=self
			add_child(discovery_checker)
			discovery_checker.run.call_deferred()
			return
		var checker=preload("res://scripts/run_hop_validation.gd").new() if run_hop else (preload("res://scripts/daily_validation.gd").new() if daily else (preload("res://scripts/scene_validation.gd").new() if scene else (preload("res://scripts/life_validation.gd").new() if life else (preload("res://scripts/interaction_validation.gd").new() if interaction else (preload("res://scripts/migration_validation.gd").new() if migration else preload("res://scripts/roster_validation.gd").new())))))
		checker.app=self
		add_child(checker)
		checker.run.call_deferred()
	else:
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--species="):
				var selected_id: int=Catalog.IDS.find(argument.trim_prefix("--species="))
				if selected_id>=0: choose_friend.call_deferred(selected_id)
