extends SceneTree
var piece
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.transparent_bg=true
	root.mouse_passthrough=true
	piece=preload("res://scripts/furniture_window.gd").new()
	root.add_child(piece)
	piece.position=Vector2i(500,860)
	piece.open_size_editor()
	piece.size_editor.close_requested.connect(func(): quit())
	await create_timer(45).timeout
	quit()
