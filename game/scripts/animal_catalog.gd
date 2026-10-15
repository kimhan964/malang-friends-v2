extends RefCounted
const IDS=["rabbit","otter","squirrel","hedgehog","raccoon","fox","bear","owl","cat","puppy","hamster","panda","red_panda","lamb","koala","penguin"]
const NAMES=["모루 · 토끼","보리 · 수달","도토 · 다람쥐","밤이 · 고슴도치","누리 · 너구리","솔 · 여우","두리 · 곰","달 · 부엉이","치즈 · 고양이","쿠키 · 강아지","콩이 · 햄스터","포포 · 판다","단풍 · 레서판다","몽실 · 아기 양","코코 · 코알라","빙글 · 펭귄"]
const DISPLAY_HEIGHT=110.0*2.0/3.0
const WORLD_SPEED_MULTIPLIER=1.3
# Existing prop spacing/size ratios extracted once from the historical textures.
# No runtime loading of obsolete character resources is necessary.
const PROP_ASPECT=[0.6640625,1.15625,1.0078125,1.359375,1.40625,0.90625,0.8515625,0.9296875,0.955223880597015,1.078125,0.923913043478261,0.961722488038278,0.979166666666667,0.886699507389163,1.00473933649289,0.939252336448598]
const HEIGHTS=[1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0]
const CYCLE_SECONDS=[2.0,2.4,1.9,2.5,2.4,2.1,2.7,2.5,2.0,1.8,1.7,2.7,2.0,2.2,2.6,2.3]
const DEFAULT_MEALS=[0,4,8,12,16,20,24,28,4,24,10,17,20,9,18,5]
static func path(species: int) -> String:
	return "res://assets/animals/%s.res"%IDS[species]
