extends Node2D
## drill-guard 런 컨트롤러 — 그레이박스 1주차.
## 루프: 파견 준비(용병 배치) → 방어(배터리 카운트다운, 채굴) → 결과/업그레이드 → 재파견.
## 헌법 4조: ①드릴=지킬것=돈줄=시계(파괴돼도 채굴량 유지) ②커서 반경 자동 공격(위치가 전부)
##   ③용병 자동 전투(사전 배치 + 전사 시 재배치 버튼) ④성장은 런 사이 수식 업그레이드뿐.
## 충돌 전부 수동 거리 판정(물리엔진 미사용 — helldiver-lite 그레이박스 결).

enum Phase { PREP, DEFEND, RESULT }

const DRILL_POS := Vector2(320, 186)
const DRILL_CONTACT := 34.0
const MERC_ENGAGE := 70.0  # 적이 드릴 대신 용병을 무는 어그로 거리
const MERC_CONTACT := 16.0
const CURSOR_TICK := 0.12
const REDEPLOY_DELAY := 2.0  # 전사 → 예비 복귀 딜레이

const UPG := {
	"mine": {"name": "채굴 속도", "cost": 20, "mult": 1.6},
	"battery": {"name": "배터리 +5s", "cost": 30, "mult": 1.7},
	"drill_hp": {"name": "드릴 장갑", "cost": 25, "mult": 1.5},
	"cursor_dmg": {"name": "커서 화력", "cost": 25, "mult": 1.6},
	"cursor_rad": {"name": "커서 반경", "cost": 40, "mult": 1.8},
	"merc_dmg": {"name": "용병 화력", "cost": 25, "mult": 1.6},
	"merc_hp": {"name": "용병 체력", "cost": 20, "mult": 1.5},
	"merc_count": {"name": "용병 +1", "cost": 80, "mult": 2.2},
}
const MERC_COUNT_MAX := 4  # merc_count 레벨 상한 (기본 2 + 4 = 총 6)
const SAVE_PATH := "user://drill-guard.cfg"

var phase: Phase = Phase.PREP
var lvl := {}
var ore_bank := 0
var ore_run := 0.0
var run_count := 0
var battery := 30.0
var drill_hp := 100.0
var enemies: Array = []
var mercs: Array = []
var reserve := 0  # 미배치 + 복귀 대기 끝난 용병
var placing := false  # DEFEND 중 재배치 모드
var tracers: Array = []  # [{a, b, t}]
var spin := 0.0  # 커서 오라 회전 연출
var rng := RandomNumberGenerator.new()

var world: Node2D
var fx: Node2D

var _pending: Array = []  # 복귀 대기 타이머들
var _spawn_t := 0.0
var _cursor_t := 0.0
var _hit_cd := 0.0  # 드릴 피격 연출 스로틀
var _t := 0.0  # 방어 경과 시간

var _ore_l: Label
var _run_l: Label
var _hint_l: Label
var _redeploy_btn: Button
var _shop_layer: CanvasLayer
var _shop_title: Label
var _shop_btns := {}


func _ready() -> void:
	rng.randomize()
	world = Node2D.new()
	add_child(world)
	Juice.bind(world)
	fx = load("res://scripts/Fx.gd").new()
	fx.run = self
	world.add_child(fx)
	_load()
	_build_hud()
	_build_shop()
	_enter_prep()


func _process(delta: float) -> void:
	spin += delta * 1.2
	for tr in tracers:
		tr["t"] += delta
	tracers = tracers.filter(func(tr): return tr["t"] < 0.12)
	if phase == Phase.DEFEND:
		_tick_defend(delta)
	fx.queue_redraw()
	_update_hud()


# ---------- 파생 스탯 (성장은 전부 이 수식들) ----------

func mining_rate() -> float:
	return 2.0 + lvl.get("mine", 0) * 1.0


func battery_max() -> float:
	return 30.0 + lvl.get("battery", 0) * 5.0


func drill_hp_max() -> float:
	return 100.0 + lvl.get("drill_hp", 0) * 25.0


func cursor_dps() -> float:
	return 8.0 + lvl.get("cursor_dmg", 0) * 4.0


func cursor_radius() -> float:
	return 52.0 + lvl.get("cursor_rad", 0) * 8.0


func merc_dmg() -> float:
	return 3.0 + lvl.get("merc_dmg", 0) * 1.5


func merc_hp_max() -> float:
	return 30.0 + lvl.get("merc_hp", 0) * 12.0


func merc_total() -> int:
	return 2 + lvl.get("merc_count", 0)


# ---------- 페이즈 ----------

func _enter_prep() -> void:
	phase = Phase.PREP
	for e in enemies:
		e.queue_free()
	enemies.clear()
	for m in mercs:
		m.queue_free()
	mercs.clear()
	_pending.clear()
	tracers.clear()
	battery = battery_max()
	drill_hp = drill_hp_max()
	ore_run = 0.0
	reserve = merc_total()
	placing = false
	_t = 0.0
	_spawn_t = 0.6
	_shop_layer.visible = false
	Juice.reset()


func _start_defend() -> void:
	run_count += 1
	phase = Phase.DEFEND
	Sfx.play("ui")
	Juice.popup("드릴 가동 — 배터리 %ds" % int(battery), DRILL_POS + Vector2(-56, -50), Color(0.5, 0.9, 1.0), 13)


func _tick_defend(delta: float) -> void:
	_t += delta
	battery -= delta
	ore_run += mining_rate() * delta
	_hit_cd -= delta
	# 전사 용병 복귀 대기
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i] -= delta
		if _pending[i] <= 0.0:
			_pending.remove_at(i)
			reserve += 1
			Sfx.play("ui", 1.2)
	# 스폰 (시간·파견 횟수에 따라 가속)
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_enemy()
		_spawn_t = maxf(0.35, 1.3 - _t * 0.03 - run_count * 0.015)
	# 커서 오라 — 반경 내 자동 공격
	_cursor_t -= delta
	if _cursor_t <= 0.0:
		_cursor_t = CURSOR_TICK
		var mp := get_global_mouse_position()
		var dmg := cursor_dps() * CURSOR_TICK
		for e in enemies.duplicate():
			if e.position.distance_to(mp) <= cursor_radius():
				e.take(dmg)
	if battery <= 0.0:
		_end_run(true)


func _end_run(survived: bool) -> void:
	phase = Phase.RESULT
	placing = false
	ore_bank += int(ore_run)  # 헌법 1조 — 드릴이 터져도 캔 만큼은 회수
	Sfx.play("end" if survived else "hit")
	if not survived:
		Juice.shake(10.0)
		Juice.debris(DRILL_POS, Color(0.95, 0.6, 0.2), 30)
	_save()
	_show_shop(survived)


# ---------- 스폰/전투 콜백 ----------

func _spawn_enemy() -> void:
	var pos: Vector2
	match rng.randi_range(0, 3):
		0: pos = Vector2(rng.randf_range(0, 640), -12)
		1: pos = Vector2(652, rng.randf_range(0, 360))
		2: pos = Vector2(rng.randf_range(0, 640), 372)
		_: pos = Vector2(-12, rng.randf_range(0, 360))
	var e: Node2D = load("res://scripts/Enemy.gd").new()
	e.run = self
	e.position = pos
	e.max_hp = 6.0 + _t * 0.25 + run_count * 1.5
	e.hp = e.max_hp
	e.speed = rng.randf_range(38.0, 55.0)
	e.ore = 1 + int(_t / 10.0)
	world.add_child(e)
	enemies.append(e)


## 적의 표적 — MERC_ENGAGE 내 최근접 용병, 없으면 null(=드릴).
func enemy_target(e: Node2D) -> Node2D:
	var best: Node2D = null
	var bd := MERC_ENGAGE
	for m in mercs:
		var d: float = e.position.distance_to(m.position)
		if d < bd:
			bd = d
			best = m
	return best


func on_enemy_dead(e: Node2D) -> void:
	enemies.erase(e)
	ore_run += e.ore
	Sfx.play("kill", rng.randf_range(0.9, 1.15))
	Juice.debris(e.position, Color(0.9, 0.45, 0.3), 6)
	Juice.popup("+%d" % e.ore, e.position + Vector2(-6, -10), Color(1.0, 0.8, 0.35), 12)
	e.queue_free()


func on_merc_dead(m: Node2D) -> void:
	mercs.erase(m)
	Juice.debris(m.position, Color(0.4, 0.8, 0.9), 8)
	Juice.popup("용병 전사", m.position + Vector2(-18, -12), Color(0.6, 0.85, 0.95), 11)
	Sfx.play("hit", 1.4)
	_pending.append(REDEPLOY_DELAY)
	m.queue_free()


func damage_drill(d: float) -> void:
	if phase != Phase.DEFEND:
		return
	drill_hp -= d
	if _hit_cd <= 0.0:
		_hit_cd = 0.5
		Sfx.play("hit")
		Juice.shake(2.5)
	if drill_hp <= 0.0:
		_end_run(false)


func add_tracer(a: Vector2, b: Vector2) -> void:
	tracers.append({"a": a, "b": b, "t": 0.0})


# ---------- 배치 ----------

func _place_merc(pos: Vector2) -> void:
	if reserve <= 0:
		return
	if pos.distance_to(DRILL_POS) < DRILL_CONTACT:
		return  # 드릴 위에는 못 세움
	var m: Node2D = load("res://scripts/Merc.gd").new()
	m.run = self
	m.position = pos
	m.max_hp = merc_hp_max()
	m.hp = m.max_hp
	world.add_child(m)
	mercs.append(m)
	reserve -= 1
	Sfx.play("ui", 0.9)
	if placing and reserve <= 0:
		placing = false


# ---------- HUD/상점 ----------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var dim := Color(0.62, 0.6, 0.7)
	_ore_l = _mk_label("", Vector2(12, 8), 14, Color(1.0, 0.8, 0.35), layer)
	_run_l = _mk_label("", Vector2(556, 8), 12, dim, layer)
	_hint_l = _mk_label("", Vector2(12, 336), 12, Color(0.85, 0.85, 0.9), layer)
	_redeploy_btn = Button.new()
	_redeploy_btn.text = "재배치 (B)"
	_redeploy_btn.position = Vector2(540, 326)
	_redeploy_btn.focus_mode = Control.FOCUS_NONE
	_redeploy_btn.pressed.connect(_toggle_placing)
	layer.add_child(_redeploy_btn)


func _build_shop() -> void:
	_shop_layer = CanvasLayer.new()
	add_child(_shop_layer)
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.05, 0.08, 0.94)
	panel.position = Vector2(168, 10)
	panel.size = Vector2(304, 340)
	_shop_layer.add_child(panel)
	_shop_title = _mk_label("", Vector2(184, 20), 13, Color(1.0, 0.8, 0.35), _shop_layer)
	var box := VBoxContainer.new()
	box.position = Vector2(184, 66)
	box.add_theme_constant_override("separation", 4)
	_shop_layer.add_child(box)
	for key in UPG:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_buy.bind(key))
		box.add_child(b)
		_shop_btns[key] = b
	var go := Button.new()
	go.text = "재파견 (Enter)"
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(_enter_prep)
	box.add_child(go)
	_shop_layer.visible = false


func _mk_label(text: String, pos: Vector2, size: int, col: Color, layer: CanvasLayer) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	layer.add_child(l)
	return l


func upg_cost(key: String) -> int:
	return int(UPG[key]["cost"] * pow(UPG[key]["mult"], lvl.get(key, 0)))


func _buy(key: String) -> void:
	if key == "merc_count" and lvl.get(key, 0) >= MERC_COUNT_MAX:
		return
	var cost := upg_cost(key)
	if ore_bank < cost:
		Sfx.play("empty")
		return
	ore_bank -= cost
	lvl[key] = lvl.get(key, 0) + 1
	Sfx.play("ui")
	_save()
	_refresh_shop()


func _show_shop(survived: bool) -> void:
	var outcome := "배터리 소진 — 파견 완료" if survived else "드릴 파괴 — 그래도 캔 건 회수"
	_shop_title.text = "파견 %d 종료: %s\n채굴 +%d → 보유 광물 %d" % [run_count, outcome, int(ore_run), ore_bank]
	_refresh_shop()
	_shop_layer.visible = true


func _refresh_shop() -> void:
	for key in _shop_btns:
		var b: Button = _shop_btns[key]
		var l: int = lvl.get(key, 0)
		if key == "merc_count" and l >= MERC_COUNT_MAX:
			b.text = "%s Lv%d — MAX" % [UPG[key]["name"], l]
		else:
			b.text = "%s Lv%d — %d 광물" % [UPG[key]["name"], l, upg_cost(key)]
	_shop_title.text = _shop_title.text.substr(0, _shop_title.text.find("\n") + 1) + "채굴 +%d → 보유 광물 %d" % [int(ore_run), ore_bank]


func _update_hud() -> void:
	_ore_l.text = "광물 %d" % ore_bank if phase != Phase.DEFEND else "광물 %d  (채굴 +%d)" % [ore_bank, int(ore_run)]
	_run_l.text = "파견 %d" % run_count
	_redeploy_btn.visible = phase == Phase.DEFEND and reserve > 0
	match phase:
		Phase.PREP:
			_hint_l.text = "파견 준비 — 클릭: 용병 배치 (남음 %d) · Enter: 파견 시작" % reserve
		Phase.DEFEND:
			if placing:
				_hint_l.text = "재배치 — 클릭한 곳에 용병 투입 (예비 %d)" % reserve
			elif reserve > 0:
				_hint_l.text = "예비 용병 %d — B: 재배치" % reserve
			else:
				_hint_l.text = ""
		Phase.RESULT:
			_hint_l.text = ""


func _toggle_placing() -> void:
	if phase != Phase.DEFEND or reserve <= 0:
		return
	placing = not placing


# ---------- 입력 ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if phase == Phase.PREP:
			_place_merc(event.position)
		elif phase == Phase.DEFEND and placing:
			_place_merc(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				if phase == Phase.PREP:
					_start_defend()
				elif phase == Phase.RESULT:
					_enter_prep()
			KEY_B:
				_toggle_placing()


# ---------- 저장 (인크리멘탈 = 영구 성장이 몸통) ----------

func _save() -> void:
	var c := ConfigFile.new()
	c.set_value("meta", "ore", ore_bank)
	c.set_value("meta", "runs", run_count)
	for key in UPG:
		c.set_value("lvl", key, lvl.get(key, 0))
	c.save(SAVE_PATH)


func _load() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return
	ore_bank = c.get_value("meta", "ore", 0)
	run_count = c.get_value("meta", "runs", 0)
	for key in UPG:
		lvl[key] = c.get_value("lvl", key, 0)
