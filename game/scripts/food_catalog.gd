extends RefCounted
# Restaurant menu and tracking with matching newly generated character art.
const Keyed=preload("res://scripts/keyed_art.gd")
const Catalog=preload("res://scripts/animal_catalog.gd")
const NATURAL_NAMES=["통당근","생연어","도토리","사과 조각","옥수수","블루베리","벌집꿀","메추리알","정어리","단호박","해바라기씨","죽순","빨간 사과","생클로버","유칼립투스 잎","멸치"]
const NAMES=[
["당근 수프","당근 채소밥","당근 케이크","당근 국수"],
["연어 토스트","생선 구이 덮밥","생선 크로켓","생선 국수"],
["도토리 죽","도토리 밥","도토리 쿠키","도토리 국수"],
["밤죽","알밤 밥","밤 케이크","알밤 수프"],
["허브 오믈렛","허브 파스타","따뜻한 허브차","허브 수프"],
["산딸기 토스트","산딸기 샐러드","산딸기 타르트","산딸기차"],
["꿀 토스트","꿀 채소 덮밥","꿀 우유","꿀 생강차"],
["버섯 수프","버섯 덮밥","버섯 키슈","버섯 우동"]]
static var icons: Array=[]
static var natural_icons: Array=[]
static var tracking: Dictionary={}
static var counts: Dictionary={}
static func prepare() -> void:
	if icons.size()==32: return
	icons=Keyed.cells("res://assets/food/character-menu-v2.png",4,8,true,[0,225,435,645,855,1065,1275,1490,1774])
	var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://assets/food/meal-tracking.json"))
	if parsed is Dictionary: tracking=parsed
	for key in tracking:
		var parts=str(key).split("-")
		if parts.size()!=3: continue
		var group=parts[0]+"-"+parts[1]
		counts[group]=maxi(int(counts.get(group,0)),int(parts[2])+1)
static func title(id: int) -> String:
	return NAMES[id/4][id%4]
static func title_for(species: int, id: int) -> String:
	return NATURAL_NAMES[species] if species>=0 and species<Catalog.DEFAULT_MEALS.size() and id==Catalog.DEFAULT_MEALS[species] else title(id)
static func action(id: int) -> String:
	return "drink" if id in [18,23,26,27] else "eat"
static func icon(id: int) -> Texture2D:
	prepare()
	return icons[clampi(id,0,31)]
static func icon_for(species: int, id: int) -> Texture2D:
	if species>=0 and species<Catalog.DEFAULT_MEALS.size() and id==Catalog.DEFAULT_MEALS[species]:
		if natural_icons.is_empty(): natural_icons=Keyed.cells("res://assets/food/natural-defaults-v1.png",4,4,true)
		if natural_icons.size()==16: return natural_icons[species]
	return icon(id)
static func hand_rect(species: int, bank: int, frame: int) -> Vector4:
	if species>=8: return preload("res://scripts/consumption_art.gd").hand_rect(species,bank,frame)
	var count=int(counts.get("%d-%d"%[species,bank],16))
	var index=floori(frame*count/16.0)
	var entry=tracking.get("%d-%d-%02d"%[species,bank,index],{})
	var r=entry.get("rect",[.29,.61,.42,.21])
	return Vector4(r[0],r[1],r[2],r[3])
