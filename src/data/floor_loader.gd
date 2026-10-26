## 층 정의 JSON(문자 격자) → FloorModel. 검사 오류는 "파일:줄:열: 내용".
## 층 묶음(미궁 하나, M3 A1): data/floors/labyrinth.json 의 floors 차례가 깊이(B1F, B2F, …)이고 계단 짝은 load_set·check_set 이 본다.
## 도달·갇힘 분석(analyze)은 읽기와 따로 부른다(시험·층 작성 도구용, 게임은 부르지 않는다).
class_name FloorLoader
extends RefCounted

## 층 ID(파일 이름이 된다).
const FLOOR_ID_PATTERN := "^[a-z][a-z0-9_]*$"
const SET_KEYS := ["id", "floors", "entrance"]
const STAIR_WAYS := ["up", "down"]

const MAX_SIZE := 64
const CELL_CHARS := {".": FloorModel.Cell.FLOOR, "#": FloorModel.Cell.VOID, "~": FloorModel.Cell.DAMAGE, "=": FloorModel.Cell.ICE}
const H_CHARS := {"-": FloorModel.Edge.WALL, " ": FloorModel.Edge.OPEN, "D": FloorModel.Edge.DOOR, "L": FloorModel.Edge.SHORTCUT, "H": FloorModel.Edge.PASSAGE, "v": FloorModel.Edge.ONEWAY, "^": FloorModel.Edge.ONEWAY}
const V_CHARS := {"|": FloorModel.Edge.WALL, " ": FloorModel.Edge.OPEN, "D": FloorModel.Edge.DOOR, "L": FloorModel.Edge.SHORTCUT, "H": FloorModel.Edge.PASSAGE, ">": FloorModel.Edge.ONEWAY, "<": FloorModel.Edge.ONEWAY}
const ONEWAY_DIRS := {"v": Dir.S, "^": Dir.N, ">": Dir.E, "<": Dir.W}


class Result:
	extends RefCounted
	var floor_def: FloorModel
	var errors: Array[String] = []

	func ok() -> bool:
		return errors.is_empty()


## 층 묶음 읽기 결과. 오류가 없을 때만 floors 가 차례대로 다 있다.
class SetResult:
	extends RefCounted
	var floors: Array[FloorModel] = []
	## 마을로 나가는 문이 있는 층 ID(M3 A2, "entrance"): 그 층의 시작 칸이 마을 입구다. 없으면 "".
	var entrance := ""
	var errors: Array[String] = []

	func ok() -> bool:
		return errors.is_empty()


## 층 묶음 파일({"id", "floors": [층 ID, …], "entrance": 층 ID(선택)})과 같은 폴더의 <층 ID>.json 을 읽고 층 사이 검사(check_set)까지 한다.
## entrance(M3 A2)는 마을과 이어진 층이다(첫 층이어야 한다, GameDefs.from_parts 가 본다). 그 층의 시작 칸이 마을로 나가는 문이다.
static func load_set(path: String) -> SetResult:
	var r := SetResult.new()
	var file := path.get_file()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		r.errors.append("%s:1:1: 파일을 읽을 수 없다 (%s)" % [path, error_string(FileAccess.get_open_error())])
		return r
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		r.errors.append("%s: 맨 위가 객체가 아니다" % file)
		return r
	for k in data:
		if not SET_KEYS.has(k):
			r.errors.append("%s: %s 는 모르는 키다" % [file, str(k)])
	if typeof(data.get("id")) != TYPE_STRING or str(data["id"]).is_empty():
		r.errors.append("%s: id 는 빈 문자열이 아닌 문자열이어야 한다" % file)
	if data.has("entrance"):
		if typeof(data["entrance"]) != TYPE_STRING or str(data["entrance"]).is_empty():
			r.errors.append("%s: entrance 는 층 ID 문자열이어야 한다" % file)
		else:
			r.entrance = data["entrance"]
	if typeof(data.get("floors")) != TYPE_ARRAY or data["floors"].is_empty():
		r.errors.append("%s: floors 는 층 ID 가 하나 이상인 배열이어야 한다" % file)
		return r
	var id_re := RegEx.create_from_string(FLOOR_ID_PATTERN)
	var seen := {}
	for v in data["floors"]:
		if typeof(v) != TYPE_STRING or id_re.search(v) == null:
			r.errors.append("%s: floors 의 %s 가 층 ID(%s)가 아니다" % [file, str(v), FLOOR_ID_PATTERN])
			continue
		if seen.has(v):
			r.errors.append("%s: floors 에 %s 가 두 번 있다" % [file, v])
			continue
		seen[v] = true
		var fr := load_path(path.get_base_dir().path_join(v + ".json"))
		r.errors.append_array(fr.errors)
		if not fr.ok():
			continue
		if fr.floor_def.id != v:
			r.errors.append("%s.json: id %s 가 묶음의 층 ID %s 와 다르다" % [v, fr.floor_def.id, v])
			continue
		r.floors.append(fr.floor_def)
	if r.errors.is_empty():
		r.errors.append_array(check_set(r.floors))
	if not r.errors.is_empty():
		r.floors = []
	return r


## 층 사이 검사: ID 가 겹치지 않음, 첫 층에 시작 칸·첫 층이 아니면 시작 칸 없음(M3 A2: 시작 칸은 마을 입구 자리다), 첫 층이 아니면 올라가는 계단이 하나 이상,
## 계단은 다른 층의 계단과 짝(서로 가리킴), 내려가는 계단은 바로 아래층·올라가는 계단은 바로 위층, 짝과 방향이 반대.
static func check_set(floors: Array[FloorModel]) -> Array[String]:
	var out: Array[String] = []
	if floors.is_empty():
		out.append("층 묶음에 층이 없다")
		return out
	var index := {}
	for i in floors.size():
		if index.has(floors[i].id):
			out.append("층 묶음에 %s 가 두 번 있다" % floors[i].id)
		else:
			index[floors[i].id] = i
	if not floors[0].has_start():
		out.append("%s: 첫 층에는 start 가 있어야 한다" % floors[0].id)
	for i in floors.size():
		var f := floors[i]
		var ups := 0
		for st in f.stair_list():
			if st.way == "up":
				ups += 1
			var where := "%s: 계단 %d:%d" % [f.id, st.at.x, st.at.y]
			if st.to_floor == f.id:
				out.append("%s 이 같은 층을 가리킨다" % where)
				continue
			if not index.has(st.to_floor):
				out.append("%s 이 없는 층 %s 를 가리킨다" % [where, st.to_floor])
				continue
			var j: int = index[st.to_floor]
			if j != i + (1 if st.way == "down" else -1):
				out.append("%s: %s 계단은 바로 %s층으로 이어져야 하는데 %s 를 가리킨다" % [where, st.way, "아래" if st.way == "down" else "위", st.to_floor])
			var t := floors[j].stair_at(st.to_at)
			if t == null:
				out.append("%s 의 짝 %s %d:%d 에 계단이 없다" % [where, st.to_floor, st.to_at.x, st.to_at.y])
			elif t.to_floor != f.id or t.to_at != st.at:
				out.append("%s 의 짝 %s %d:%d 계단이 이 계단을 가리키지 않는다" % [where, st.to_floor, st.to_at.x, st.to_at.y])
			elif t.way == st.way:
				out.append("%s 과 짝 계단의 방향(way)이 같다" % where)
		if i > 0 and ups == 0:
			out.append("%s: 첫 층이 아니면 올라가는 계단(up)이 있어야 한다" % f.id)
		if i > 0 and f.has_start():
			out.append("%s: start 는 첫 층에만 둔다(시작 칸은 마을 입구 자리다)" % f.id)
	return out


static func load_path(path: String) -> Result:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		var r := Result.new()
		r.errors.append("%s:1:1: 파일을 읽을 수 없다 (%s)" % [path, error_string(FileAccess.get_open_error())])
		return r
	return parse_text(text, path.get_file())


## 문자열을 읽어 검사한다. 오류가 없을 때만 floor_def가 있다.
static func parse_text(text: String, source: String) -> Result:
	var ctx := _Ctx.new(text, source)
	var json := JSON.new()
	if json.parse(text) != OK:
		ctx.fail_at_line(json.get_error_line() + 1, 1, "JSON 읽기 실패: %s" % json.get_error_message())
		return ctx.result
	if typeof(json.data) != TYPE_DICTIONARY:
		ctx.fail_at_line(1, 1, "맨 위가 객체가 아니다")
		return ctx.result
	var f := _build(ctx, json.data)
	if ctx.result.ok():
		ctx.result.floor_def = f
	return ctx.result


# ---- 도달·갇힘 (실제 이동 규칙의 (멈춘 칸, 세계 상태) 전이 그래프) ----

const MAX_WORLD_BITS := 12  # 세계 상태 4096 가지까지
## 탐색할 (칸, 상태) 노드 수 한도. 이 기기(Galaxy S23, 웹 아님)에서 초당 약 4만 노드, f1_test 는 1104 노드다.
## 5만이면 약 1.3초이고 f1_test 의 45배, 20×20 층의 상태 64 가지(25,600 노드)까지 덮는다.
const MAX_ANALYSIS_NODES := 50000

## can_return 결과. 한도를 넘으면 「못 돌아감」이 아니라 「알 수 없음」.
enum Reach { NO, YES, UNKNOWN }


## 도달·갇힘 분석 경고 목록. 세계 상태는 찾은 숨은 통로·연 지름길의 집합(비트)이고 늘기만 한다.
## 들어오는 곳(entries: 시작 칸, 계단 칸 — 계단으로 오면 그 계단 칸에 선다)에서 닿을 수 없는 칸(미끄러져 지나간 칸은 닿은 것),
## 어떤 상태로도 나가는 곳(exits: 시작 칸, 올라가는 계단)에 가지 못하는 (칸, 상태)(갇힘). 내려가는 계단만 닿는 곳은 갇힘이다:
## 내려갔다 올라오면 같은 계단 칸에 다시 선다.
## 한도(비트 수, 노드 수 budget)를 넘으면 「분석 미완료」 경고 하나만 낸다.
static func analyze(f: FloorModel, source: String = "", budget: int = MAX_ANALYSIS_NODES) -> Array[String]:
	var out: Array[String] = []
	var bits := _world_bits(f)
	if bits.size() > MAX_WORLD_BITS:
		out.append("%s: 분석 미완료: 숨은 통로·지름길이 %d개라 세계 상태가 4096 을 넘는다" % [source, bits.size()])
		return out
	var g := _explore(f, entries(f), 0, bits, budget, {})
	if not g["complete"]:
		out.append("%s: 분석 미완료: 탐색 노드가 한도 %d 개를 넘었다" % [source, budget])
		return out
	var touched: Dictionary = g["touched"]
	for c in f.cells():
		if not touched.has(c):
			out.append("%s: 칸 %d:%d 에 %s 닿을 수 없다" % [source, c.x, c.y, "시작 칸에서" if f.stairs.is_empty() else "들어오는 곳(시작 칸·계단)에서"])
	var back := _returning(f, g, exits(f))
	var goal := "시작 칸으로 돌아올" if f.stairs.is_empty() else "나가는 곳(시작 칸·올라가는 계단)으로 갈"
	var keys: Array = g["next"].keys()
	keys.sort()
	for key in keys:
		if not back.has(key):
			var c := _node_cell(f, key)
			out.append("%s: 칸 %d:%d 에서 %s 수 없다 (갇힘, 세계 상태: %s)" % [source, c.x, c.y, goal, _describe(bits, _node_mask(f, key))])
	return out


## 들어오는 곳: 시작 칸(있으면), 계단 칸.
static func entries(f: FloorModel) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if f.has_start():
		out.append(f.start_at)
	for st in f.stair_list():
		out.append(st.at)
	return out


## 나가는 곳(칸 → true): 시작 칸(있으면, 첫 층의 입구), 올라가는 계단 칸.
static func exits(f: FloorModel) -> Dictionary:
	var out := {}
	if f.has_start():
		out[f.start_at] = true
	for st in f.stair_list():
		if st.way == "up":
			out[st.at] = true
	return out


## 칸 at 에 세계 상태 world 로 서 있을 때 나가는 곳(시작 칸·올라가는 계단)으로 갈 길이 있는지(조사·지름길 열기 포함).
## analyze 와 같은 한도를 쓰고, 넘으면 Reach.UNKNOWN.
static func can_return(f: FloorModel, at: Vector2i, world: WorldState, budget: int = MAX_ANALYSIS_NODES) -> Reach:
	var goals := exits(f)
	if goals.has(at):
		return Reach.YES
	var bits := _world_bits(f)
	if bits.size() > MAX_WORLD_BITS:
		return Reach.UNKNOWN
	var mask := 0
	for i in bits.size():
		if world.is_passage_found(bits[i]) or world.is_shortcut_open(bits[i]):
			mask |= 1 << i
	var starts: Array[Vector2i] = [at]
	var g := _explore(f, starts, mask, bits, budget, goals)
	if g["found"]:
		return Reach.YES
	return Reach.NO if g["complete"] else Reach.UNKNOWN


## 세계 상태 비트에 대응하는 경계: 숨은 통로 다음 지름길.
static func _world_bits(f: FloorModel) -> Array[Vector3i]:
	var bits := f.edges_of_kind(FloorModel.Edge.PASSAGE)
	bits.append_array(f.edges_of_kind(FloorModel.Edge.SHORTCUT))
	return bits


## (칸들, 상태)에서 닿는 노드와 전이. next: 노드 → 다음 노드 목록, touched: 지나간 칸 포함.
## 노드가 budget 개를 넘으면(budget < 1 이면 탐색 없이) complete=false 로 멈춘다. goals 칸에 멈추는 노드가 나오면 found=true 로 바로 멈춘다.
static func _explore(f: FloorModel, starts: Array[Vector2i], start_mask: int, bits: Array[Vector3i], budget: int, goals: Dictionary) -> Dictionary:
	if budget < 1:
		return {"next": {}, "touched": {}, "complete": false, "found": false}
	var worlds := {}
	var next := {}
	var touched := {}
	var queue: Array[int] = []
	for st in starts:
		touched[st] = true
		var n := _node(f, st, start_mask)
		if not next.has(n):
			next[n] = []
			queue.append(n)
	var head := 0
	while head < queue.size():
		var key := queue[head]
		head += 1
		var c := _node_cell(f, key)
		var mask := _node_mask(f, key)
		var world := _world_of(f, mask, bits, worlds)
		var targets: Array[int] = []
		for d in 4:
			var path := ExplorationRules.move_path(f, world, c, d)
			for p in path:
				touched[p] = true
			if not path.is_empty():
				targets.append(_node(f, path[-1], mask))
		for i in bits.size():
			if mask & (1 << i) == 0 and _can_unlock(f, bits[i], c):
				targets.append(_node(f, c, mask | (1 << i)))
		next[key] = targets
		for t in targets:
			if next.has(t):
				continue
			if goals.has(_node_cell(f, t)):
				return {"next": next, "touched": touched, "complete": false, "found": true}
			if next.size() >= budget:
				return {"next": next, "touched": touched, "complete": false, "found": false}
			next[t] = []
			queue.append(t)
	return {"next": next, "touched": touched, "complete": true, "found": false}


## 나가는 곳(goals)에 (어떤 상태로든) 갈 수 있는 노드 집합(거꾸로 너비 우선 탐색).
static func _returning(f: FloorModel, g: Dictionary, goals: Dictionary) -> Dictionary:
	var next: Dictionary = g["next"]
	var prev := {}
	var queue: Array[int] = []
	var back := {}
	for key in next:
		for t in next[key]:
			if not prev.has(t):
				prev[t] = []
			prev[t].append(key)
		if goals.has(_node_cell(f, key)):
			back[key] = true
			queue.append(key)
	var head := 0
	while head < queue.size():
		var key := queue[head]
		head += 1
		for p in prev.get(key, []):
			if not back.has(p):
				back[p] = true
				queue.append(p)
	return back


## 칸 c 에서 그 경계를 바꿀 수 있는지: 맞닿은 숨은 통로 조사, 열 수 있는 쪽 칸의 지름길.
static func _can_unlock(f: FloorModel, e: Vector3i, c: Vector2i) -> bool:
	if f.edge_kind(e) == FloorModel.Edge.PASSAGE:
		return FloorModel.cells_of_edge(e).has(c)
	return f.shortcut_opener(e) == c


## mask 가 가리키는 세계 상태(찾은 통로·연 지름길). mask 마다 한 번 만들어 둔다.
static func _world_of(f: FloorModel, mask: int, bits: Array[Vector3i], cache: Dictionary) -> WorldState:
	if not cache.has(mask):
		var w := WorldState.new()
		for i in bits.size():
			if mask & (1 << i) != 0:
				if f.edge_kind(bits[i]) == FloorModel.Edge.PASSAGE:
					w.find_passage(bits[i])
				else:
					w.open_shortcut(bits[i])
		cache[mask] = w
	return cache[mask]


static func _node(f: FloorModel, c: Vector2i, mask: int) -> int:
	return mask * f.width * f.height + c.y * f.width + c.x


static func _node_cell(f: FloorModel, key: int) -> Vector2i:
	var i := key % (f.width * f.height)
	return Vector2i(i % f.width, i / f.width)


static func _node_mask(f: FloorModel, key: int) -> int:
	return key / (f.width * f.height)


static func _describe(bits: Array[Vector3i], mask: int) -> String:
	var keys: Array[String] = []
	for i in bits.size():
		if mask & (1 << i) != 0:
			keys.append(GridKey.edge(bits[i]))
	return "바뀐 경계 없음" if keys.is_empty() else "찾거나 연 경계 " + ", ".join(keys)


# ---- 구조 검사 ----

static func _build(ctx: _Ctx, d: Dictionary) -> FloorModel:
	var id := ctx.string_field(d, "id")
	var name_key := ctx.string_field(d, "name_key")
	var theme := ctx.string_field(d, "theme")
	var size := ctx.int_list(d, "size", 2)
	if size.size() != 2 or size[0] < 1 or size[1] < 1 or size[0] > MAX_SIZE or size[1] > MAX_SIZE:
		if size.size() == 2:
			ctx.fail_key("size", "size는 1~%d 사이 양수여야 한다" % MAX_SIZE)
		return null
	var f := FloorModel.new(size[0], size[1])
	f.id = id
	f.name_key = name_key
	f.theme = theme
	if not _read_grid(ctx, d, f):
		return f
	_check_border_and_void(ctx, f)
	_read_shortcuts(ctx, d, f)
	_read_start(ctx, d, f)
	_read_stairs(ctx, d, f)
	_read_encounter(ctx, d, f)
	_read_zones(ctx, d, f)
	_read_damage(ctx, d, f)
	return f


static func _read_grid(ctx: _Ctx, d: Dictionary, f: FloorModel) -> bool:
	if typeof(d.get("grid")) != TYPE_ARRAY:
		ctx.fail_key("grid", "grid는 문자열 배열이어야 한다")
		return false
	var rows: Array = d["grid"]
	var want_rows := 2 * f.height + 1
	var want_cols := 2 * f.width + 1
	if rows.size() != want_rows:
		ctx.fail_key("grid", "grid 줄 수가 %d 이어야 하는데 %d 이다" % [want_rows, rows.size()])
		return false
	var good := true
	for r in rows.size():
		if typeof(rows[r]) != TYPE_STRING:
			ctx.fail_grid(r, 0, "격자 줄이 문자열이 아니다")
			good = false
			continue
		var row: String = rows[r]
		if row.length() != want_cols:
			ctx.fail_grid(r, mini(row.length(), want_cols), "격자 %d줄 길이가 %d 이어야 하는데 %d 이다" % [r, want_cols, row.length()])
			good = false
			continue
		for c in row.length():
			if not _put_char(f, r, c, row[c]):
				ctx.fail_grid(r, c, "격자 %d줄 %d열: 이 자리에 '%s' 를 쓸 수 없다" % [r, c, row[c]])
				good = false
	return good


## 격자 문자 하나를 모델에 넣는다. 그 자리에 허용되지 않는 문자면 false.
static func _put_char(f: FloorModel, r: int, c: int, ch: String) -> bool:
	if r % 2 == 0 and c % 2 == 0:
		return ch == "+"
	if r % 2 == 1 and c % 2 == 1:
		if not CELL_CHARS.has(ch):
			return false
		f.set_cell(Vector2i(c / 2, r / 2), CELL_CHARS[ch])
		return true
	var horizontal := r % 2 == 0
	var table: Dictionary = H_CHARS if horizontal else V_CHARS
	if not table.has(ch):
		return false
	var e := Vector3i(c / 2, r / 2, 0) if horizontal else Vector3i(c / 2, r / 2, 1)
	f.set_edge(e, table[ch], ONEWAY_DIRS.get(ch, -1))
	return true


## 바깥 테두리는 벽, 빈 곳에 맞닿은 경계도 벽.
static func _check_border_and_void(ctx: _Ctx, f: FloorModel) -> void:
	for e in _all_edges(f):
		if f.edge_kind(e) == FloorModel.Edge.WALL:
			continue
		var sides := FloorModel.cells_of_edge(e)
		var r := 2 * e.y if e.z == 0 else 2 * e.y + 1
		var c := 2 * e.x + 1 if e.z == 0 else 2 * e.x
		if not f.in_bounds(sides[0]) or not f.in_bounds(sides[1]):
			ctx.fail_grid(r, c, "격자 %d줄 %d열: 바깥 테두리는 벽이어야 한다" % [r, c])
		elif not f.is_cell(sides[0]) or not f.is_cell(sides[1]):
			ctx.fail_grid(r, c, "격자 %d줄 %d열: 빈 곳(#)에 맞닿은 경계는 벽이어야 한다" % [r, c])


static func _all_edges(f: FloorModel) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for y in f.height + 1:
		for x in f.width:
			out.append(Vector3i(x, y, 0))
	for y in f.height:
		for x in f.width + 1:
			out.append(Vector3i(x, y, 1))
	return out


static func _read_shortcuts(ctx: _Ctx, d: Dictionary, f: FloorModel) -> void:
	var list: Array = []
	if d.has("shortcuts"):
		if typeof(d["shortcuts"]) != TYPE_ARRAY:
			ctx.fail_key("shortcuts", "shortcuts는 배열이어야 한다")
			return
		list = d["shortcuts"]
	for i in list.size():
		var item: Variant = list[i]
		var label := "shortcuts[%d]" % i
		if typeof(item) != TYPE_DICTIONARY:
			ctx.fail_key("shortcuts", "%s 는 객체여야 한다" % label)
			continue
		var at := ctx.cell_value(item.get("at"), "shortcuts", label + ".at")
		var dir := Dir.from_name(item.get("dir"))
		if dir < 0:
			ctx.fail_key("shortcuts", "%s.dir 는 N·E·S·W 중 하나여야 한다" % label)
			continue
		if at == GridKey.BAD_CELL:
			continue
		if not f.in_bounds(at):
			ctx.fail_key("shortcuts", "%s.at 이 층 밖이다" % label)
			continue
		var e := FloorModel.edge_of(at, dir)
		if f.edge_kind(e) != FloorModel.Edge.SHORTCUT:
			ctx.fail_key("shortcuts", "%s 의 경계 %s 가 격자의 L 이 아니다" % [label, GridKey.edge(e)])
		elif f.shortcut_opener(e) != GridKey.BAD_CELL:
			ctx.fail_key("shortcuts", "%s 의 경계 %s 가 중복이다" % [label, GridKey.edge(e)])
		else:
			f.set_shortcut_opener(e, at)
	for e in f.edges_of_kind(FloorModel.Edge.SHORTCUT):
		if f.shortcut_opener(e) == GridKey.BAD_CELL:
			var r := 2 * e.y if e.z == 0 else 2 * e.y + 1
			var c := 2 * e.x + 1 if e.z == 0 else 2 * e.x
			ctx.fail_grid(r, c, "격자 %d줄 %d열: 지름길 문 L 에 맞는 shortcuts 항목이 없다" % [r, c])


## start: 계단이 있는 층은 없어도 된다(GridKey.BAD_CELL). 층 묶음의 첫 층에 있는지는 check_set 이 본다.
static func _read_start(ctx: _Ctx, d: Dictionary, f: FloorModel) -> void:
	if not d.has("start") and typeof(d.get("stairs")) == TYPE_ARRAY and not d["stairs"].is_empty():
		f.start_at = GridKey.BAD_CELL
		return
	if typeof(d.get("start")) != TYPE_DICTIONARY:
		ctx.fail_key("start", "start는 객체여야 한다")
		return
	var s: Dictionary = d["start"]
	var at := ctx.cell_value(s.get("at"), "start", "start.at")
	f.start_facing = Dir.from_name(s.get("facing"))
	if f.start_facing < 0:
		ctx.fail_key("start", "start.facing 은 N·E·S·W 중 하나여야 한다")
	if at == GridKey.BAD_CELL:
		return
	if f.cell_kind(at) != FloorModel.Cell.FLOOR:
		ctx.fail_key("start", "start.at %d:%d 이 바닥 칸(.)이 아니다" % [at.x, at.y])
	f.start_at = at


## 계단(M3 A1): [{"at", "way": up·down, "exit": N·E·S·W, "to": {"floor", "at"}}]. 계단 칸은 바닥(.)이고 칸마다 하나, 시작 칸이 아니다.
## 내려설 칸(at + exit)은 바닥(.)이고 계단이 아니며, 그 사이 경계는 열림·문이다. 짝(to)은 check_set 이 본다.
static func _read_stairs(ctx: _Ctx, d: Dictionary, f: FloorModel) -> void:
	if not d.has("stairs"):
		return
	if typeof(d["stairs"]) != TYPE_ARRAY:
		ctx.fail_key("stairs", "stairs는 배열이어야 한다")
		return
	var id_re := RegEx.create_from_string(FLOOR_ID_PATTERN)
	var list: Array = d["stairs"]
	for i in list.size():
		var item: Variant = list[i]
		var label := "stairs[%d]" % i
		if typeof(item) != TYPE_DICTIONARY:
			ctx.fail_key("stairs", "%s 는 객체여야 한다" % label)
			continue
		var bad := false
		var at := ctx.cell_value(item.get("at"), "stairs", label + ".at")
		var way: Variant = item.get("way")
		if typeof(way) != TYPE_STRING or not STAIR_WAYS.has(way):
			ctx.fail_key("stairs", "%s.way 는 up·down 중 하나여야 한다" % label)
			bad = true
		var exit := Dir.from_name(item.get("exit"))
		if exit < 0:
			ctx.fail_key("stairs", "%s.exit 는 N·E·S·W 중 하나여야 한다" % label)
			bad = true
		var to: Variant = item.get("to")
		var to_at := GridKey.BAD_CELL
		if typeof(to) != TYPE_DICTIONARY or typeof(to.get("floor")) != TYPE_STRING or id_re.search(to["floor"]) == null:
			ctx.fail_key("stairs", "%s.to 는 {\"floor\": 층 ID, \"at\": [x, y]} 이어야 한다" % label)
			bad = true
		else:
			to_at = ctx.cell_value(to.get("at"), "stairs", label + ".to.at")
		if bad or at == GridKey.BAD_CELL or to_at == GridKey.BAD_CELL:
			continue
		var where := "%s %d:%d" % [label, at.x, at.y]
		var step := at + Dir.vec(exit)
		if f.cell_kind(at) != FloorModel.Cell.FLOOR:
			ctx.fail_key("stairs", "%s 이 바닥 칸(.)이 아니다" % where)
		elif f.stairs.has(at):
			ctx.fail_key("stairs", "%s 에 계단이 이미 있다" % where)
		elif f.has_start() and at == f.start_at:
			ctx.fail_key("stairs", "%s 이 시작 칸이다" % where)
		elif f.cell_kind(step) != FloorModel.Cell.FLOOR:
			ctx.fail_key("stairs", "%s 에서 내려설 칸 %d:%d 이 바닥 칸(.)이 아니다" % [where, step.x, step.y])
		elif not (f.edge_kind(FloorModel.edge_of(at, exit)) in [FloorModel.Edge.OPEN, FloorModel.Edge.DOOR]):
			ctx.fail_key("stairs", "%s 과 내려설 칸 사이 경계가 열림·문이 아니다" % where)
		else:
			var st := FloorModel.Stair.new()
			st.at = at
			st.way = way
			st.exit = exit
			st.to_floor = to["floor"]
			st.to_at = to_at
			f.stairs[at] = st
	for st in f.stair_list():
		var step: Vector2i = st.at + Dir.vec(st.exit)
		if f.stairs.has(step):
			ctx.fail_key("stairs", "계단 %d:%d 에서 내려설 칸 %d:%d 이 계단이다" % [st.at.x, st.at.y, step.x, step.y])


static func _read_encounter(ctx: _Ctx, d: Dictionary, f: FloorModel) -> void:
	if typeof(d.get("encounter")) != TYPE_DICTIONARY:
		ctx.fail_key("encounter", "encounter는 객체여야 한다")
		return
	var e: Dictionary = d["encounter"]
	f.danger_per_step = ctx.int_value(e, "danger_per_step", "encounter", 0)
	f.threshold_min = ctx.int_value(e, "threshold_min", "encounter", 1)
	f.threshold_max = ctx.int_value(e, "threshold_max", "encounter", 1)
	if f.threshold_max < f.threshold_min:
		ctx.fail_key("encounter", "threshold_min <= threshold_max 이어야 한다")
	# 출현 표 ID(선택, 06 §8.2). 여기서는 형식만 보고, 표가 있는지는 GameDefs 가 본다.
	if e.has("table"):
		if typeof(e["table"]) != TYPE_STRING or not e["table"].begins_with("encounter.") or RegEx.create_from_string(BattleDb.ID_PATTERN).search(e["table"]) == null:
			ctx.fail_key("encounter", "encounter.table 은 encounter. 로 시작하는 ID 문자열이어야 한다")
		else:
			f.encounter_table = e["table"]


static func _read_zones(ctx: _Ctx, d: Dictionary, f: FloorModel) -> void:
	if not d.has("zones"):
		return
	if typeof(d["zones"]) != TYPE_ARRAY:
		ctx.fail_key("zones", "zones는 배열이어야 한다")
		return
	var list: Array = d["zones"]
	for i in list.size():
		var z: Variant = list[i]
		if typeof(z) != TYPE_DICTIONARY:
			ctx.fail_key("zones", "zones[%d] 는 객체여야 한다" % i)
			continue
		if typeof(z.get("id")) != TYPE_STRING:
			ctx.fail_key("zones", "zones[%d].id 는 문자열이어야 한다" % i)
		var rect := ctx.coords(z.get("rect"), 4, "zones", "zones[%d].rect" % i)
		var danger := ctx.int_value(z, "danger_per_step", "zones", 0)
		if rect.size() != 4:
			continue
		var lo := Vector2i(rect[0], rect[1])
		var hi := Vector2i(rect[2], rect[3])
		if not f.in_bounds(lo) or not f.in_bounds(hi) or hi.x < lo.x or hi.y < lo.y:
			ctx.fail_key("zones", "zones[%d].rect 가 층 범위를 벗어나거나 뒤집혔다" % i)
			continue
		f.zones.append({"id": str(z.get("id")), "rect": Rect2i(lo, hi - lo + Vector2i.ONE), "danger_per_step": danger})


static func _read_damage(ctx: _Ctx, d: Dictionary, f: FloorModel) -> void:
	if not d.has("damage_floor"):
		for c in f.cells():
			if f.cell_kind(c) == FloorModel.Cell.DAMAGE:
				ctx.fail_key("grid", "피해 바닥(~)이 있는데 damage_floor 가 없다")
				return
		return
	if typeof(d["damage_floor"]) != TYPE_DICTIONARY:
		ctx.fail_key("damage_floor", "damage_floor는 객체여야 한다")
		return
	f.damage = ctx.int_value(d["damage_floor"], "damage", "damage_floor", 0)


## 오류 모음과 원문 위치 찾기.
class _Ctx:
	extends RefCounted
	var text := ""
	var source := ""
	var result := Result.new()
	var _grid_rows: Array[int] = []  # 격자 각 원소가 시작하는 원문 위치(문자열이면 따옴표 다음)
	var _grid_exact: Array[bool] = []  # 이스케이프 없는 문자열이라 열 위치를 그대로 셀 수 있는지
	var _grid_scanned := false

	func _init(t: String, s: String) -> void:
		text = t
		source = s

	func fail_at_line(line: int, col: int, msg: String) -> void:
		result.errors.append("%s:%d:%d: %s" % [source, line, col, msg])

	func fail_at_offset(offset: int, msg: String) -> void:
		var lc := _line_col(offset)
		fail_at_line(lc.x, lc.y, msg)

	## 맨 위 객체의 키 name 위치. 없으면 문서 처음.
	func fail_key(name: String, msg: String) -> void:
		fail_at_offset(maxi(_top_key(name).x, 0), msg)

	## 맨 위 객체를 키·값 단위로 걸어 키 name(이스케이프를 푼 값)의 (키 위치, 값 위치). 없으면 (-1, -1).
	## 같은 키가 여러 번이면 JSON 파서처럼 마지막 것.
	func _top_key(name: String) -> Vector2i:
		var found := Vector2i(-1, -1)
		var i := _skip_space(0)
		if i >= text.length() or text[i] != "{":
			return found
		i += 1
		while true:
			i = _skip_space(i)
			if i >= text.length() or text[i] != "\"":
				return found
			var end := _string_end(i)
			var key: Variant = JSON.parse_string(text.substr(i, end - i + 1))
			var at := i
			i = _skip_space(end + 1)
			if i >= text.length() or text[i] != ":":
				return found
			i = _skip_space(i + 1)
			if key is String and key == name:
				found = Vector2i(at, i)
			i = _skip_space(_value_end(i))
			if i >= text.length() or text[i] != ",":
				return found
			i += 1
		return found

	## 격자 r줄 c열 문자의 원문 위치. 그 줄에 이스케이프가 있거나 문자열이 아니면 줄 시작 위치.
	func fail_grid(r: int, c: int, msg: String) -> void:
		if not _grid_scanned:
			_scan_grid_rows()
		if r < _grid_rows.size():
			fail_at_offset(_grid_rows[r] + (c if _grid_exact[r] else 0), msg)
		else:
			fail_key("grid", msg)

	func _line_col(offset: int) -> Vector2i:
		var line := 1
		var col := 1
		for i in mini(offset, text.length()):
			if text[i] == "\n":
				line += 1
				col = 1
			else:
				col += 1
		return Vector2i(line, col)

	## 맨 위 "grid" 키 값 배열의 원소마다 시작 위치와 열을 그대로 셀 수 있는지 모은다.
	func _scan_grid_rows() -> void:
		_grid_scanned = true
		var i := _top_key("grid").y
		if i < 0 or i >= text.length() or text[i] != "[":
			return
		i += 1
		while i < text.length():
			i = _skip_space(i)
			if i >= text.length() or text[i] == "]":
				return
			if text[i] == "\"":
				var end := _string_end(i)
				_grid_rows.append(i + 1)
				_grid_exact.append(not text.substr(i + 1, end - i - 1).contains("\\"))
				i = end + 1
			else:
				_grid_rows.append(i)
				_grid_exact.append(false)
				i = _value_end(i)
			i = _skip_space(i)
			if i < text.length() and text[i] == ",":
				i += 1

	func _skip_space(i: int) -> int:
		while i < text.length() and text[i] in [" ", "\t", "\n", "\r"]:
			i += 1
		return i

	## i 의 따옴표로 시작한 문자열을 닫는 따옴표 위치.
	func _string_end(i: int) -> int:
		i += 1
		while i < text.length() and text[i] != "\"":
			i += 2 if text[i] == "\\" else 1
		return i

	## i 에서 시작한 값(문자열·숫자·배열·객체 등)이 끝난 다음 위치(같은 깊이의 , ] } 또는 원문 끝).
	func _value_end(i: int) -> int:
		var depth := 0
		while i < text.length():
			var ch := text[i]
			if ch == "\"":
				i = _string_end(i)
			elif ch == "[" or ch == "{":
				depth += 1
			elif ch == "]" or ch == "}":
				if depth == 0:
					return i
				depth -= 1
			elif ch == "," and depth == 0:
				return i
			i += 1
		return i

	func string_field(d: Dictionary, key: String) -> String:
		if typeof(d.get(key)) != TYPE_STRING or str(d[key]).is_empty():
			fail_key(key, "%s 는 빈 문자열이 아닌 문자열이어야 한다" % key)
			return ""
		return d[key]

	## d[key]의 0 이상 정수. 없거나 소수·불리언이면 오류를 남기고 fallback.
	func int_value(d: Dictionary, key: String, anchor: String, fallback: int) -> int:
		var v: Variant = SaveCodec.to_int(d.get(key))
		if v == null:
			fail_key(anchor, "%s 는 정수여야 한다" % key)
			return fallback
		if key.begins_with("threshold") and v < 1:
			fail_key(anchor, "%s 는 1 이상이어야 한다" % key)
			return fallback
		if v < 0:
			fail_key(anchor, "%s 는 0 이상이어야 한다" % key)
			return fallback
		return v

	func int_list(d: Dictionary, key: String, n: int) -> Array[int]:
		return int_array(d.get(key), n, key, key)

	func int_array(v: Variant, n: int, anchor: String, label: String) -> Array[int]:
		var out: Array[int] = []
		if typeof(v) != TYPE_ARRAY or v.size() != n:
			fail_key(anchor, "%s 는 정수 %d개 배열이어야 한다" % [label, n])
			return out
		for x in v:
			var i: Variant = SaveCodec.to_int(x)
			if i == null:
				fail_key(anchor, "%s 에 정수가 아닌 값이 있다" % label)
				return [] as Array[int]
			out.append(i)
		return out

	## [x, y] → 칸. 정수 그대로 0~MAX_SIZE 범위를 본 뒤에 Vector2i 로 바꾼다(32비트로 잘리지 않게).
	func cell_value(v: Variant, anchor: String, label: String) -> Vector2i:
		var a := coords(v, 2, anchor, label)
		if a.size() != 2:
			return GridKey.BAD_CELL
		return Vector2i(a[0], a[1])

	## 좌표 정수 n개. 하나라도 0~MAX_SIZE 밖이면 오류를 남기고 빈 배열.
	func coords(v: Variant, n: int, anchor: String, label: String) -> Array[int]:
		var a := int_array(v, n, anchor, label)
		for x in a:
			if x < 0 or x > MAX_SIZE:
				fail_key(anchor, "%s 의 좌표 %d 가 층 범위를 벗어났다" % [label, x])
				return [] as Array[int]
		return a
