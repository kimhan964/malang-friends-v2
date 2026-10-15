extends SceneTree
const Book=preload("res://scripts/action_codex.gd")
const Data=preload("res://scripts/action_codex_data.gd")
var checks=[]
var failed=false
var book
class PreviewPet extends Node:
	var species=0
	var state=preload("res://scripts/pet_state.gd").new()
func _initialize() -> void: run.call_deferred()
func check(value: bool,message: String) -> void:
	checks.append({"check":message,"passed":value})
	if not value: failed=true;push_error(message)
func run() -> void:
	book=Book.new();root.add_child(book)
	var out=OS.get_executable_path().get_base_dir().path_join("검수/행동도감")
	DirAccess.make_dir_recursive_absolute(out)
	var board=Image.create(4*410,4*180,false,Image.FORMAT_RGBA8);board.fill(Color("faf8f3"))
	for species in range(16):
		book.open(species)
		check(book.selector.item_count==16,"species selector "+str(species))
		check(book.shown_actions>=14,"available actions "+str(species))
		check(book.rows.get_child_count()==Data.ROWS.size(),"table categories "+str(species))
		for row in Data.ROWS:
			for item in row[2]:
				var spec=Data.descriptor(species,item[0],item[1])
				if spec.is_empty(): continue
				book.select_action(spec,item[2],row[1])
				check(book.atlas.atlas.get_width()>=spec.columns*256,"atlas width %d/%s"%[species,spec.key])
				check(book.atlas.atlas.get_height()>=ceili(float(spec.count)/spec.columns)*256,"atlas height %d/%s"%[species,spec.key])
				book.clock=spec.seconds*.51;book.update_frame()
				check(book.atlas.region.position!=Vector2.ZERO,"animation advances %d/%s"%[species,spec.key])
				book.clock=spec.seconds;book.update_frame()
				check(book.atlas.region.position==Vector2.ZERO,"loop wraps %d/%s"%[species,spec.key])
		book.buttons[1].pressed.emit()
		await process_frame
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var image=book.panel.get_texture().get_image()
			if species in [0,3,8,15]: image.save_png(out.path_join(Data.Catalog.IDS[species]+".png"))
			var card=image.get_region(Rect2i(0,0,mini(820,image.get_width()),mini(360,image.get_height())))
			card.resize(410,180,Image.INTERPOLATE_LANCZOS)
			board.blit_rect(card,Rect2i(0,0,410,180),Vector2i(species%4*410,int(species/4)*180))
	book.open(8,[8,9]);check(book.selector.item_count==2,"owned selector only")
	check(book.species==8,"opening preserves animal")
	book.play.pressed.emit();var before=book.clock;book._process(.1);check(book.clock==before,"pause")
	book.play.pressed.emit();book._process(.1);check(book.clock>before,"resume")
	var pet=PreviewPet.new();root.add_child(pet)
	var menu=preload("res://scripts/friend_menu.gd").new();pet.add_child(menu)
	var friends=PopupMenu.new();friends.name="Friends";friends.add_item("토끼",0);friends.add_item("수달",1);menu.add_child(friends)
	menu.rebuild()
	var entry: Button
	for child in menu.body.get_children():
		if child is Button and child.text.begins_with("행동 도감"): entry=child
	check(is_instance_valid(entry),"codex is in Together menu")
	if is_instance_valid(entry):
		entry.pressed.emit()
		await process_frame
		await process_frame
		check(menu.action_codex.panel.visible,"menu opens codex")
		check(menu.action_codex.selector.item_count==2,"menu passes owned animals")
		check(pet.species==0,"preview does not change live animal")
		menu.action_codex.panel.hide()
	pet.queue_free()
	if DisplayServer.get_name()!="headless":
		book.open(0);book.scroll.scroll_vertical=10000
		await process_frame
		await RenderingServer.frame_post_draw
		book.panel.get_texture().get_image().save_png(out.path_join("lower-rows.png"))
		book.panel.size=Vector2i(600,500)
		await process_frame
		await RenderingServer.frame_post_draw
		book.panel.get_texture().get_image().save_png(out.path_join("compact.png"))
		board.save_png(out.path_join("all-species.png"))
	FileAccess.open(out.path_join("validation.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"checks":checks},"\t"))
	print("ACTION_CODEX_CHECKS ",checks.size()," PASSED ",not failed)
	quit(1 if failed else 0)
