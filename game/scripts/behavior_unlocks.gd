extends RefCounted
const THRESHOLDS={"roll":8,"fly":20}
static func available(points: int,kind: String) -> bool: return points>=int(THRESHOLDS.get(kind,0))
static func hint(points: int,kind: String) -> String:
	var needed=int(THRESHOLDS.get(kind,0))
	return "처음부터 가능" if needed==0 else ("해금 완료 · 우리 집 교감 %d / %d"%[points,needed] if points>=needed else "우리 집 교감 %d / %d · %d 더 모으면 해금"%[points,needed,needed-points])
