extends SceneTree
func _initialize() -> void:
	var preview=OS.get_cmdline_user_args().has("--preview")
	var scene="res://scenes/species_walk_preview.tscn" if preview else "res://scenes/main.tscn"
	var user_dir="DesktopFriendsWalkPreview" if preview else "DesktopFriends"
	var ok=ProjectSettings.get_setting("application/run/main_scene")==scene and ProjectSettings.get_setting("application/config/custom_user_dir_name")==user_dir
	print("PACKAGE_CONFIG scene=",ProjectSettings.get_setting("application/run/main_scene")," user=",ProjectSettings.get_setting("application/config/custom_user_dir_name")," pass=",ok)
	print(FileAccess.get_file_as_string("res://project.godot").substr(0,520))
	quit(0 if ok else 1)
