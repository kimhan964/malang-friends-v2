extends SceneTree
const Access=preload("res://scripts/commerce_access.gd")
func _initialize() -> void:
	var access=Access.new()
	root.add_child(access)
	assert(not access.permits(0))
	assert(not access._accept_entitlements({"animalIds":["rabbit"]}))
	assert(not access._accept_entitlements({"animalIds":["rabbit"],"validForSeconds":0}))
	assert(access._accept_entitlements({"animalIds":["rabbit","unknown","rabbit"],"validForSeconds":60}))
	assert(access.allowed.size()==1)
	assert(access.permits(0))
	assert(not access.permits(1))
	assert(not access.permits(-1))
	access.verified_until=0
	assert(not access.permits(0))
	print("COMMERCE_ACCESS_TESTS_PASSED")
	access.free()
	quit()
