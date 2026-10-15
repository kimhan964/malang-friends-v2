extends SceneTree
func _initialize() -> void:
	if not ProjectSettings.load_resource_pack("res://builds/DesktopFriends-Commerce-0.11/DesktopFriends.pck"):
		quit(1)
		return
	var config=ConfigFile.new()
	assert(config.load("res://project.godot")==OK)
	assert(config.get_value("commerce","enabled",false)==true)
	assert(config.get_value("commerce","site_url","")=="https://your-mbti.rlagksv.chatgpt.site")
	assert(config.get_value("application","run/main_scene","")!="")
	assert(FileAccess.file_exists("res://scripts/commerce_access.gd"))
	print("COMMERCE_PACKAGE_TEST_PASSED")
	quit()
