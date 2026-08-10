extends Node2D
## 용병 — 사거리 내 최근접 적을 자동 사격. 파견 전 배치, 전사하면 딜레이 후 예비로 복귀(재배치 버튼).
## 스탯(화력/체력)은 전부 run 의 수식에서 온다 — 개체 고유 능력 없음 (헌법 4조).

var run: Node2D
var hp := 30.0
var max_hp := 30.0

const RANGE := 110.0
const FIRE_CD := 0.5

var _cd := 0.0
var _flash := 0.0
var _dead := false


func _process(delta: float) -> void:
	if run.phase != run.Phase.DEFEND:
		return
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()
	_cd -= delta
	if _cd > 0.0:
		return
	var best: Node2D = null
	var bd := RANGE
	for e in run.enemies:
		var d: float = position.distance_to(e.position)
		if d < bd:
			bd = d
			best = e
	if best:
		_cd = FIRE_CD
		run.add_tracer(position, best.position)
		Sfx.play("shot", run.rng.randf_range(0.9, 1.1))
		best.take(run.merc_dmg())


func take(d: float) -> void:
	if _dead:
		return
	hp -= d
	_flash = 0.1
	queue_redraw()
	if hp <= 0.0:
		_dead = true
		run.on_merc_dead(self)


func _draw() -> void:
	var c := Color(1, 1, 1) if _flash > 0.0 else Color(0.45, 0.82, 0.9)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -9), Vector2(8, 7), Vector2(-8, 7)]), c)
	draw_rect(Rect2(-8, -15, 16, 2), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-8, -15, 16.0 * clampf(hp / max_hp, 0.0, 1.0), 2), Color(0.5, 0.9, 0.95))
