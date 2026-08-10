extends Node2D
## 적 — 드릴로 직행하되, 어그로 거리(run.MERC_ENGAGE) 안에 용병이 있으면 그놈부터 문다.
## 수동 거리 판정(물리엔진 미사용). 사망 콜백은 run.on_enemy_dead 한 곳.

var run: Node2D
var hp := 6.0
var max_hp := 6.0
var speed := 45.0
var dmg := 8.0  # 초당 접촉 피해
var ore := 1

var _flash := 0.0
var _dead := false


func _process(delta: float) -> void:
	if run.phase != run.Phase.DEFEND:
		return
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()
	var target: Node2D = run.enemy_target(self)
	var tpos: Vector2 = target.position if target else run.DRILL_POS
	var contact: float = run.MERC_CONTACT if target else run.DRILL_CONTACT
	var d := position.distance_to(tpos)
	if d > contact:
		position += (tpos - position).normalized() * speed * delta
	elif target:
		target.take(dmg * delta)
	else:
		run.damage_drill(dmg * delta)


func take(d: float) -> void:
	if _dead:
		return
	hp -= d
	_flash = 0.08
	queue_redraw()
	if hp <= 0.0:
		_dead = true
		run.on_enemy_dead(self)


func _draw() -> void:
	var c := Color(1.0, 0.85, 0.8) if _flash > 0.0 else Color(0.85, 0.32, 0.26)
	draw_circle(Vector2.ZERO, 7.0, c)
	if hp < max_hp:
		draw_rect(Rect2(-8, -13, 16, 2), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(-8, -13, 16.0 * clampf(hp / max_hp, 0.0, 1.0), 2), Color(0.9, 0.5, 0.4))
