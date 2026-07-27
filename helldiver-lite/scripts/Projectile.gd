class_name Projectile
extends Node2D
## 발사체 1발 — 그레이박스. 충돌은 수동 거리 판정(스캐빈저 결 — 물리엔진 미사용).

var dir: Vector2 = Vector2.RIGHT
var speed: float = 420.0
var damage: float = 1.0  # float 유지 — int 캐스팅 시 배수 보너스 증발(스캐빈저 교훈)
var hostile: bool = false  # true = 적탄(플레이어 명중 판정)
var life: float = 0.9
var run: Node2D


func _process(delta: float) -> void:
	position += dir * speed * delta
	life -= delta
	if life <= 0.0 or run.hits_prop(position):
		if run.hits_prop(position):
			Juice.debris(position, Color(0.6, 0.6, 0.6), 2)
		queue_free()
		return
	if hostile:
		var p: Node2D = run.player
		if is_instance_valid(p) and position.distance_to(p.position) < 9.0:
			p.take_hit()
			queue_free()
	else:
		for e in run.enemies:
			if is_instance_valid(e) and position.distance_to(e.position) < Enemy.RADIUS + 3.0:
				e.damage(damage, dir)
				queue_free()
				return
	queue_redraw()


func _draw() -> void:
	var c := Color(1.0, 0.55, 0.35) if hostile else Color(1.0, 1.0, 0.8)
	draw_rect(Rect2(-1.5, -1.5, 3, 3), c)
