extends SceneTree

const Main=preload("res://scripts/main.gd")
const Prop=preload("res://scripts/desktop_prop.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var app=Main.new()
	var prop=Prop.new()
	prop.prop_id="acorn"
	prop.kind="acorn"
	prop.size=Vector2i(112,90)
	prop.position=Vector2i(300,300)
	app.props["acorn"]=prop
	app.start_unlock_fall("acorn")
	assert(app.falling_gifts.has("acorn"))
	assert(prop.position.y<300 and prop.mouse_passthrough)
	app.advance_unlock_falls(.7)
	assert(prop.position.y<300)
	app.advance_unlock_falls(.55)
	assert(not app.falling_gifts.has("acorn"))
	assert(prop.position==Vector2i(300,300) and not prop.mouse_passthrough)
	assert(app.pending_gift_visits==["acorn"])
	prop.free()
	app.free()
	print("UNLOCK_FALL_TEST_PASSED")
	quit()
