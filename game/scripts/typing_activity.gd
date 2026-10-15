extends RefCounted
# Session-only aggregate activity; no key identities or application history.
const WINDOW_MS=3000
const RATE_MULTIPLIER=60000.0/WINDOW_MS
const IDLE_MS=30000
var total=0
var apm=0
var window_actions=0
var active_ms=0
var last_tick=-1
var last_action=-1
var sampling=false
var recent: Array[Vector2i]=[]
var first=0

func update(now: int, actions: int, enabled: bool) -> void:
	if last_tick>=0 and sampling and enabled and last_action>=0:
		active_ms+=maxi(0,mini(now,last_action+IDLE_MS)-last_tick)
	last_tick=now
	sampling=enabled
	if not enabled:
		last_action=-1
		recent.clear()
		first=0
		window_actions=0
	if enabled and actions>0:
		total+=actions
		window_actions+=actions
		last_action=now
		recent.append(Vector2i(now,actions))
	while first<recent.size() and recent[first].x<=now-WINDOW_MS:
		window_actions-=recent[first].y
		first+=1
	if first>512 or first==recent.size():
		recent=recent.slice(first)
		first=0
	# Short trailing window gives current speed in actions/minute, not a minute's count.
	apm=roundi(window_actions*RATE_MULTIPLIER)

func suspend(now: int) -> void:
	update(now,0,sampling)
	update(now,0,false)

func time_text() -> String:
	var seconds=int(active_ms/1000)
	return "%02d:%02d:%02d"%[int(seconds/3600),int(seconds/60)%60,seconds%60]
