## 웹(브라우저)과의 연결: 메모 입력 창(window.prompt), 저장 내려받기, 파일 가져오기, 디버그 주소(?debug=1)의 window.sqfDebug,
## 저장 반영 확인(IndexedDB 읽기, 05 §8.3).
## 디버그 주소에서만 &seed=N(0 이상의 정수)으로 새 게임 시드를 고정한다(웹 확인 도구의 재현용).
## 웹이 아니면 is_web() 이 false 이고 다른 함수는 부르지 않는다(화면이 PC 경로를 쓴다).
## JavaScriptBridge 콜백 객체는 멤버로 잡아 둔다(지역 변수면 풀려서 콜백이 오지 않을 수 있다, 05 §8.5).
class_name WebBridge
extends RefCounted

## 가져오기 크기 한도(바이트).
const IMPORT_LIMIT := 1048576
## 디버그 주소 &seed=N 으로 받는 가장 큰 시드: 새 게임 시드(fresh_seed 의 randi)와 같은 32비트 부호 없는 정수 범위.
const SEED_MAX := 4294967295

## 가져오기 결과: (토큰, 상태 "ok"·"cancel"·"error"·"too_large", 글).
var on_import: Callable
## 디버그 요청: JSON 문자열 → 결과 JSON 문자열.
var on_debug_request: Callable

var _import_cb: JavaScriptObject
var _idb_cb: JavaScriptObject
## IndexedDB 읽기 요청 번호 → 결과를 받을 Callable.
var _idb_done := {}
var _idb_next := 0
var _debug_cb: JavaScriptObject
var _debug: JavaScriptObject
var _forced := ""
## 시험용 주소 인자 글("debug=1&seed=5"). 비어 있지 않으면 브라우저 주소 대신 이것을 읽는다.
var _query := ""
## 이 연결의 번호. 전역(window.sqfImportResult·sqfDebug)을 누가 걸었는지 남겨, 정리할 때 남의 것은 지우지 않는다.
var _owner := ""
static var _next_owner := 0


## force = "web"·"native" 이면 그렇게 본다(시험용). 빈 문자열이면 실제 플랫폼. query 는 시험용 주소 인자 글.
func _init(force: String = "", query: String = "") -> void:
	_forced = force
	_query = query
	_next_owner += 1
	_owner = "%d-%d" % [Time.get_ticks_usec(), _next_owner]


func is_web() -> bool:
	if not _forced.is_empty():
		return _forced == "web"
	return OS.has_feature("web")


## 주소 인자 하나. 없으면 빈 문자열(웹이 아니고 시험용 인자 글도 없으면 늘 빈 문자열).
func url_param(key: String) -> String:
	if not _query.is_empty():
		for part in _query.trim_prefix("?").split("&", false):
			var kv := part.split("=", true, 1)
			if kv[0].uri_decode() == key:
				return kv[1].uri_decode() if kv.size() > 1 else ""
		return ""
	if not OS.has_feature("web"):
		return ""
	var v: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get(%s)" % JSON.stringify(key), true)
	return v if typeof(v) == TYPE_STRING else ""


## 주소에 ?debug=1 이 있는지.
func debug_requested() -> bool:
	return url_param("debug") == "1"


## 디버그 주소의 새 게임 시드(&seed=N). 디버그 주소가 아니거나, 없거나, parse_seed 가 받지 않는 글이면 -1.
func debug_seed() -> int:
	if not debug_requested():
		return -1
	return parse_seed(url_param("seed"))


## 시드 글 → 0..SEED_MAX, 받지 않으면 -1. 십진 숫자만 받는다(부호·공백·소수점 없음, 앞의 0 은 괜찮다).
## 범위는 바꾸기 전에 글의 길이·글자로 본다: to_int() 는 int64 를 넘는 글에서 오류를 내고 상한값을 돌려준다.
static func parse_seed(text: String) -> int:
	if text.is_empty():
		return -1
	for i in text.length():
		var c := text.unicode_at(i)
		if c < 0x30 or c > 0x39:
			return -1
	var digits := text.lstrip("0")
	if digits.is_empty():
		return 0
	var max_text := str(SEED_MAX)
	if digits.length() > max_text.length() or (digits.length() == max_text.length() and digits > max_text):
		return -1
	return digits.to_int()


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
	if not OS.has_feature("web"):
		return  # 시험(웹 아님): 요청은 화면 함수를 바로 부른다
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
	_idb_done.clear()
	if OS.has_feature("web") and (_import_cb != null or _debug != null or _idb_cb != null):
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
	if (window.sqfIdbOwners) { delete window.sqfIdbOwners[me]; }  // 읽는 중인 IndexedDB 결과는 버린다
})();
""" % JSON.stringify(_owner)
		JavaScriptBridge.eval(code, true)
	_import_cb = null
	_idb_cb = null
	_debug_cb = null
	_debug = null


## 시험용: 걸어 둔 콜백이 남아 있는지.
func has_callbacks() -> bool:
	return _import_cb != null or _debug_cb != null or _debug != null or _idb_cb != null or not on_import.is_null() \
		or not on_debug_request.is_null() or not _idb_done.is_empty()


## 저장 반영 확인(IndexedDB 읽기)을 쓸 수 있는지: 진짜 웹 빌드이고 user:// 가 IndexedDB 에 이어져 있을 때만.
func can_read_idb() -> bool:
	return is_web() and OS.has_feature("web") and OS.is_userfs_persistent()


## Godot 의 IndexedDB(DB /userfs, 저장소 FILE_DATA, 열쇠 = 전역 경로)에서 파일 글을 읽는다(web_check 의 idbAuto 와 같은 길).
## 결과는 나중에 done.call(경로 → 바이트(PackedByteArray), 열쇠가 없으면 null, 기록은 있는데 내용을 읽을 수 없으면 false) 로 온다.
## 읽기가 실패하면 빈 사전. 화면이 사라진 뒤의 결과는 버린다.
## DB 가 없으면 만들지 않는다(버전 올림을 취소). 읽은 뒤 연결을 닫는다(Godot 의 동기화를 막지 않게).
func read_idb_files(paths: PackedStringArray, done: Callable) -> void:
	if not OS.has_feature("web"):
		return
	if _idb_cb == null:
		_idb_cb = JavaScriptBridge.create_callback(_on_idb_js)
	_idb_next += 1
	for id in _idb_done.keys():
		if int(id) < _idb_next - 8:
			_idb_done.erase(id)  # 오지 않은 낡은 결과(SavePending 이 시간 초과로 버렸다)
	_idb_done[_idb_next] = done
	var code := """
(function(){
	var owners = window.sqfIdbOwners || (window.sqfIdbOwners = {});
	if (window.sqfIdbRead) return;
	window.sqfIdbRead = function(owner, id, keysJson, cb) {
		owners[owner] = cb;
		var keys = JSON.parse(keysJson), out = {}, sent = false;
		function fin(err) {
			if (sent) return; sent = true;
			if (owners[owner] !== cb) return;  // 화면이 사라졌거나 다른 연결이 덮어씀
			try { cb(id, err ? '{}' : JSON.stringify(out), err || ''); } catch (e) {}
		}
		var req;
		try { req = indexedDB.open('/userfs'); } catch (e) { fin('open'); return; }
		req.onupgradeneeded = function(){ req.transaction.abort(); };
		req.onerror = function(){ fin('open'); };
		req.onsuccess = function(){
			var db = req.result;
			try {
				var tx = db.transaction('FILE_DATA', 'readonly'), st = tx.objectStore('FILE_DATA');
				keys.forEach(function(k){
					var g = st.get(k);
					g.onsuccess = function(){
						var r = g.result;
						if (r === undefined) { out[k] = null; return; }  // 정말 없는 열쇠만 null
						out[k] = false;  // 있는데 내용을 읽을 수 없는 기록: 어떤 파일과도 같지 않다
						var c = r && r.contents;
						if (c instanceof ArrayBuffer || ArrayBuffer.isView(c)) {  // Emscripten 은 형식 배열(종류는 판마다 다르다)로 둔다
							try {
								var u = ArrayBuffer.isView(c) ? new Uint8Array(c.buffer, c.byteOffset, c.byteLength) : new Uint8Array(c), bin = '';
								for (var i = 0; i < u.length; i += 0x8000) bin += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000));
								out[k] = btoa(bin);  // 바이트 그대로(base64)
							} catch (e) {}
						}
					};
				});
				tx.oncomplete = function(){ db.close(); fin(''); };
				tx.onerror = tx.onabort = function(){ db.close(); fin('read'); };
			} catch (e) { db.close(); fin('read'); }
		};
	};
})();
"""
	JavaScriptBridge.eval(code, true)
	JavaScriptBridge.get_interface("window").sqfIdbRead(_owner, _idb_next, JSON.stringify(paths), _idb_cb)


func _on_idb_js(args: Array) -> void:
	if args.size() < 3:
		return
	var done: Variant = _idb_done.get(int(args[0]))
	_idb_done.erase(int(args[0]))
	if not (done is Callable) or not (done as Callable).is_valid():
		return
	var parsed: Variant = JSON.parse_string(str(args[1]))
	if not (parsed is Dictionary) or not str(args[2]).is_empty():
		(done as Callable).call({})
		return
	var out := {}
	for k in parsed:
		var v: Variant = parsed[k]
		out[k] = Marshalls.base64_to_raw(v) if typeof(v) == TYPE_STRING else v  # null = 없음, false = 읽을 수 없음
	(done as Callable).call(out)


func device_pixel_ratio() -> float:
	if not OS.has_feature("web"):
		return 1.0
	var v: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true)
	return float(v) if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT else 1.0
