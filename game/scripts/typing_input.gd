extends RefCounted
var socket: PacketPeerUDP
var helper_pid=-1
var token=""
var count=0
var connected=false
var last_packet=0
var error=""

func start() -> void:
	stop()
	count=0
	error=""
	if OS.get_name()!="Windows" or DisplayServer.get_name()=="headless":
		error="Windows에서 사용할 수 있어요"
		return
	socket=PacketPeerUDP.new()
	if socket.bind(0,"127.0.0.1")!=OK:
		error="입력 연결을 열지 못했어요"
		stop()
		return
	token=Crypto.new().generate_random_bytes(16).hex_encode()
	var relative="addons/typing_input/TypingInput.exe"
	var path=OS.get_executable_path().get_base_dir().path_join(relative)
	if OS.has_feature("editor"): path=ProjectSettings.globalize_path("res://"+relative)
	if not FileAccess.file_exists(path):
		error="입력 도우미 파일이 없어요"
		stop()
		return
	helper_pid=OS.create_process(path,PackedStringArray([str(OS.get_process_id()),str(socket.get_local_port()),token]),false)
	if helper_pid<=0: error="입력 도우미를 실행하지 못했어요"
	last_packet=Time.get_ticks_msec()

func poll() -> int:
	var before=count
	if socket:
		while socket.get_available_packet_count()>0:
			var packet=socket.get_packet().get_string_from_ascii().split(":")
			if packet.size()!=2 or packet[0]!=token or not packet[1].is_valid_int(): continue
			var next=int(packet[1])
			if next<count: continue
			count=next
			connected=true
			last_packet=Time.get_ticks_msec()
	if Time.get_ticks_msec()-last_packet>2500:
		connected=false
		if helper_pid>0: error="입력 연결이 끊겼어요 · 메뉴에서 다시 시작"
	return count-before

func stop() -> void:
	if helper_pid>0 and OS.is_process_running(helper_pid): OS.kill(helper_pid)
	helper_pid=-1
	connected=false
	if socket: socket.close()
	socket=null
