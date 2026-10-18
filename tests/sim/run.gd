## 전투 시뮬레이션 실행기(06 §7.1). 쓰는 법:
##   timeout 1800 godot --headless -s tests/sim/run.gd -- --size probe|small|large [--seed N] [--out build/sim/report.json] [--save-check N]
## 종료 코드(SimLib.exit_code): 0 통과, 2 설정·계획·실행(명령 거부·시작 실패)·불변 조건·보고서 쓰기 오류. 밸런스 판정과 제출 상한
## 도달(교착) 관측은 참고라(D15) 범위 밖·계산 불가·상한 도달이어도 0 이고, 판정 표·요약 줄·보고서(참고 판정의 checks[].note)에
## 「참고: 범위 밖」·「참고: 계산 불가」·「참고: 제출 상한 도달」로 적는다. probe 에는 밸런스 판정이 없다.
## 마지막 줄은 「SIM 요약: …」 한 줄.
extends SceneTree

const SimLib := preload("res://tests/sim/sim_lib.gd")


func _init() -> void:
	var args := _args()
	if args.has("error"):
		print("SIM 요약: 실패 — 인자 오류: %s" % args["error"])
		quit(2)
		return
	var lib := SimLib.new()
	if not lib.load_all():
		for e in lib.errors:
			printerr(e)
		print("SIM 요약: 실패 — 정의·설정 오류 %d건" % lib.errors.size())
		quit(2)
		return
	if not lib.config["sizes"].has(args["size"]):
		print("SIM 요약: 실패 — 모르는 크기 %s" % args["size"])
		quit(2)
		return
	var plan := lib.plan_of(args["size"], args.get("seed", -1))
	if args.has("save_check"):
		plan["save_check_games"] = args["save_check"]
	var perr := lib.check_plan(plan)
	if not perr.is_empty():
		for e in perr:
			printerr(e)
		print("SIM 요약: 실패 — 계획 오류 %d건" % perr.size())
		quit(2)
		return
	var t0 := Time.get_ticks_usec()
	var report := lib.run(plan)
	var elapsed := (Time.get_ticks_usec() - t0) / 1_000_000.0
	report["commit"] = _commit()
	report["godot_version"] = Engine.get_version_info()["string"]
	report["machine"] = "%s %s, %d코어" % [OS.get_name(), Engine.get_architecture_name(), OS.get_processor_count()]
	report["elapsed_sec"] = snappedf(elapsed, 0.01)
	var fought: int = report["games"] + report["battles_in_chains"]
	report["sec_per_battle"] = elapsed / maxi(1, fought)
	report["vm_hwm_kb"] = _vm_hwm_kb()
	report["static_memory_peak"] = OS.get_static_memory_peak_usage()
	var out_path: String = args.get("out", "build/sim/report.json")
	var abs_path := out_path if out_path.is_absolute_path() else ProjectSettings.globalize_path("res://" + out_path)
	var write_error := SimLib.write_report(report, abs_path)
	if not write_error.is_empty():
		printerr(write_error)
	_print_tables(report)
	var code := SimLib.exit_code(report, write_error)
	var exec_fail := 0
	var exec_total := 0
	var ref_total := 0
	var ref_notes := {}
	for c in report["checks"]:
		if c["kind"] == "exec":
			exec_total += 1
			if not c["pass"]:
				exec_fail += 1
		else:
			ref_total += 1
			if not c["pass"]:
				ref_notes[c["note"]] = ref_notes.get(c["note"], 0) + 1
	var balance_note := ""
	if not ref_notes.is_empty():
		var keys: Array = ref_notes.keys()
		keys.sort()
		for k in keys:
			balance_note += ", %s %d/%d" % [k, ref_notes[k], ref_total]
	elif ref_total > 0:
		balance_note = ", 참고 판정 %d건 모두 범위 안" % ref_total
	var errs := 0
	var stalled := 0
	for c in report["cells"]:
		errs += c["outcomes"]["error"]
		stalled += c["outcomes"]["stalled"]
	for ch in report["chains"]:
		errs += ch["codes"]["error"]
		stalled += ch["codes"]["stalled"]
	var w: Dictionary = report["weighted"]
	var max_wipe := 0.0
	for c in report["cells"]:
		if c["policy"] == "default":
			max_wipe = maxf(max_wipe, c["wipe_rate"])
	var median := "—"
	for ch in report["chains"]:
		if ch["party"] == "P1":
			median = str(ch["median_L"])
	var turns := []
	for p in ["P1", "P2", "P3"]:
		if w.has(p + "/default"):
			turns.append("%s %.2f" % [p, w[p + "/default"]])
	print("측정: 전투 %d(단일 %d + 연전 안 %d), 판당 %.2f ms, VmHWM %d KB, 정적 최대 %d B" % [fought, report["games"], report["battles_in_chains"],
		report["sec_per_battle"] * 1000.0, report["vm_hwm_kb"], report["static_memory_peak"]])
	var verdict := "통과" if code == 0 else "실패(실행 오류)"
	print("SIM 요약: %s %d/%d%s — 기본 %s턴, 최대 전멸률 %.1f%%, L 중앙값 %s, 교착 %d, 오류 %d, 해시 %s, 설정 %s, 정의 %s, %.1f초%s" % [
		verdict, exec_total - exec_fail, exec_total, balance_note, " ".join(turns), max_wipe * 100.0, median, stalled, errs,
		report["result_hash"], report["config_hash"], report["data_hash"], elapsed, ", 보고서 쓰기 실패" if not write_error.is_empty() else ""])
	quit(code)


func _args() -> Dictionary:
	var out := {"size": "small"}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var k := a[i]
		var v := a[i + 1] if i + 1 < a.size() else ""
		match k:
			"--size":
				out["size"] = v
			"--seed":
				if not v.is_valid_int():
					return {"error": "--seed 는 정수"}
				out["seed"] = v.to_int()
			"--out":
				out["out"] = v
			"--save-check":
				if not v.is_valid_int():
					return {"error": "--save-check 는 정수"}
				out["save_check"] = v.to_int()
			_:
				return {"error": "모르는 인자 %s" % k}
		i += 2
	return out


func _commit() -> String:
	var out := []
	if OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], out) != 0 or out.is_empty():
		return "unknown"
	var c := str(out[0]).strip_edges()
	out.clear()
	if OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain", "--", "src", "data", "tests"], out) == 0 and not str(out[0]).strip_edges().is_empty():
		c += "-dirty"
	return c


static func _vm_hwm_kb() -> int:
	# /proc 파일은 크기가 0 으로 보여 한 줄씩 읽는다.
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return -1
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("VmHWM:"):
			return line.trim_prefix("VmHWM:").strip_edges().trim_suffix("kB").strip_edges().to_int()
	return -1


func _print_tables(r: Dictionary) -> void:
	print("| 칸 | 파티 | 편성 | 정책 | 판 | 승 | 전멸 | 교착 | 오류 | 평균 턴 | 승리 평균 | 중앙값 | 전멸률 | TP | 받은 피해 | 순손실 |")
	print("|---:|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	for c in r["cells"]:
		var o: Dictionary = c["outcomes"]
		print("| %d | %s | %s | %s | %d | %d | %d | %d | %d | %.2f | %.2f | %d | %.1f%% | %.1f | %.1f | %.1f |" % [c["cell"], c["party"], c["formation"].trim_prefix("formation."),
			c["policy"], c["games"], o["victory"], o["wiped"], o["stalled"], o["error"], c["avg_turns"], c["avg_turns_victory"], c["median_turns"],
			c["wipe_rate"] * 100.0, c["avg_tp"], c["avg_damage"], c["avg_net_loss"]])
	print("")
	print("| 가중 평균 턴 | 값 |")
	print("|---|---:|")
	var keys: Array = r["weighted"].keys()
	keys.sort()
	for k in keys:
		print("| %s | %.2f |" % [k, r["weighted"][k]])
	print("")
	print("| 연전 | 판 | 센 판 | L 중앙값 | 평균 | 10분위 | 최소~최대 | 전멸·상한·교착·오류 | 전투 수 | 전투당 TP | 전투당 받은 피해 |")
	print("|---|---:|---:|---:|---:|---|---|---|---:|---:|---:|")
	for ch in r["chains"]:
		var cd: Dictionary = ch["codes"]
		print("| %s | %d | %d | %d | %.2f | %s | %d~%d | %d·%d·%d·%d | %d | %.1f | %.1f |" % [ch["party"], ch["chains"], ch["counted"], ch["median_L"], ch["mean_L"],
			str(ch["deciles"]), ch["min_L"], ch["max_L"], cd["wiped"], cd["cap"], cd["stalled"], cd["error"], ch["battles"], ch["avg_tp_per_battle"], ch["avg_damage_per_battle"]])
	print("")
	print("| 판정 | 종류 | 값 | 범위 | 통과 | 종료 코드에 씀 |")
	print("|---|---|---|---|---|---|")
	for c in r["checks"]:
		var is_exec: bool = c["kind"] == "exec"
		var passed: String = "예" if c["pass"] else ("아니오" if is_exec else str(c["note"]))
		var kind: String = {"exec": "실행", "observed": "관측", "balance": "밸런스"}.get(c["kind"], str(c["kind"]))
		print("| %s | %s | %s | %s | %s%s | %s |" % [c["name"], kind, str(c["value"]), c["range"], passed,
			" (경계)" if c.get("border", false) else "", "2" if is_exec else "참고"])
	print("")
	print("스킬 사용(정책별): %s" % JSON.stringify(r["skill_use"], "", true))
	if r["save_error_count"] > 0:
		print("저장 왕복 실패 %d건: %s" % [r["save_error_count"], str(r["save_errors"])])
