## M0 확인용 장면: 격자 복도 한 줄과 한글 표시. 웹 내보내기·렌더러·글꼴 확인에 쓴다.
extends Node3D

const CELL := 2.0
const LENGTH := 6


func _ready() -> void:
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.08, 0.09, 0.12)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.2, 0.9, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.2, 0.9, 1.0)
	glow.emission_energy_multiplier = 2.0

	for i in LENGTH:
		var z := -i * CELL
		_add_box(Vector3(0, -0.05, z), Vector3(CELL, 0.1, CELL), wall)
		_add_box(Vector3(0, CELL + 0.05, z), Vector3(CELL, 0.1, CELL), wall)
		_add_box(Vector3(-CELL / 2 - 0.05, CELL / 2, z), Vector3(0.1, CELL, CELL), wall)
		_add_box(Vector3(CELL / 2 + 0.05, CELL / 2, z), Vector3(0.1, CELL, CELL), wall)
		_add_box(Vector3(-CELL / 2 + 0.01, 0.2, z), Vector3(0.02, 0.04, CELL * 0.9), glow)
		_add_box(Vector3(CELL / 2 - 0.01, 0.2, z), Vector3(0.02, 0.04, CELL * 0.9), glow)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, CELL / 2)
	cam.fov = 75
	add_child(cam)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.01, 0.01, 0.02)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.8)
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color(0.02, 0.05, 0.08)
	env.environment.fog_density = 0.08
	add_child(env)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.6, 0)
	light.omni_range = 8.0
	light.light_color = Color(0.7, 0.9, 1.0)
	add_child(light)

	var ui := CanvasLayer.new()
	var label := Label.new()
	label.text = "아보르 프로토콜 — M0 기반 확인"
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 28)
	ui.add_child(label)
	add_child(ui)


func _add_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	add_child(inst)
