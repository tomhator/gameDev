extends Node2D
## 보드·우측 패널 렌더 전담 — 상태는 전부 toy 참조 (helldiver-lite Ground.gd 패턴).
## 조각 = 정사각형 + 변마다 반원 돌기/홈을 샘플링한 폴리곤. 배치 직후 0.16s 팝 스케일.

var toy: Node2D

const ARC_STEPS := 10
const COL_FELT := Color(0.13, 0.19, 0.155)
const COL_GRID := Color(0.17, 0.24, 0.2)
const COL_EDGE := Color(0.24, 0.18, 0.09, 0.75)
const COL_CORE := Color(0.88, 0.66, 0.24)
const COL_OK := Color(0.56, 0.85, 0.54)
const COL_BAD := Color(0.9, 0.42, 0.35, 0.4)
const COL_GOLD := Color(1.0, 0.78, 0.33)
const COL_HOT := Color(1.0, 0.48, 0.3)


func _draw() -> void:
	var s: float = toy.CELL
	var pad: Vector2 = toy.PAD
	var n: int = toy.N

	# 매트 + 격자
	draw_rect(Rect2(pad - Vector2(8, 8), Vector2(s * n + 16, s * n + 16)), COL_FELT)
	for i in n + 1:
		draw_line(pad + Vector2(i * s, 0), pad + Vector2(i * s, n * s), COL_GRID, 1.0)
		draw_line(pad + Vector2(0, i * s), pad + Vector2(n * s, i * s), COL_GRID, 1.0)

	var cur: Dictionary = toy.queue[0]

	# 현재 조각이 들어갈 자리 표시
	for v in toy.valid_cells(cur):
		var r0 := Rect2(pad + Vector2(v.y, v.x) * s + Vector2(3, 3), Vector2(s - 6, s - 6))
		draw_rect(r0, Color(COL_OK.r, COL_OK.g, COL_OK.b, 0.1))
		draw_rect(r0, Color(COL_OK.r, COL_OK.g, COL_OK.b, 0.35), false, 1.0)

	# 놓인 조각 (배치 직후 팝 스케일)
	for r in n:
		for c in n:
			var p = toy.board[r][c]
			if p == null:
				continue
			var t: float = toy.now() - p["placed_at"]
			var k := 1.0 + 0.28 * (1.0 - t / 0.16) if t < 0.16 else 1.0
			_piece(pad + Vector2(c, r) * s, s, p, 1.0, k)

	# 마우스 고스트 — 안 맞는 자리면 붉은 오버레이
	var hr: int = toy.hover_r
	var hc: int = toy.hover_c
	if hr >= 0 and hc >= 0 and hr < n and hc < n and toy.board[hr][hc] == null and not toy.done:
		var ok: bool = toy.fit_info(cur, hr, hc) > 0
		var tint := Color(0, 0, 0, 0) if ok else COL_BAD
		_piece(pad + Vector2(hc, hr) * s, s, cur, 0.5, 1.0, tint)

	# 콤보 바 (우측 패널)
	var rem := 0.0
	if toy.combo > 0:
		rem = 1.0 if toy.zen else clampf(
			1.0 - (toy.now() - toy.last_place) / toy.COMBO_WINDOW, 0.0, 1.0
		)
	draw_rect(Rect2(348, 92, 260, 5), COL_GRID)
	if rem > 0.0:
		draw_rect(Rect2(348, 92, 260 * rem, 5), COL_HOT if rem < 0.33 else COL_GOLD)

	# 다음 조각 미리보기 — 현재(크게) + 대기열
	_piece(Vector2(356, 164), 48, cur, 1.0, 1.0)
	for i in range(1, mini(toy.queue.size(), 4)):
		_piece(Vector2(428 + (i - 1) * 44, 176), 26, toy.queue[i], 0.55, 1.0)


func _piece(pos: Vector2, s: float, p: Dictionary, alpha: float, k: float, tint := Color(0, 0, 0, 0)) -> void:
	var center := pos + Vector2(s, s) * 0.5
	draw_set_transform(center, 0.0, Vector2(k, k))
	var pts := _piece_points(-Vector2(s, s) * 0.5, s, p["edges"])
	var col: Color = COL_CORE if p["is_core"] else Color.from_hsv(0.105, 0.3, p["v"])
	col.a = alpha
	draw_colored_polygon(pts, col)
	if tint.a > 0.0:
		draw_colored_polygon(pts, tint)
	var line := pts.duplicate()
	line.append(pts[0])
	var ec := COL_EDGE
	ec.a *= alpha
	draw_polyline(line, ec, maxf(1.5, s * 0.04), true)
	if p["is_core"]:
		draw_circle(Vector2.ZERO, s * 0.1, Color(0.5, 0.33, 0.08, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 시계방향 외곽선. 변마다: 코너 → (돌기/홈이면) 반원 호 샘플. 호 시작각은 변별 고정,
## 스윕 +PI = 바깥(돌기), -PI = 안쪽(홈). y-down 좌표 기준.
func _piece_points(pos: Vector2, s: float, edges: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := s * 0.16
	var corners := [pos, pos + Vector2(s, 0), pos + Vector2(s, s), pos + Vector2(0, s)]
	var centers := [
		pos + Vector2(s * 0.5, 0), pos + Vector2(s, s * 0.5),
		pos + Vector2(s * 0.5, s), pos + Vector2(0, s * 0.5),
	]
	var starts := [PI, -PI / 2.0, 0.0, PI / 2.0]
	for i in 4:
		pts.append(corners[i])
		var e: int = edges[i]
		if e == 0:
			continue
		var sweep: float = PI if e == 1 else -PI
		for k in ARC_STEPS + 1:
			var a: float = starts[i] + sweep * float(k) / float(ARC_STEPS)
			pts.append(centers[i] + Vector2(cos(a), sin(a)) * r)
	return pts
