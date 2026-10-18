extends RefCounted
const Catalog=preload("res://scripts/animal_catalog.gd")
signal affection_changed(species: int, gifts: Array)
signal growth_changed(species: int, stage: int)
signal food_unlocked(species: int, foods: Array)

func feeding_count(species: int) -> int:
	return int(activity_counts.get(str(species),{}).get("hand_feed",0))

func food_available(species: int, food: int) -> bool:
	return species>=0 and species<Catalog.IDS.size() and food>=0 and food<32

func food_hint(_species: int, _food: int) -> String:
	return "식탁에 차려 함께 먹어요"

func food_progress(_species: int) -> String:
	return "모든 메뉴를 처음부터 이용해요 · 음식과 물은 식탁에서"
const GROWTH_NAMES=["새끼","중간","성체"]
const GROWTH_SCALES=[.93,.98,1.0]
const GROWTH_LIMITS=[0,12,36]
const CARE_ACTIONS=["pet","ball","hand_feed","snack","cuddle","doze","relax","playful","personality","bowl","water","plant","lamp","acorn","home_rest","home_play","home_music","home_read","home_groom","home_tea"]
var growth: Dictionary={}
var guide_seen=false
var activity_counts: Dictionary={}
func goal_text(species: int) -> String:
	return next_gift(species)

func growth_stage(species: int) -> int:
	var points=int(growth.get(str(species),0))
	return 2 if points>=36 else (1 if points>=12 else 0)

func growth_scale(species: int) -> float:
	var points=float(growth.get(str(species),0))
	# Newborn pets start about 1.5x larger (.62 -> .93). Keep the
	# boundary continuous so growing into the next stage never shrinks them.
	if points<12: return lerpf(.93,.98,points/12.0)
	if points<36: return lerpf(.98,1.0,(points-12)/24.0)
	return 1.0

func growth_text(species: int) -> String:
	var stage=growth_stage(species)
	var points=int(growth.get(str(species),0))
	var text="성장 단계: %s · 성장 경험치 %d\n새끼 → 중간 → 성체\n"%[GROWTH_NAMES[stage],points]
	text+=("다음 단계까지 %d 더 돌봐주세요."%(GROWTH_LIMITS[stage+1]-points)) if stage<2 else "함께 돌보며 어른으로 자랐어요!"
	return text+"\n먹여주기·공놀이·간식 찾기·토닥이기 +2\n쓰다듬기·잠자리·휴식·성격 놀이·식사·물 마시기 +1\n가구 해금과 성장은 별개예요. 자리를 비워도 퇴행하지 않아요."

func add_growth(species: int, amount: int) -> void:
	if species<0 or species>=Catalog.IDS.size() or amount<=0: return
	var before=growth_stage(species)
	growth[str(species)]=clampi(int(growth.get(str(species),0))+amount,0,9999)
	if growth_stage(species)!=before: growth_changed.emit(species,growth_stage(species))
const Furniture=preload("res://scripts/furniture_catalog.gd")
# One shared home progression; basic care and communication are never locked.
const UNLOCKS={"home_table":0,"home_sofa":0,"home_play_rug":0,"home_shelf":6,"home_lamp":12,"home_reading_chair":20,"home_daybed":30,"home_vanity":42,"home_record_player":56,"home_window_seat":72,"home_tv":90,"home_turntable":110,"home_wall_clock":8,"home_wall_shelf":16,"home_plant_stand":24,"home_dresser":38,"home_fireplace":64,"home_aquarium":84,"home_alarm_clock":18,"home_toy_ball":4,"home_toy_mouse":10,"home_toy_plush":0,"home_bathtub":0}
const BASIC_ACTIONS=["acorn","bowl","water","playful","follow","basket","snack","rub","cushion","cuddle","plant","personality","lamp","shelter"]
const RETIRED_PROPS=["bowl","water","cushion","shelter","lamp","plant"]
var home_owned: Dictionary={}
var home_initialized=false
var starter_layout_version=0
var scale_defaults_version=1
func migrate_scale_defaults(version: int) -> void:
	if version<1 and furniture.has("plant_stand") and furniture.plant_stand.size()>3 and is_equal_approx(float(furniture.plant_stand[3]),1.0):furniture.plant_stand[3]=.7
	scale_defaults_version=1
func home_points() -> int:
	var points=0
	for value in play_affection.values(): points+=int(value)
	return points
func furniture_available(id: String) -> bool:
	return UNLOCKS.has("home_"+id) and (test_unlocks() or home_owned.get(id,false) or home_points()>=UNLOCKS["home_"+id])
func gift_name(id: String) -> String:
	return Furniture.ITEMS.get(id.trim_prefix("home_"),{}).get("name",id)
const REWARDS={"follow":1,"rub":1,"pet":1,"ball":2,"hand_feed":2,"snack":2,"cuddle":2,"doze":1,"relax":1,"playful":1,"personality":1,"decorate":1,"bowl":1,"water":1,"basket":1,"plant":1,"lamp":1,"shelter":1,"acorn":1,"home_rest":1,"home_play":1,"home_music":1,"home_read":1,"home_groom":1,"home_tea":1}
const ACTION_LABELS={"pet":"쓰다듬기","hand_feed":"직접 먹여주기","acorn":"도토리 놀이","follow":"마우스 따라오기","ball":"공 가져오기","playful":"폴짝 놀이","home_rest":"가구에서 휴식","home_music":"음악 감상","home_play":"러그 놀이","home_read":"독서","home_groom":"단장","home_tea":"티타임","water":"물 마시기","bowl":"식사","doze":"낮잠","cuddle":"토닥이기","snack":"간식 찾기","rub":"부비기","personality":"성격 놀이","plant":"식물 놀이","lamp":"조명 곁 휴식","decorate":"공간 꾸미기"}
var last_reward_action: Dictionary={}
var reward_times: Dictionary={}
func route_hint(_species: int,id: String) -> String:
	if not UNLOCKS.has(id): return "처음부터 함께해요"
	return "함께 쌓은 교감 %d / %d"%[mini(home_points(),UNLOCKS[id]),UNLOCKS[id]]
func unlock_rows(species: int) -> Array:
	var rows=[]
	for id in UNLOCKS:
		var piece_id=id.trim_prefix("home_")
		var category="놀이감" if piece_id in ["toy_ball","toy_mouse","toy_plush","play_rug"] else ("꾸미기" if piece_id in ["wall_clock","wall_shelf","plant_stand","alarm_clock","aquarium"] else "생활 가구")
		rows.append({"id":id,"title":gift_name(id),"category":category,"threshold":UNLOCKS[id],"open":unlocked(species,id),"hint":route_hint(species,id),"progress":1.0 if unlocked(species,id) else clampf(float(home_points())/maxf(1,UNLOCKS[id]),0,1)})
	rows.sort_custom(func(a,b): return a.threshold<b.threshold if a.threshold!=b.threshold else a.id<b.id)
	return rows
func unlocked_ids(species: int) -> Array:
	var ids=[]
	for id in UNLOCKS:
		if unlocked(species,id): ids.append(id)
	return ids

func reward_activity(species: int, action: String) -> void:
	if species<0 or species>=Catalog.IDS.size() or not REWARDS.has(action): return
	var key=str(species)+":"+action
	var now=Time.get_ticks_msec()/1000.0
	var interval=45.0 if action in ["bowl","water"] or action.begins_with("home_") else 8.0
	if reward_times.has(key) and now-float(reward_times[key])<interval: return
	var before_gifts=unlocked_ids(species)
	var before_foods: Array=[]
	for food in range(32):
		if food_available(species,food): before_foods.append(food)
	reward_times[key]=now
	var counts: Dictionary=activity_counts.get(str(species),{})
	counts[action]=int(counts.get(action,0))+1
	activity_counts[str(species)]=counts
	last_reward_action[str(species)]=action
	if action in CARE_ACTIONS: add_growth(species,int(REWARDS[action]))
	add_affection(species,int(REWARDS[action]),before_gifts)
	var new_foods: Array=[]
	for food in range(32):
		if food not in before_foods and food_available(species,food): new_foods.append(food)
	if not new_foods.is_empty(): food_unlocked.emit(species,new_foods)
func unlocked(_species: int, id: String) -> bool:
	if id in BASIC_ACTIONS: return true
	return id.begins_with("home_") and furniture_available(id.trim_prefix("home_"))

func test_unlocks() -> bool:
	return OS.has_feature("editor") and bool(ProjectSettings.get_setting("testing/unlock_all",false))

func can_action(species: int, id: int) -> bool:
	if id>=100 and id<132: return food_available(species,id-100)
	return true

func action_hint(_species: int, _id: int) -> String:
	if _id in [36,37]: return "기본 복장에서 볼 수 있어요"
	return ""

func progress_text(species: int) -> String:
	var lines=PackedStringArray(["우리 집 교감 %d · 모든 친구가 함께 쌓아요"%home_points(),"행동과 표정은 쓰다듬기·들기·물건 이용·생활 상황에 따라 나타나요.","식탁에서 먹고 마시고, 소파와 침대에서 쉬어요.","교감으로 생활 가구·놀이감·꾸미기 아이템이 열리며 점수는 차감되지 않아요.","쓰다듬기·놀이·교감 +1~2, 식사·물·가구 이용 +1.","같은 교감 행동은 8초, 식사·물·가구 이용은 45초 간격으로 기록해요.","놀이감은 함께하기에서 꺼내고, 가구는 집 꾸미기에서 배치해 이용하세요."])
	for row in unlock_rows(species): lines.append(("배치 가능 · " if row.open else "준비 중 · ")+row.title+("" if row.open else " · "+row.hint))
	return "\n".join(lines)

func next_gift(species: int) -> String:
	for row in unlock_rows(species):
		if not row.open: return "다음 아이템 · "+row.category+" · "+row.title+"\n"+row.hint
	return "모든 가구와 아이템을 배치할 수 있어요 · 오늘도 편안한 하루"
const PROPS=["cushion","bowl","basket","plant","lamp","shelter","acorn"]
var save_path="user://friends-release.json"
var selected=3
var palette=0
var play_affection: Dictionary={}
var layout: Dictionary={}
var hidden: Array=[]
var discoveries: Dictionary={}
var save_failed=false
var save_recovered=false
var personal_layout: Dictionary={}
var meals: Dictionary={}
var favorite_foods: Dictionary={}
var outfits: Dictionary={}
var outfit_colors: Dictionary={}
var furniture: Dictionary={}
var furniture_styles: Dictionary={}
var arrival_seen: Dictionary={}
var activity_space="floor"

func load_furniture(value) -> void:
	furniture.clear()
	if not value is Dictionary: return
	for id in preload("res://scripts/furniture_catalog.gd").ITEMS:
		var point=value.get(id)
		if point is Array and point.size()>=2 and point.size()<=5 and numeric(point[0]) and numeric(point[1]):
			furniture[id]=[clampf(float(point[0]),-100000,100000),clampf(float(point[1]),-100000,100000)]
			furniture[id].append(point.size()>2 and point[2]==true)
			furniture[id].append(clampf(float(point[3]),.6,1.6) if point.size()>3 and numeric(point[3]) else Furniture.default_scale(id))
			furniture[id].append(clampi(int(point[4]),-100000,100000) if point.size()>4 and numeric(point[4]) else 0)

func read_save(path: String):
	if not FileAccess.file_exists(path): return null
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK: return null
	return parser.data if parser.data is Dictionary else null

func load_game() -> void:
	save_recovered=false
	var data=read_save(save_path)
	if data==null:
		data=read_save(save_path+".bak")
		if data==null: return
		save_recovered=true
	load_furniture(data.get("furniture",{}))
	migrate_scale_defaults(clean_number(data.get("scale_defaults_version"),0,1))
	arrival_seen.clear()
	var seen=data.get("arrival_seen",{})
	if seen is Dictionary:
		for id in ["toy_ball","toy_mouse","alarm_clock"]:
			if seen.get(id,false)==true: arrival_seen[id]=true
	furniture_styles.clear()
	var styles=data.get("furniture_styles",{})
	if styles is Dictionary:
		for id in Furniture.ITEMS:
			if styles.has(id): furniture_styles[id]=Furniture.normalize_style(styles[id])
	home_initialized=data.get("home_initialized",false)==true
	starter_layout_version=int(clean_number(data.get("starter_layout_version"),0,1))
	var saved_owned=data.get("home_owned",{})
	for id in Furniture.ITEMS:
		if furniture.has(id) or (saved_owned is Dictionary and saved_owned.get(id,false)==true): home_owned[id]=true
	activity_space=preload("res://scripts/living_space.gd").clean(data.get("activity_space"))
	guide_seen=data.get("guide_seen",false)==true
	if not home_initialized: guide_seen=false
	if data.get("activity_counts") is Dictionary:
		for i in range(Catalog.IDS.size()):
			var counts=data.activity_counts.get(str(i),{})
			if not counts is Dictionary: continue
			var clean: Dictionary={}
			for action in REWARDS: clean[action]=clean_number(counts.get(action),0,9999)
			activity_counts[str(i)]=clean
	selected=clean_number(data.get("selected"),0,Catalog.IDS.size()-1)
	palette=clean_number(data.get("palette"),0,2)
	for i in range(Catalog.IDS.size()):
		var key=str(i)
		if data.get("outfits") is Dictionary: outfits[key]=clean_number(data.outfits.get(key),0,3)
		if data.get("outfit_colors") is Dictionary: outfit_colors[key]=clean_number(data.outfit_colors.get(key),0,5)
		if data.get("growth") is Dictionary: growth[key]=clean_number(data.growth.get(key),0,9999)
		if data.get("meals") is Dictionary: meals[key]=clean_number(data.meals.get(key,Catalog.DEFAULT_MEALS[i]),0,31)
		if data.get("favorite_foods") is Dictionary and data.favorite_foods.get(key)==true: favorite_foods[key]=true
		if data.get("personal_layout") is Dictionary and data.personal_layout.get(key) is Dictionary:
			var places: Dictionary={}
			for id in ["cushion","shelter"]:
				var point=data.personal_layout[key].get(id)
				if point is Array and point.size()==2 and numeric(point[0]) and numeric(point[1]): places[id]=[float(point[0]),float(point[1])]
			personal_layout[key]=places
	if data.get("affection") is Dictionary:
		for i in range(Catalog.IDS.size()): play_affection[str(i)]=clean_number(data.affection.get(str(i)),0,9999)
	if data.get("layout") is Dictionary:
		for id in PROPS:
			var point=data.layout.get(id)
			if point is Array and point.size()==2 and numeric(point[0]) and numeric(point[1]): layout[id]=[float(point[0]),float(point[1])]
	if data.get("hidden") is Array:
		for id in data.hidden:
			if id in PROPS and id not in hidden: hidden.append(id)
	if data.get("discoveries") is Dictionary:
		for i in range(Catalog.IDS.size()):
			var id=data.discoveries.get(str(i))
			if id in PROPS: discoveries[str(i)]=id

func numeric(value) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))
func clean_number(value, low: int, high: int) -> int:
	return clampi(int(value),low,high) if numeric(value) else low

func save_game() -> void:
	var file=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file==null:
		save_failed=true
		return
	file.store_string(JSON.stringify({"version":9,"scale_defaults_version":scale_defaults_version,"starter_layout_version":starter_layout_version,"home_initialized":home_initialized,"home_owned":home_owned,"activity_space":activity_space,"guide_seen":guide_seen,"activity_counts":activity_counts,"growth":growth,"selected":selected,"palette":palette,"affection":play_affection,"layout":layout,"hidden":hidden,"discoveries":discoveries,"personal_layout":personal_layout,"meals":meals,"favorite_foods":favorite_foods,"outfits":outfits,"outfit_colors":outfit_colors,"furniture":furniture,"furniture_styles":furniture_styles,"arrival_seen":arrival_seen}))
	file.flush()
	var write_error=file.get_error()
	file.close()
	if write_error!=OK:
		save_failed=true
		return
	# Never replace the last good backup with a damaged primary file.
	if read_save(save_path)!=null and DirAccess.copy_absolute(save_path,save_path+".bak")!=OK:
		save_failed=true
		return
	save_failed=DirAccess.rename_absolute(save_path+".tmp",save_path)!=OK

func add_affection(species: int, amount: int=1, before_unlocks: Array=[]) -> void:
	if species<0 or species>=Catalog.IDS.size(): return
	if before_unlocks.is_empty(): before_unlocks=unlocked_ids(species)
	var before=int(play_affection.get(str(species),0))
	play_affection[str(species)]=clampi(before+amount,0,9999)
	var gifts: Array=[]
	for id in UNLOCKS:
		if not test_unlocks() and id not in before_unlocks and unlocked(species,id):
			gifts.append(id)
			home_owned[id.trim_prefix("home_")]=true
	save_game()
	affection_changed.emit(species,gifts)

