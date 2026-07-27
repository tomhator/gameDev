class_name Enemy
extends Node2D
## 적 1기 — 그레이박스. 3상태 FSM: PATROL(순찰) → ALERT(경계·소음 지점 확인) → COMBAT(교전).
## 충돌은 Run 이 수동 거리 판정. 텔레그래프 = 상태 틴트 점멸(스캐빈저 인양 문법 —
## docs/scavenger-salvage.md). HP = float 유지(int 캐스팅 시 배수 증발, 스캐빈저 교훈).

enum Kind { RUSHER, SHOOTER }
enum State { PATROL, ALERT, COMBAT }

const RADIUS := 9.0
const SIGHT_RANGE := 140.0  # 시야 반경(그레이박스 — 지형 무시)
const LOSE_RANGE := 280.0  # 이 밖으로 벗어나면 추격 포기 → 마지막 위치 경계
const ALERT_WAIT := 3.0  # 경계 지점 도착 후 순찰 복귀까지 대기
const SHOUT_RADIUS := 120.0  # 교전 진입 시 분대 동료를 깨우는 소리 반경

var kind: Kind = Kind.RUSHER
var state: State = State.PATROL
var hp: float = 3.0
var speed: float = 55.0
var run: Node2D

var patrol_points: PackedVector2Array = []
var _patrol_i: int = 0
var alert_pos: Vector2 = Vector2.ZERO
var _alert_t: float = 0.0
var fire_cd: float = 0.0
var contact_cd: float = 0.0
var _t: float = 0.0  # 점멸 위상


func _process(delta: float) -> void:
	_t += delta
	fire_cd = maxf(fire_cd - delta, 0.0)
	contact_cd = maxf(contact_cd - delta, 0.0)
	var p: Node2D = run.player
	var see := is_instance_valid(p) and position.distance_to(p.position) < SIGHT_RANGE
	match state:
		State.PATROL:
			if see:
				_enter_combat()
			else:
				_move_along_patrol(delta)
		State.ALERT:
			if see:
				_enter_combat()
			else:
				_tick_alert(delta)
		State.COMBAT:
			_tick_combat(delta, p)
	queue_redraw()


## 소음/신호 수신 — 순찰 중이면 발원지 확인하러 이동(ALERT). 교전 중이면 무시.
func hear(pos: Vector2) -> void:
	if state == State.COMBAT:
		return
	state = State.ALERT
	alert_pos = pos
	_alert_t = 0.0


func _enter_combat() -> void:
	if state != State.COMBAT:
		state = State.COMBAT
		Juice.popup("!", position + Vector2(0, -14), Color(1, 0.4, 0.3), 12)
		run.noise_at(position, SHOUT_RADIUS)  # 분대 동료 경계(교전의 소리)


func _move_along_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return
	var target := patrol_points[_patrol_i]
	if position.distance_to(target) < 6.0:
		_patrol_i = (_patrol_i + 1) % patrol_points.size()
		return
	_step_toward(target, speed * 0.6, delta)


func _tick_alert(delta: float) -> void:
	if position.distance_to(alert_pos) > 8.0:
		_step_toward(alert_pos, speed, delta)
		return
	_alert_t += delta
	if _alert_t >= ALERT_WAIT:
		state = State.PATROL


func _tick_combat(delta: float, p: Node2D) -> void:
	if not is_instance_valid(p):
		state = State.ALERT
		return
	var dist := position.distance_to(p.position)
	if dist > LOSE_RANGE:  # 추격 포기 — 마지막 목격 지점 경계
		state = State.ALERT
		alert_pos = p.position
		_alert_t = 0.0
		return
	if kind == Kind.RUSHER:
		_step_toward(p.position, speed, delta)
		if dist < RADIUS + 9.0 and contact_cd <= 0.0:
			contact_cd = 1.0
			p.take_hit()
	else:  # SHOOTER — 거리 유지 + 사격
		if dist < 80.0:
			_step_toward(position + (position - p.position), speed * 0.8, delta)
		elif dist > 130.0:
			_step_toward(p.position, speed * 0.8, delta)
		if fire_cd <= 0.0 and dist < 180.0:
			fire_cd = 1.6
			run.spawn_projectile(position, (p.position - position).normalized(), true)


func _step_toward(target: Vector2, spd: float, delta: float) -> void:
	position += (target - position).normalized() * spd * delta
	position = run.push_out(position, RADIUS)


func damage(dmg: float, hit_dir: Vector2) -> void:
	hp -= dmg
	Juice.flash(self, Color(1, 1, 1))
	Juice.popup(str(int(dmg)), position + Vector2(0, -12), Color(1, 0.9, 0.5), 10)
	if state != State.COMBAT:  # 피격 = 즉시 교전
		_enter_combat()
	if hp <= 0.0:
		Juice.hitstop(0.03)
		Juice.shake(3.0)
		Juice.debris(position, _base_color(), 5)
		run.on_enemy_died(self)
		queue_free()
	else:
		position += hit_dir.normalized() * 3.0  # 미세 넉백(타격 체감)


func _base_color() -> Color:
	return Color(0.85, 0.4, 0.3) if kind == Kind.RUSHER else Color(0.7, 0.45, 0.85)


func _draw() -> void:
	var c := _base_color()
	match state:
		State.ALERT:  # 경계 = 노란 점멸(텔레그래프)
			if fmod(_t, 0.4) < 0.2:
				c = c.lerp(Color(1, 0.9, 0.3), 0.6)
		State.COMBAT:  # 교전 = 밝게
			c = c.lerp(Color(1, 0.6, 0.5), 0.35)
	draw_circle(Vector2.ZERO, RADIUS, c)
	# 진행 방향 표식(다음 목적지 쪽 짧은 선)
	var aim := Vector2.RIGHT
	if state == State.COMBAT and is_instance_valid(run.player):
		aim = (run.player.position - position).normalized()
	elif state == State.ALERT:
		aim = (alert_pos - position).normalized()
	elif not patrol_points.is_empty():
		aim = (patrol_points[_patrol_i] - position).normalized()
	draw_line(Vector2.ZERO, aim * (RADIUS + 4.0), c.lightened(0.4), 2.0)
