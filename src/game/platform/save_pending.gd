## 웹 저장의 IndexedDB 반영 기다림(05 §8.3). 저장을 시도할 때마다(성공·실패 모두) 그 슬롯의 메모리 파일 묶음
## (본 파일·.tmp·.bak 각각 있는지와 바이트의 SHA-256)을 「반영 대기」에 올리고, IndexedDB 가 그 묶음을 그대로(없는 파일은 없게)
## 담은 것을 읽어 확인한 뒤에야 내린다. 그러면 메모리에서 읽기 순서(본 파일 → .tmp → .bak)로 고를 후보와 IndexedDB 에서
## 고를 후보가 같다(마지막 이름 바꾸기가 실패해 본 파일이 없는 경우도). 화면은 대기가 하나라도 있는 동안 「저장 중」 표시를 보인다.
## 시간으로 내리지 않는다: 읽기가 실패하거나 늦으면 대기가 남는다(표시가 남는 쪽이 안전하다).
## 판정은 generation 이 아니라 바이트 그대로다: 수동 슬롯을 불러오면 generation 이 그 파일 값으로 돌아가므로(05 §8.1)
## IndexedDB 의 낡은 자동 저장이 방금 쓴 것과 같거나 큰 generation 을 가질 수 있다. 같은 슬롯에 다시 올리면 새 묶음으로 바뀐다.
## 읽는 함수는 밖에서 넣는다: reader.call(paths: PackedStringArray, done: Callable), done.call(결과 사전: 경로 →
## 바이트(PackedByteArray), 열쇠가 없으면 null, 그 밖의 값(기록은 있는데 내용을 읽을 수 없음 = false 등)은 어떤 묶음과도 맞지 않는다).
## 읽기에 실패하면 빈 사전(물은 경로가 결과에 없으면 판정하지 않는다). 웹에서는 WebBridge.read_idb_files, 시험에서는 가짜.
## done 은 같은 호출 안에서 불러도 되고 나중에 불러도 된다.
class_name SavePending
extends RefCounted

## 대기가 바뀌었다(올림·내림).
signal changed

## 대기가 있는 동안 읽기 사이 간격(초). 대기가 없으면 읽지 않는다.
const POLL_SEC := 0.25
## 결과가 이만큼 오지 않은 읽기는 버리고 다시 읽는다(늦게 온 결과는 번호로 가린다).
const READ_TIMEOUT_SEC := 5.0

## false 면 아무것도 올리지 않는다(웹이 아님·user:// 가 IndexedDB 에 이어지지 않음·연결 없음).
var enabled := false
var reader: Callable
## 시작한 읽기 수(시험·디버그).
var reads := 0

var _pending := {}  # 슬롯 → {"generation": 값, "files": 경로 → 바이트의 SHA-256(없는 파일은 "")}
var _wait := 0.0
var _read_id := 0
var _in_flight := false
var _in_flight_age := 0.0


## 저장을 시도한 뒤(성공·실패 모두) 부른다. files 는 그 슬롯의 파일 묶음: IndexedDB 의 열쇠(전역 경로) → 메모리의
## 바이트 그대로(PackedByteArray, 없는 파일은 null). generation 은 상태 요약에 내는 값(그 묶음이 담은 저장의 generation).
func note(slot: String, generation: int, files: Dictionary) -> void:
	if not enabled or files.is_empty():
		return
	if _pending.is_empty() and not _in_flight:
		_wait = POLL_SEC  # 동기화는 다음 프레임에 시작한다: 바로 읽지 않는다
	var want := {}
	for path in files:
		want[path] = digest(files[path]) if typeof(files[path]) == TYPE_PACKED_BYTE_ARRAY else ""
	_pending[slot] = {"generation": generation, "files": want}
	changed.emit()


func is_pending() -> bool:
	return not _pending.is_empty()


## 슬롯 → 반영을 기다리는 generation(디버그 상태 요약).
func generations() -> Dictionary:
	var out := {}
	for slot in _pending:
		out[slot] = _pending[slot]["generation"]
	return out


## 매 프레임 부른다. 대기가 있을 때만 POLL_SEC 마다 한 번(읽는 중이면 기다린다) 읽는다.
func tick(delta: float) -> void:
	if _pending.is_empty() or not reader.is_valid():
		return
	if _in_flight:
		_in_flight_age += delta
		if _in_flight_age < READ_TIMEOUT_SEC:
			return
		_in_flight = false
		_wait = 0.0
	_wait -= delta
	if _wait > 0.0:
		return
	_read_id += 1
	_in_flight = true
	_in_flight_age = 0.0
	reads += 1
	var paths := PackedStringArray()
	for slot in _pending:
		for path in _pending[slot]["files"]:
			paths.append(path)
	reader.call(paths, _on_read.bind(_read_id))


func _on_read(results: Dictionary, id: int) -> void:
	if id != _read_id or not _in_flight:
		return  # 버린 읽기의 늦은 결과
	_in_flight = false
	_wait = POLL_SEC
	var done: Array = []
	for slot in _pending:
		if _mirrored(_pending[slot]["files"], results):
			done.append(slot)
	for slot in done:
		_pending.erase(slot)
	if not done.is_empty():
		changed.emit()


## 바이트의 SHA-256(16진).
static func digest(bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		h.update(bytes)
	return h.finish().hex_encode()


## IndexedDB 가 묶음을 그대로 담았는지: 경로마다 있는 파일은 같은 바이트, 없는 파일은 없음(null).
## 물은 경로가 결과에 없거나 바이트도 null 도 아니면(읽을 수 없는 기록) 아니다.
static func _mirrored(want: Dictionary, results: Dictionary) -> bool:
	for path in want:
		if not results.has(path):
			return false
		var data: Variant = results[path]
		var got := ""
		if typeof(data) == TYPE_PACKED_BYTE_ARRAY:
			got = digest(data)
		elif typeof(data) != TYPE_NIL:
			return false
		if got != want[path]:
			return false
	return true
