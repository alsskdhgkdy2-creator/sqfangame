## 웹(브라우저)과의 연결: 메모 입력 창(window.prompt), 저장 내려받기, 파일 가져오기, 디버그 주소(?debug=1)의 window.sqfDebug.
## 웹이 아니면 is_web() 이 false 이고 다른 함수는 부르지 않는다(화면이 PC 경로를 쓴다).
## JavaScriptBridge 콜백 객체는 멤버로 잡아 둔다(지역 변수면 풀려서 콜백이 오지 않을 수 있다, 05 §8.5).
class_name WebBridge
extends RefCounted

## 가져오기 크기 한도(바이트).
const IMPORT_LIMIT := 1048576

## 가져오기 결과: (토큰, 상태 "ok"·"cancel"·"error"·"too_large", 글).
var on_import: Callable
## 디버그 요청: JSON 문자열 → 결과 JSON 문자열.
var on_debug_request: Callable

var _import_cb: JavaScriptObject
var _debug_cb: JavaScriptObject
var _debug: JavaScriptObject
var _forced := ""
## 이 연결의 번호. 전역(window.sqfImportResult·sqfDebug)을 누가 걸었는지 남겨, 정리할 때 남의 것은 지우지 않는다.
var _owner := ""
static var _next_owner := 0


## force = "web"·"native" 이면 그렇게 본다(시험용). 빈 문자열이면 실제 플랫폼.
func _init(force: String = "") -> void:
	_forced = force
	_next_owner += 1
	_owner = "%d-%d" % [Time.get_ticks_usec(), _next_owner]


func is_web() -> bool:
	if not _forced.is_empty():
		return _forced == "web"
	return OS.has_feature("web")


## 주소에 ?debug=1 이 있는지.
func debug_requested() -> bool:
	if not OS.has_feature("web"):
		return false
	var v: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('debug')", true)
	return typeof(v) == TYPE_STRING and v == "1"


## 브라우저 입력 창. 확인이면 글(빈 문자열 포함), 취소·막힘이면 null.
## 동기로 막는다. 닫힌 뒤 화면이 미리 받은 입력과 손가락 상태를 비운다.
func prompt(message: String, default_text: String) -> Variant:
	var code := "(function(){try{return window.prompt(%s,%s);}catch(e){return null;}})()" % [JSON.stringify(message), JSON.stringify(default_text)]
	var v: Variant = JavaScriptBridge.eval(code, true)
	return v if typeof(v) == TYPE_STRING else null


## 단추를 누른 처리 안에서 바로 부른다(나중에 부르면 브라우저가 막을 수 있다).
func download(bytes: PackedByteArray, file_name: String, mime: String) -> void:
	JavaScriptBridge.download_buffer(bytes, file_name, mime)


## 숨은 <input type=file> 로 파일을 고르게 한다. 결과는 on_import(token, status, text) 로 온다.
## 단추를 누른 처리 안에서 불러야 한다(사용자 활성화). 크기 한도는 읽기 전에 JS 에서 본다.
## 요청마다 만든 때의 주인·토큰·콜백을 묶어 둔다. 읽기가 끝났을 때 이 요청이 아직 지금 주인의 현재 요청이
## 아니면(새 요청·dispose·다른 연결이 덮어씀) 결과를 버리고 window.sqfImportState.dropped 를 1 올린다(05 §8.5).
func start_import(token: int) -> void:
	if _import_cb == null:
		_import_cb = JavaScriptBridge.create_callback(_on_import_js)
	JavaScriptBridge.get_interface("window").sqfImportResult = _import_cb
	var code := """
(function(){
	var st = window.sqfImportState || (window.sqfImportState = {dropped: 0});
	window.sqfImportOwner = %s;
	if (st.input) { st.input.remove(); st.input = null; }
	var inp = document.createElement('input');
	inp.type = 'file'; inp.accept = '.json,application/json'; inp.style.display = 'none';
	document.body.appendChild(inp); st.input = inp;
	var req = {owner: window.sqfImportOwner, token: %d, cb: window.sqfImportResult, done: false};
	st.current = req;
	function fin(status, text) {
		if (req.done) return; req.done = true;
		inp.remove(); if (st.input === inp) st.input = null;
		if (st.current !== req || window.sqfImportOwner !== req.owner || window.sqfImportResult !== req.cb || typeof req.cb !== 'function') {
			st.dropped = (st.dropped || 0) + 1;
			return;
		}
		st.current = null;
		req.cb(req.token, status, text || '');
	}
	inp.addEventListener('change', function(){
		var f = inp.files && inp.files[0];
		if (!f) { fin('cancel'); return; }
		if (f.size > %d) { fin('too_large'); return; }
		f.text().then(function(t){ fin('ok', t); }, function(e){ fin('error', String(e)); });
	});
	inp.addEventListener('cancel', function(){ fin('cancel'); });
	inp.click();
})();
""" % [JSON.stringify(_owner), token, IMPORT_LIMIT]
	JavaScriptBridge.eval(code, true)


func _on_import_js(args: Array) -> void:
	if on_import.is_valid() and args.size() >= 3:
		on_import.call(int(args[0]), str(args[1]), str(args[2]))


## window.sqfDebug = {ready, snapshot, result, request(json)} 를 만든다. ?debug=1 일 때만 부른다.
func setup_debug() -> void:
	JavaScriptBridge.eval("window.sqfDebug = {ready: false, snapshot: '', result: '', request: null, owner: %s};" % JSON.stringify(_owner), true)
	_debug = JavaScriptBridge.get_interface("sqfDebug")
	_debug_cb = JavaScriptBridge.create_callback(_on_debug_js)
	_debug.request = _debug_cb


## 상태 요약(JSON 문자열)을 내보낸다.
func publish(snapshot_json: String) -> void:
	if _debug == null:
		return
	_debug.snapshot = snapshot_json
	_debug.ready = true


func _on_debug_js(args: Array) -> void:
	if _debug == null or args.is_empty() or not on_debug_request.is_valid():
		return
	_debug.result = on_debug_request.call(str(args[0]))


## 화면이 사라질 때 부른다: 이 연결이 건 전역 콜백·숨은 파일 입력을 걷고 콜백 객체를 놓는다.
## 다른(새) 연결이 이미 덮어쓴 전역은 건드리지 않는다. 웹이 아니면 콜백만 놓는다. 여러 번 불러도 된다.
func dispose() -> void:
	on_import = Callable()
	on_debug_request = Callable()
	if OS.has_feature("web") and (_import_cb != null or _debug != null):
		var code := """
(function(){
	var me = %s;
	if (window.sqfImportOwner === me) {
		var st = window.sqfImportState;
		if (st && st.input) { st.input.remove(); st.input = null; }
		if (st) { st.current = null; }  // 읽는 중인 요청도 무효(끝나면 버린다)
		delete window.sqfImportResult; delete window.sqfImportOwner;
	}
	if (window.sqfDebug && window.sqfDebug.owner === me) { delete window.sqfDebug; }
})();
""" % JSON.stringify(_owner)
		JavaScriptBridge.eval(code, true)
	_import_cb = null
	_debug_cb = null
	_debug = null


## 시험용: 걸어 둔 콜백이 남아 있는지.
func has_callbacks() -> bool:
	return _import_cb != null or _debug_cb != null or _debug != null or not on_import.is_null() or not on_debug_request.is_null()


func device_pixel_ratio() -> float:
	if not OS.has_feature("web"):
		return 1.0
	var v: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true)
	return float(v) if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT else 1.0
