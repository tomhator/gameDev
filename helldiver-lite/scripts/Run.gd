extends Node2D
## helldiver-lite 런 컨트롤러 — 그레이박스 1주차.
## 루프: 강하 → 탐험 → 순찰 조우(피하거나/조지거나) → 목표(송신기 파괴, E 채널)
##   → 탈출 신호(E) → 셔틀 카운트다운 버티기 → 탑승 = 생환.
## 택티컬 = 규칙 3개뿐: ①총성=어그로(Player.NOISE_RADIUS) ②한정 탄약 ③탈출 카운트다운.
## 충돌·시야 전부 수동 거리 판정(물리엔진·타일맵 없음 — 그레이박스 결).

enum Phase { EXPLORE, EVAC_WAIT, DONE }

const MAP_RECT := Rect2(0, 0, 1600, 1200)
const DROP_POS := Vector2(140, 1060)  # 강하 지점(남서) — 시작 주변은 비전투(스캐빈저 INV-17 교훈)
const SAFE_RADIUS := 320.0  # 강하 지점 주변 순찰대 배치 금지 반경
const SQUAD_COUNT := 5
const OBJECTIVE_CHANNEL := 2.0  # 목표 상호작용(E 홀드) 시간
const EVAC_DURATION := 60.0  # 셔틀 도착까지 버티기
const PAD_RADIUS := 22.0

var phase: Phase = Phase.EXPLORE
var player: Player
var enemies: Array = []
var world: Node2D
var rng := RandomNumberGenerator.new()

var props: Array = []  # [{pos: Vector2, r: float}] — 원형 장애물(바위)
var ammo_drops: Array = []  # [Vector2]
var objective_pos: Vector2
var objective_progress: float = 0.0  # 0~1
var objective_done: bool = false
var evac_pos: Vector2
var evac_t: float = 0.0
var shuttle_here: bool = false
var _wave_t: float = 0.0
var _wave_interval: float = 8.0
var _win: bool = false
var _e_prev: bool = false

var _hud_status: Label
var _hud_mission: Label
var _hud_msg: Label


func _ready() -> void:
	rng.randomize()
	world = Node2D.new()
	add_child(world)
	Juice.bind(world)
	var ground: Node2D = load("res://scripts/Ground.gd").new()
	ground.run = self
	world.add_child(ground)
	_gen_map()
	_spawn_player()
	_spawn_squads()
	_build_hud()
	Juice.popup("강하 완료 — 송신기를 파괴하라", DROP_POS + Vector2(-60, -40), Color(0.7, 1, 0.8), 12)


func _gen_map() -> void:
	# 목표(북동 사분면) / 탈출 패드(북서·남동 중 택1) — 강하 지점에서 멀리.
	objective_pos = Vector2(rng.randf_range(1100, 1480), rng.randf_range(140, 500))
	var pads := [Vector2(rng.randf_range(140, 420), rng.randf_range(140, 420)),
		Vector2(rng.randf_range(1180, 1460), rng.randf_range(800, 1060))]
	evac_pos = pads[rng.randi() % 2]
	# 원형 장애물 — 특수 지점 주변은 비움.
	for i in 18:
		var p := Vector2(
			rng.randf_range(80, MAP_RECT.size.x - 80), rng.randf_range(80, MAP_RECT.size.y - 80)
		)
		if (
			p.distance_to(DROP_POS) < 120.0
			or p.distance_to(objective_pos) < 100.0
			or p.distance_to(evac_pos) < 100.0
		):
			continue
		props.append({"pos": p, "r": rng.randf_range(14.0, 38.0)})


func _spawn_player() -> void:
	player = Player.new()
	player.run = self
	player.position = DROP_POS
	world.add_child(player)
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(MAP_RECT.size.x)
	cam.limit_bottom = int(MAP_RECT.size.y)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)


func _spawn_squads() -> void:
	for i in SQUAD_COUNT:
		var center := Vector2.ZERO
		for attempt in 40:  # 강하 안전지대 밖 + 특수 지점 위 금지
			center = Vector2(
				rng.randf_range(150, MAP_RECT.size.x - 150),
				rng.randf_range(150, MAP_RECT.size.y - 150)
			)
			if center.distance_to(DROP_POS) > SAFE_RADIUS:
				break
		var w := rng.randf_range(90.0, 180.0)
		var h := rng.randf_range(90.0, 180.0)
		var route := PackedVector2Array([
			center + Vector2(-w, -h), center + Vector2(w, -h),
			center + Vector2(w, h), center + Vector2(-w, h)
		])
		for m in 3:
			var kind := Enemy.Kind.SHOOTER if m == 2 else Enemy.Kind.RUSHER
			_spawn_enemy(kind, center + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30)),
				route, (i + m) % 4)


func _spawn_enemy(
	kind: Enemy.Kind, pos: Vector2, route: PackedVector2Array, patrol_start: int
) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	e.run = self
	e.position = pos.clamp(MAP_RECT.position + Vector2(20, 20), MAP_RECT.end - Vector2(20, 20))
	e.patrol_points = route
	if not route.is_empty():
		e._patrol_i = patrol_start % route.size()  # 분대원 출발점 분산(뭉침 방지)
	if kind == Enemy.Kind.SHOOTER:
		e.hp = 2.0
		e.speed = 50.0
	world.add_child(e)
	enemies.append(e)
	return e


func _process(delta: float) -> void:
	var e_now := Input.is_physical_key_pressed(KEY_E)
	var e_pressed := e_now and not _e_prev
	_e_prev = e_now
	match phase:
		Phase.EXPLORE:
			_tick_objective(delta, e_now)
			if objective_done and e_pressed and player.position.distance_to(evac_pos) < PAD_RADIUS + 14.0:
				_call_evac()
		Phase.EVAC_WAIT:
			_tick_evac(delta)
		Phase.DONE:
			if Input.is_physical_key_pressed(KEY_ENTER):
				Juice.reset()
				get_tree().reload_current_scene()
	_tick_pickups()
	_update_hud()


func _tick_objective(delta: float, holding_e: bool) -> void:
	if objective_done:
		return
	if holding_e and player.position.distance_to(objective_pos) < 30.0:
		objective_progress += delta / OBJECTIVE_CHANNEL
		if objective_progress >= 1.0:
			objective_done = true
			Juice.popup("송신기 파괴!", objective_pos + Vector2(-30, -30), Color(1, 0.9, 0.4), 14)
			Juice.shake(5.0)
			Juice.debris(objective_pos, Color(1, 0.8, 0.3), 8)
			noise_at(objective_pos, 400.0)  # 폭발음 — 큰 소음
	else:
		objective_progress = maxf(objective_progress - delta * 0.5, 0.0)


func _call_evac() -> void:
	phase = Phase.EVAC_WAIT
	evac_t = EVAC_DURATION
	_wave_t = 2.0
	_wave_interval = 8.0
	Juice.popup("탈출선 호출 — 버텨라!", evac_pos + Vector2(-50, -34), Color(0.6, 1, 0.7), 14)
	Juice.shake(4.0)
	for e in enemies:  # 신호탄은 모두가 본다
		if is_instance_valid(e):
			e.hear(evac_pos)


func _tick_evac(delta: float) -> void:
	if not shuttle_here:
		evac_t -= delta
		_wave_t -= delta
		if _wave_t <= 0.0:
			_wave_t = _wave_interval
			_wave_interval = maxf(_wave_interval - 0.8, 4.0)
			_spawn_wave()
		if evac_t <= 0.0:
			shuttle_here = true
			Juice.popup("셔틀 도착 — 탑승!", evac_pos + Vector2(-44, -40), Color(0.6, 1, 0.7), 14)
			Juice.shake(6.0)
	elif player.position.distance_to(evac_pos) < PAD_RADIUS:
		_win = true
		phase = Phase.DONE


func _spawn_wave() -> void:
	var count := 3 + rng.randi_range(0, 2)
	for i in count:
		var edge := rng.randi() % 4
		var pos := Vector2.ZERO
		match edge:
			0: pos = Vector2(rng.randf_range(0, MAP_RECT.size.x), 20)
			1: pos = Vector2(rng.randf_range(0, MAP_RECT.size.x), MAP_RECT.size.y - 20)
			2: pos = Vector2(20, rng.randf_range(0, MAP_RECT.size.y))
			3: pos = Vector2(MAP_RECT.size.x - 20, rng.randf_range(0, MAP_RECT.size.y))
		var kind := Enemy.Kind.RUSHER if rng.randf() < 0.7 else Enemy.Kind.SHOOTER
		var e := _spawn_enemy(kind, pos, PackedVector2Array(), 0)
		e.state = Enemy.State.ALERT
		e.alert_pos = evac_pos  # 셔틀 지점으로 쇄도 → 시야 들어오면 교전 전환


func _tick_pickups() -> void:
	for i in range(ammo_drops.size() - 1, -1, -1):
		if player.position.distance_to(ammo_drops[i]) < 13.0:
			player.reserve += 8
			Juice.popup("+8 탄약", ammo_drops[i] + Vector2(-14, -12), Color(0.5, 0.9, 1), 10)
			ammo_drops.remove_at(i)


func game_over() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	_win = false
	Juice.shake(8.0)
	Juice.debris(player.position, Color(0.9, 0.3, 0.3), 10)


func on_enemy_died(e: Enemy) -> void:
	enemies.erase(e)
	if rng.randf() < 0.3:  # 탄약 경제 순환 — 싸움이 보급을 만든다
		ammo_drops.append(e.position)


## 총성·폭음 전파 — 반경 내 순찰/경계 개체가 발원지를 확인하러 이동.
func noise_at(pos: Vector2, radius: float) -> void:
	for e in enemies:
		if is_instance_valid(e) and e.position.distance_to(pos) < radius:
			e.hear(pos)


## 원형 장애물 밀어내기 + 맵 경계 클램프(이동체 공용).
func push_out(pos: Vector2, radius: float) -> Vector2:
	var p := pos
	for prop in props:
		var d: Vector2 = p - prop.pos
		var min_d: float = prop.r + radius
		if d.length() < min_d:
			p = prop.pos + d.normalized() * min_d
	return p.clamp(
		MAP_RECT.position + Vector2(radius, radius), MAP_RECT.end - Vector2(radius, radius)
	)


## 발사체용 — 장애물 명중 여부.
func hits_prop(pos: Vector2) -> bool:
	for prop in props:
		if pos.distance_to(prop.pos) < prop.r:
			return true
	return false


func spawn_projectile(pos: Vector2, dir: Vector2, hostile: bool) -> void:
	var b := Projectile.new()
	b.run = self
	b.position = pos
	b.dir = dir
	b.hostile = hostile
	if hostile:
		b.speed = 240.0
	world.add_child(b)


# ── HUD ──


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud_status = Label.new()
	_hud_status.position = Vector2(6, 4)
	_hud_status.add_theme_font_size_override("font_size", 10)
	layer.add_child(_hud_status)
	_hud_mission = Label.new()
	_hud_mission.position = Vector2(6, 18)
	_hud_mission.add_theme_font_size_override("font_size", 10)
	_hud_mission.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8))
	layer.add_child(_hud_mission)
	_hud_msg = Label.new()
	_hud_msg.size = Vector2(640, 360)
	_hud_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_msg.add_theme_font_size_override("font_size", 18)
	layer.add_child(_hud_msg)


func _update_hud() -> void:
	var reload_txt := " (재장전…)" if player.reload_t > 0.0 else ""
	_hud_status.text = "HP %d   탄약 %d/%d%s" % [int(player.hp), player.mag, player.reserve, reload_txt]
	match phase:
		Phase.EXPLORE:
			if not objective_done:
				_hud_mission.text = "임무: 송신기 파괴 (E 홀드)"
			else:
				_hud_mission.text = "임무: 탈출 패드에서 신호 (E)"
		Phase.EVAC_WAIT:
			if shuttle_here:
				_hud_mission.text = "셔틀 도착 — 탑승하라!"
			else:
				_hud_mission.text = "셔틀 도착까지 %d초 — 버텨라" % int(ceil(evac_t))
		Phase.DONE:
			_hud_mission.text = ""
	if phase == Phase.DONE:
		_hud_msg.text = "임무 완료 — 생환!\n(Enter = 재강하)" if _win else "전사…\n(Enter = 재강하)"
	else:
		_hud_msg.text = ""


# ── 정적 드로잉 (Ground 프록시가 호출 — World 소속이라 셰이크 동조) ──


func draw_ground(c: CanvasItem) -> void:
	c.draw_rect(MAP_RECT, Color(0.13, 0.14, 0.16))  # 바닥
	c.draw_rect(MAP_RECT, Color(0.4, 0.42, 0.5), false, 3.0)  # 경계
	c.draw_circle(DROP_POS, 16.0, Color(0.25, 0.3, 0.35))  # 강하 지점
	for prop in props:
		c.draw_circle(prop.pos, prop.r, Color(0.28, 0.29, 0.33))
	for a in ammo_drops:
		c.draw_rect(Rect2(a - Vector2(4, 4), Vector2(8, 8)), Color(0.5, 0.9, 1.0))
	# 목표: 송신기(노란 사각) + 채널 진행 링
	if not objective_done:
		c.draw_rect(Rect2(objective_pos - Vector2(10, 10), Vector2(20, 20)), Color(1, 0.85, 0.3))
		if objective_progress > 0.0:
			c.draw_arc(
				objective_pos, 18.0, -PI / 2, -PI / 2 + TAU * objective_progress, 24,
				Color(1, 0.95, 0.6), 3.0
			)
	else:
		c.draw_rect(Rect2(objective_pos - Vector2(10, 10), Vector2(20, 20)), Color(0.4, 0.35, 0.25))
	# 탈출 패드 — 목표 완료 후 활성(펄스)
	var pad_col := Color(0.3, 0.5, 0.4)
	if objective_done and phase == Phase.EXPLORE:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
		pad_col = Color(0.3, 0.8, 0.5).lerp(Color(0.5, 1.0, 0.7), pulse)
	elif phase != Phase.EXPLORE:
		pad_col = Color(0.4, 0.9, 0.6)
	c.draw_circle(evac_pos, PAD_RADIUS, pad_col)
	c.draw_arc(evac_pos, PAD_RADIUS + 4.0, 0, TAU, 28, pad_col.lightened(0.3), 2.0)
	if shuttle_here:  # 셔틀(그레이박스 = 큰 초록 사각)
		c.draw_rect(Rect2(evac_pos - Vector2(26, 40), Vector2(52, 30)), Color(0.5, 0.9, 0.6))
