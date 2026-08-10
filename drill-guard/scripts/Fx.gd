extends Node2D
## 드릴·배터리 링·커서 오라·트레이서·배치 고스트 렌더 전담 (helldiver-lite Ground.gd 패턴).
## 상태는 전부 run 참조 — 이 노드는 그리기만 한다.

var run: Node2D


func _draw() -> void:
	var dp: Vector2 = run.DRILL_POS
	# 채굴공 바닥
	draw_circle(dp, 30.0, Color(0.15, 0.13, 0.1))
	# 드릴 본체
	draw_circle(dp, 15.0, Color(0.88, 0.66, 0.24))
	draw_circle(dp, 6.0, Color(0.55, 0.38, 0.12))
	# 배터리 링 — 드릴 둘레가 곧 시계 (디제틱 타이머)
	var bf: float = clampf(run.battery / run.battery_max(), 0.0, 1.0)
	if bf > 0.0 and run.phase != run.Phase.RESULT:
		var bc := Color(0.45, 0.85, 0.95) if bf > 0.25 else Color(1.0, 0.5, 0.3)
		draw_arc(dp, 24.0, -PI / 2.0, -PI / 2.0 + TAU * bf, 40, bc, 3.0)
	# 드릴 HP 바
	var hf: float = clampf(run.drill_hp / run.drill_hp_max(), 0.0, 1.0)
	draw_rect(Rect2(dp.x - 20, dp.y + 32, 40, 3), Color(0.2, 0.2, 0.2))
	draw_rect(
		Rect2(dp.x - 20, dp.y + 32, 40.0 * hf, 3),
		Color(0.9, 0.55, 0.3) if hf < 0.35 else Color(0.6, 0.9, 0.5)
	)
	# 커서 오라 — 닿는 곳이 곧 화력
	if run.phase == run.Phase.DEFEND:
		var mp: Vector2 = run.get_global_mouse_position()
		var r: float = run.cursor_radius()
		draw_circle(mp, r, Color(1.0, 0.8, 0.35, 0.05))
		for i in 12:
			var a0: float = TAU * i / 12.0 + run.spin
			draw_arc(mp, r, a0, a0 + TAU / 24.0, 4, Color(1.0, 0.8, 0.35, 0.65), 1.5)
	# 용병 트레이서
	for tr in run.tracers:
		var k: float = 1.0 - tr["t"] / 0.12
		draw_line(tr["a"], tr["b"], Color(0.7, 0.95, 1.0, 0.8 * k), 1.5)
	# 배치 고스트
	if (run.phase == run.Phase.PREP and run.reserve > 0) or run.placing:
		var gp: Vector2 = run.get_global_mouse_position()
		draw_colored_polygon(
			PackedVector2Array([gp + Vector2(0, -9), gp + Vector2(8, 7), gp + Vector2(-8, 7)]),
			Color(0.45, 0.82, 0.9, 0.45)
		)
