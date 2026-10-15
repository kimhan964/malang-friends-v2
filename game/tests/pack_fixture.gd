extends RefCounted
static func mount() -> bool:
	var directory=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--animal-pack-dir="): directory=arg.trim_prefix("--animal-pack-dir=")
	if directory.is_empty(): return true
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animal-packs.json"))
	for id in manifest.animals:
		var spec=manifest.animals[id]
		var path=directory.path_join(str(spec.file))
		if FileAccess.get_sha256(path)!=str(spec.sha256) or not ProjectSettings.load_resource_pack(path,false):
			push_error("Invalid test animal pack: "+id)
			return false
	return true
