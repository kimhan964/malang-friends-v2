extends RefCounted

const STYLE_NAMES=[
	["클로버 케이프","당근 산책 조끼","봄날 스웨터"],
	["물결 케이프","조약돌 조끼","강가 스웨터"],
	["도토리 케이프","숲길 조끼","참나무 스웨터"],
	["낙엽 케이프","밤송이 조끼","포근 스웨터"],
	["체크 케이프","탐험 조끼","개울 스웨터"],
	["단풍 케이프","숲사냥 조끼","노을 스웨터"],
	["벌꿀 케이프","통나무 조끼","겨울 스웨터"],
	["달빛 케이프","별자리 조끼","밤하늘 스웨터"],
	["생선 케이프","골목 산책 조끼","포근 스웨터"],
	["비스킷 케이프","산책 조끼","체크 스웨터"],
	["해바라기 케이프","씨앗 주머니 조끼","복실 스웨터"],
	["대나무 케이프","느긋한 조끼","구름 스웨터"],
	["단풍잎 케이프","나무타기 조끼","숲빛 스웨터"],
	["초원 케이프","목동 조끼","양털 스웨터"],
	["유칼립투스 케이프","나무타기 조끼","포근 스웨터"],
	["눈꽃 케이프","빙하 탐험 조끼","겨울 스웨터"]
]
const COLOR_NAMES=["세이지","살구","하늘","라벤더","딸기","크림"]
const COLORS=["88a879","dc9078","79a9c5","a790c2","c96f7b","d8bd88"]

static func style_name(species: int, style: int) -> String:
	return "기본 복장" if style<=0 else STYLE_NAMES[clampi(species,0,15)][clampi(style-1,0,2)]

static func color_name(index: int) -> String:
	return COLOR_NAMES[clampi(index,0,COLOR_NAMES.size()-1)]

static func color(index: int) -> Color:
	return Color(COLORS[clampi(index,0,COLORS.size()-1)])
