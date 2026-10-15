extends SceneTree
const Preview=preload("res://scripts/species_walk_preview.gd")
var preview
func _initialize() -> void: call_deferred("run")
func run() -> void:
	preview=Preview.new()
	root.add_child(preview)
	if not preview.is_node_ready(): await preview.ready
	var room=preview.app.furniture_room
	for id in room.Catalog.ITEMS:
		room.place(id)
	room.open()
	print("FURNITURE_CONTROLS_READY")
