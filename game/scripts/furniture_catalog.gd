extends RefCounted
const ITEMS={
	"sofa":{"name":"폭신 소파","size":Vector2(142,112)},
	"table":{"name":"둥근 식탁","size":Vector2(126,86)},
	"shelf":{"name":"도토리 책장","size":Vector2(108,126)},
	"lamp":{"name":"버섯 조명","size":Vector2(84,126)},
	"reading_chair":{"name":"독서 의자","size":Vector2(124,122)},
	"daybed":{"name":"낮잠 침대","size":Vector2(168,88)},
	"vanity":{"name":"둥근 거울 화장대","size":Vector2(118,125)},
	"record_player":{"name":"작은 음악 장식장","size":Vector2(114,94)},
	"play_rug":{"name":"구름 놀이 러그","size":Vector2(146,76)},
	"window_seat":{"name":"잎새 창가 벤치","size":Vector2(160,105)},
	"tv":{"name":"작은 TV장","size":Vector2(158,138)},
	"turntable":{"name":"LP 리스닝 테이블","size":Vector2(132,112)},
	"wall_clock":{"name":"곰 귀 원목 벽시계","size":Vector2(76,86),"wall":true},
	"wall_shelf":{"name":"둥근 벽 책장","size":Vector2(132,76),"wall":true},
	"plant_stand":{"name":"잎새 세라믹 화분대","size":Vector2(94,136)},
	"dresser":{"name":"발바닥 원목 서랍장","size":Vector2(124,108)},
	"fireplace":{"name":"포근한 전기 벽난로","size":Vector2(144,122)},
	"aquarium":{"name":"작은 물고기 수조장","size":Vector2(136,128)},
	"alarm_clock":{"name":"동물 귀 작은 자명종","size":Vector2(64,80)},
	"toy_ball":{"name":"실뜨개 공 놀이감","size":Vector2(48,46)},
	"toy_mouse":{"name":"생쥐 인형 놀이감","size":Vector2(60,40)},
	"toy_plush":{"name":"당근 애착 인형","size":Vector2(44,48)},
	"bathtub":{"name":"보송 거품 욕조","size":Vector2(164,104)}
}
const USE_LABELS={"sofa":"소파에서 쉬기","table":"앉아서 티타임","shelf":"책 읽기","lamp":"조명 곁에서 낮잠","reading_chair":"의자에서 독서","daybed":"누워 낮잠 자기","vanity":"거울 보고 단장","record_player":"음악 듣기","play_rug":"러그에서 놀이","window_seat":"벤치에서 쉬기"}
static var textures={}
const COLOR_NAMES=["원래 색","크림","세이지","더스티 로즈","안개 블루","월넛"]
const COLORS=[Color.WHITE,Color("e7d5b8"),Color("a5b397"),Color("c7a4a0"),Color("a7b8c1"),Color("ae927b")]
const FINISH_NAMES=["원본 질감","원목결","리넨결","매끈한 무광"]
const DESIGNS=["토끼","고양이","곰"]
static func normalize_style(value) -> Dictionary:
	var data: Dictionary=value if value is Dictionary else {}
	return {"color":clampi(int(data.get("color",0)),0,5),"finish":clampi(int(data.get("finish",0)),0,3),"design":clampi(int(data.get("design",0)),0,2)}
static func apply_style(target: ShaderMaterial,value: Dictionary,id: String="") -> void:
	var s=normalize_style(value)
	target.set_shader_parameter("color_choice",s.color)
	target.set_shader_parameter("finish_choice",s.finish)
	target.set_shader_parameter("accent_color",COLORS[s.color])
	target.set_shader_parameter("protect_nature",id in ["plant_stand","aquarium","window_seat"])
static func is_wall(id: String) -> bool: return ITEMS.get(id,{}).get("wall",false)
static func material() -> ShaderMaterial:
	var result=ShaderMaterial.new()
	result.shader=preload("res://scripts/furniture_palette.gdshader")
	return result
static func use_label(id: String) -> String:
	if id in ["toy_ball","toy_mouse"]: return "톡톡 건드리며 놀기"
	if id=="toy_plush": return "인형 안고 놀기"
	if id=="bathtub": return "거품 목욕하기"
	if id=="alarm_clock": return "자명종 살펴보기"
	return {"tv":"TV 보며 쉬기","turntable":"LP 감상하기","wall_clock":"시계 바라보기","wall_shelf":"선반 곁에서 독서","plant_stand":"잎새 구경하기","dresser":"거울 없이 털 단장","fireplace":"따뜻하게 쉬기","aquarium":"물고기 구경하기"}.get(id,USE_LABELS.get(id,"곁에서 쉬기"))
static func texture(id: String,design: int=0) -> Texture2D:
	if id in preload("res://scripts/v2_furniture_art.gd").IDS: return preload("res://scripts/v2_furniture_art.gd").frames(id)[0]
	if id=="toy_plush": return preload("res://scripts/v2_shared_art.gd").texture("carrot-plush")
	if not ITEMS.has(id) and id!="water-cup": return null
	var key=id+str(design) if id=="alarm_clock" else id
	if not textures.has(key):
		var path="res://assets/furniture-v1/"+id+".png"
		if preload("res://scripts/asset_images.gd").exists("res://assets/furniture-v2/"+id+".png"): path="res://assets/furniture-v2/"+id+".png"
		if preload("res://scripts/asset_images.gd").exists("res://assets/furniture-v3/"+id+".png"): path="res://assets/furniture-v3/"+id+".png"
		if preload("res://scripts/asset_images.gd").exists("res://assets/furniture-v4/"+id+".png"): path="res://assets/furniture-v4/"+id+".png"
		if id in ["toy_ball","toy_mouse"]: path="res://assets/furniture-v6/"+id+".png"
		if id=="alarm_clock": path="res://assets/furniture-v5/alarm-%s.png"%["rabbit","cat","bear"][clampi(design,0,2)]
		if FileAccess.file_exists("res://assets/v2-shared/"+id+".png"): path="res://assets/v2-shared/"+id+".png"
		if not preload("res://scripts/asset_images.gd").exists(path): return null
		var image=Image.new()
		if preload("res://scripts/asset_images.gd").decode_into(image,path)!=OK: return null
		var used=image.get_used_rect()
		# This generated cup includes almost invisible alpha specks far from
		# the ceramic. Use its reviewed atlas region; preserve the PNG original.
		if id=="water-cup" and not path.begins_with("res://assets/v2-shared/"): used=Rect2i(447,261,685,487)
		if not used.has_area(): return null
		textures[key]=ImageTexture.create_from_image(image.get_region(used))
	return textures[key]

static var ground_contacts={}
static func ground_contact(texture: Texture2D) -> float:
	var key=texture.get_instance_id()
	if ground_contacts.has(key): return ground_contacts[key]
	var image=texture.get_image()
	var bottom=image.get_height()-1
	for y in range(image.get_height()-1,-1,-1):
		var solid=0
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a>.67: solid+=1
		if solid>=maxi(3,int(image.get_width()*.003)):
			bottom=y+1
			break
	ground_contacts[key]=float(bottom)/image.get_height()
	return ground_contacts[key]
