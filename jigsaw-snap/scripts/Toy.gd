extends Node2D
## 직소 손맛 토이 — 그레이박스 0주차. 게임이 아니라 "착!" 검증기 (방향은 브레인스토밍 중).
## 랜덤 조각을 중앙 핵에 이어 붙인다. 돌기(+1)와 홈(-1)이 서로 맞아야(합=0) 끼워짐.
## 콤보: 마지막 배치 후 3초 안에 또 끼우면 배수↑. 점수 = 10 × 맞물린 변 수 × 콤보.
## 검증 질문은 STATUS.md — ①콤보 "착!" 에스컬레이션 ②3초 타이머 vs 젠 모드 ③자리 수색의 재미.

const N := 7
const CELL := 44.0
const PAD := Vector2(16.0, 26.0)
const COMBO_WINDOW := 3.0
const QUEUE_LEN := 4

## [dr, dc, 내 변, 상대 변] — 변 순서: 상0 우1 하2 좌3
const NB := [[-1, 0, 0, 2], [0, 1, 1, 3], [1, 0, 2, 0], [0, -1, 3, 1]]

var board: Array = []  # N×N — null 또는 조각 {edges, v, is_core, placed_at}
var queue: Array = []
var score := 0
var combo := 0
var best_combo := 0
var last_place := -1e9
var zen := false
var done := false
var hover_r := -1
var hover_c := -1
var rng := RandomNumberGenerator.new()

var world: Node2D
var canvas: Node2D

var _score_l: Label
var _combo_l: Label
var _best_l: Label
var _zen_l: Label
var _hint_l: Label


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _ready() -> void:
	rng.randomize()
	world = Node2D.new()
	add_child(world)
	Juice.bind(world)
	canvas = load("res://scripts/Board.gd").new()
	canvas.toy = self
	world.add_child(canvas)
	_build_hud()
	_reset()


func _process(_delta: float) -> void:
	if combo > 0 and not zen and now() - last_place > COMBO_WINDOW:
		combo = 0
		Sfx.play("brk")
		_update_labels()
	canvas.queue_redraw()


# ---------- 조각/보드 ----------

func new_piece() -> Dictionary:
	var edges: Array = []
	for i in 4:
		var r := rng.randf()
		edges.append(1 if r < 0.4 else (-1 if r < 0.8 else 0))
	return {"edges": edges, "v": rng.randf_range(0.76, 0.9), "is_core": false, "placed_at": 0.0}


## 놓을 수 있으면 맞물린 변 수(1~4), 아니면 0. 기존 조각과 최소 1변 접해야 함.
func fit_info(p: Dictionary, r: int, c: int) -> int:
	if r < 0 or c < 0 or r >= N or c >= N or board[r][c] != null:
		return 0
	var touch := 0
	for nb in NB:
		var nr: int = r + nb[0]
		var nc: int = c + nb[1]
		if nr < 0 or nc < 0 or nr >= N or nc >= N:
			continue
		var q = board[nr][nc]
		if q == null:
			continue
		if p["edges"][nb[2]] + q["edges"][nb[3]] != 0:
			return 0
		touch += 1
	return touch


func valid_cells(p: Dictionary) -> Array:
	var out: Array = []
	for r in N:
		for c in N:
			if fit_info(p, r, c) > 0:
				out.append(Vector2i(r, c))
	return out


func rotated(p: Dictionary) -> Dictionary:
	var e: Array = p["edges"]
	var q := p.duplicate(true)
	q["edges"] = [e[3], e[0], e[1], e[2]]
	return q


func _board_full() -> bool:
	for r in N:
		for c in N:
			if board[r][c] == null:
				return false
	return true


# ---------- 동작 ----------

func _reset() -> void:
	board = []
	for r in N:
		var row := []
		for c in N:
			row.append(null)
		board.append(row)
	var core := new_piece()
	core["is_core"] = true
	board[3][3] = core
	queue = []
	for i in QUEUE_LEN:
		queue.append(new_piece())
	score = 0
	combo = 0
	best_combo = 0
	last_place = -1e9
	done = false
	Juice.reset()
	_update_labels()


func _try_place(r: int, c: int) -> void:
	if done:
		return
	var p: Dictionary = queue[0]
	var m := fit_info(p, r, c)
	var cell_pos := PAD + Vector2(c, r) * CELL + Vector2(CELL, CELL) * 0.5
	if m == 0:
		Sfx.play("fail")
		Juice.shake(2.0)
		return
	combo = combo + 1 if (zen or now() - last_place <= COMBO_WINDOW) else 1
	last_place = now()
	best_combo = maxi(best_combo, combo)
	var pts := 10 * m * combo
	score += pts
	p["placed_at"] = now()
	board[r][c] = p
	queue.pop_front()
	queue.append(new_piece())

	# 손맛 — 콤보가 오를수록 소리·흔들림·파편이 세진다.
	Sfx.play("snap", 1.0 + minf(combo, 20.0) * 0.06)
	Juice.shake(minf(2.0 + combo * 0.9, 11.0))
	Juice.debris(cell_pos, Color(1.0, 0.75, 0.3), 6 + mini(combo * 2, 14))
	var txt := "착! ×%d" % combo if combo >= 2 else "착!"
	var col := Color(1.0, 0.5, 0.32) if combo >= 6 else Color(1.0, 0.8, 0.35)
	Juice.popup(txt, cell_pos + Vector2(-16, -34), col, 20 if combo >= 6 else 16)
	if m == 4:  # 만끼움 — 4변 전부 맞물림
		Juice.hitstop(0.05)
		Juice.debris(cell_pos, Color(0.95, 0.72, 0.2), 24)
		Juice.popup("완벽!! +%d" % pts, cell_pos + Vector2(-34, -56), Color(0.95, 0.72, 0.2), 22)

	if _board_full():
		done = true
		Juice.popup("판 완성! Enter = 새 판", Vector2(80, 150), Color(0.95, 0.72, 0.2), 24)
	_update_labels()


func _rotate() -> void:
	queue[0] = rotated(queue[0])
	_update_labels()


func _discard() -> void:
	queue.pop_front()
	queue.append(new_piece())
	combo = 0
	last_place = -1e9
	Sfx.play("drop")
	_update_labels()


# ---------- HUD ----------

func _hint_text() -> String:
	if done:
		return "판 완성! Enter = 새 판"
	var p: Dictionary = queue[0]
	if valid_cells(p).size() > 0:
		return "초록 칸 = 들어갈 자리. 연달아 끼우면 콤보!"
	var q := p
	for i in 3:
		q = rotated(q)
		if valid_cells(q).size() > 0:
			return "이 방향으론 안 맞음 — R로 회전해 보라"
	return "어디에도 안 맞는 조각 — X로 버리기 (콤보 리셋)"


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var dim := Color(0.72, 0.68, 0.58)
	var ink := Color(0.94, 0.9, 0.83)
	_mk_label("직소 손맛 토이 — 그레이박스 (게임 아님, 검증기)", Vector2(16, 6), 11, dim, layer)
	_mk_label("점수", Vector2(348, 30), 11, dim, layer)
	_score_l = _mk_label("0", Vector2(348, 44), 24, ink, layer)
	_mk_label("콤보", Vector2(490, 30), 11, dim, layer)
	_combo_l = _mk_label("–", Vector2(490, 44), 24, Color(1.0, 0.8, 0.35), layer)
	_best_l = _mk_label("최고 콤보 –", Vector2(348, 104), 11, dim, layer)
	_zen_l = _mk_label("", Vector2(348, 120), 11, dim, layer)
	_mk_label("다음", Vector2(348, 146), 11, dim, layer)
	_hint_l = _mk_label("", Vector2(348, 244), 13, Color(1.0, 0.8, 0.35), layer)
	_hint_l.size = Vector2(276, 0)
	_hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var help := _mk_label("좌클릭 배치 · 우클릭/R/Space 회전\nX 버리기 · Z 젠 모드 · Enter 새 판", Vector2(348, 306), 11, dim, layer)
	help.size = Vector2(276, 0)


func _mk_label(text: String, pos: Vector2, size: int, col: Color, layer: CanvasLayer) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	layer.add_child(l)
	return l


func _update_labels() -> void:
	_score_l.text = str(score)
	_combo_l.text = "×%d" % combo if combo > 0 else "–"
	_combo_l.add_theme_color_override(
		"font_color", Color(1.0, 0.5, 0.32) if combo >= 6 else Color(1.0, 0.8, 0.35)
	)
	_best_l.text = "최고 콤보 ×%d" % best_combo if best_combo > 0 else "최고 콤보 –"
	_zen_l.text = "젠 모드 ON — 콤보 안 끊김 (Z로 끄기)" if zen else "콤보 타이머 3초 (Z: 젠 모드 비교)"
	_hint_l.text = _hint_text()


# ---------- 입력 ----------

func _cell_at(pos: Vector2) -> Vector2i:
	var v := (pos - PAD) / CELL
	return Vector2i(int(floor(v.y)), int(floor(v.x)))  # (r, c)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _cell_at(event.position)
		hover_r = cell.x
		hover_c = cell.y
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var cell := _cell_at(event.position)
			_try_place(cell.x, cell.y)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_rotate()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R, KEY_SPACE:
				_rotate()
			KEY_X:
				_discard()
			KEY_Z:
				zen = not zen
				_update_labels()
			KEY_ENTER:
				_reset()
