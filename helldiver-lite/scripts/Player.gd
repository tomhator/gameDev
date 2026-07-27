class_name Player
extends Node2D
## 플레이어 — 그레이박스. WASD 이동 · 마우스 조준 · 좌클릭 사격 · R 재장전.
## 택티컬 규칙 ①② 담당: 사격 = 소음(순찰대 어그로), 탄약 = 한정(탄창+예비).
## 입력은 인풋맵 없이 물리 키 폴링(그레이박스 — 키 변경은 폴리싱 단계에서 인풋맵으로).

const SPEED := 140.0
const RADIUS := 8.0
const MAG_SIZE := 12
const FIRE_CD := 0.16
const RELOAD_TIME := 1.1
const NOISE_RADIUS := 220.0  # 총성 어그로 반경 — 규칙 ①의 핵심 수치

var hp: float = 3.0
var mag: int = MAG_SIZE
var reserve: int = 72
var reload_t: float = 0.0  # >0 = 재장전 중
var fire_cd: float = 0.0
var invuln_t: float = 0.0
var run: Node2D


func _process(delta: float) -> void:
	fire_cd = maxf(fire_cd - delta, 0.0)
	invuln_t = maxf(invuln_t - delta, 0.0)
	_tick_move(delta)
	_tick_reload(delta)
	_tick_fire()
	queue_redraw()


func _tick_move(delta: float) -> void:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1
	if v != Vector2.ZERO:
		position += v.normalized() * SPEED * delta
		position = run.push_out(position, RADIUS)


func _tick_reload(delta: float) -> void:
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			var need := MAG_SIZE - mag
			var take := mini(need, reserve)
			mag += take
			reserve -= take
		return
	if Input.is_physical_key_pressed(KEY_R) and mag < MAG_SIZE and reserve > 0:
		reload_t = RELOAD_TIME


func _tick_fire() -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if fire_cd > 0.0 or reload_t > 0.0 or run.phase == run.Phase.DONE:
		return
	if mag <= 0:
		if reserve > 0:
			reload_t = RELOAD_TIME  # 빈 탄창 격발 = 자동 재장전
		else:
			Juice.popup("탄약 없음!", position + Vector2(0, -16), Color(1, 0.5, 0.4), 10)
			fire_cd = 0.4
		return
	fire_cd = FIRE_CD
	mag -= 1
	var dir := (get_global_mouse_position() - position).normalized()
	run.spawn_projectile(position + dir * (RADIUS + 4.0), dir, false)
	run.noise_at(position, NOISE_RADIUS)  # 규칙 ① — 총성은 순찰대를 부른다
	Juice.shake(1.2)


func take_hit() -> void:
	if invuln_t > 0.0 or run.phase == run.Phase.DONE:
		return
	invuln_t = 0.9
	hp -= 1.0
	Juice.flash(self, Color(1, 0.3, 0.3))
	Juice.shake(6.0)
	Juice.hitstop(0.05)
	if hp <= 0.0:
		run.game_over()


func _draw() -> void:
	var body := Color(0.95, 0.95, 0.95)
	if invuln_t > 0.0 and fmod(invuln_t, 0.2) < 0.1:  # 무적 점멸
		body.a = 0.4
	draw_circle(Vector2.ZERO, RADIUS, body)
	var aim := (get_global_mouse_position() - position).normalized()
	draw_line(aim * RADIUS, aim * (RADIUS + 7.0), Color(1, 1, 0.7), 2.0)
	if reload_t > 0.0:  # 재장전 진행 링
		var frac := 1.0 - reload_t / RELOAD_TIME
		draw_arc(Vector2.ZERO, RADIUS + 5.0, -PI / 2, -PI / 2 + TAU * frac, 20, Color(1, 0.9, 0.4), 2.0)
