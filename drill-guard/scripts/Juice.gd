extends Node
## 전투 피드백 유틸 (autoload "Juice") — 히트스톱·셰이크·넘버팝업·파편·플래시.
## ProjectScavenger에서 인양 (Scripts/Combat/Juice.gd — docs/scavenger-salvage.md 참조).
##
## 좌표: popup/debris 는 world-local 좌표에 노드를 붙인다(world = Run 이 bind).
## 히트스톱 = Engine.time_scale 잠깐 ↓. 셰이크 = world.position 감쇠 흔들기.

var world: Node2D = null
var _shake_amount: float = 0.0
var _hitstopping: bool = false

const SHAKE_DECAY := 60.0  # px/s 감쇠율


func bind(w: Node2D) -> void:
	world = w
	_shake_amount = 0.0
	if is_instance_valid(world):
		world.position = Vector2.ZERO


## 씬 재시작 등에서 시간 배율·상태 원복(누적 정지 방지).
func reset() -> void:
	Engine.time_scale = 1.0
	_hitstopping = false
	_shake_amount = 0.0
	if is_instance_valid(world):
		world.position = Vector2.ZERO


func _process(delta: float) -> void:
	if not is_instance_valid(world):
		return
	if _shake_amount > 0.3:
		world.position = Vector2(
			randf_range(-_shake_amount, _shake_amount), randf_range(-_shake_amount, _shake_amount)
		)
		# time_scale 영향 안 받게 실시간 감쇠(히트스톱 중에도 자연 복귀).
		var real_delta := delta if Engine.time_scale > 0.01 else 0.016
		_shake_amount = move_toward(_shake_amount, 0.0, SHAKE_DECAY * real_delta)
	else:
		_shake_amount = 0.0
		world.position = Vector2.ZERO


## 짧은 시간정지 — time_scale 0 후 d초(실시간) 뒤 1.0 복귀. 중첩은 무시(누적 정지 금지).
func hitstop(duration: float) -> void:
	if _hitstopping:
		return
	_hitstopping = true
	Engine.time_scale = 0.0
	var t := get_tree().create_timer(duration, true, false, true)
	t.timeout.connect(_end_hitstop)


func _end_hitstop() -> void:
	Engine.time_scale = 1.0
	_hitstopping = false


## 흔들림 강도 세팅(큰 값이 오면 덮어쓰기). _process 가 감쇠.
func shake(amount: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)


## 월드 좌표에 떠오르는 텍스트.
func popup(text: String, world_pos: Vector2, color: Color, size: int = 16) -> void:
	if not is_instance_valid(world):
		return
	var l := Label.new()
	l.text = text
	l.position = world_pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	world.add_child(l)
	var t := create_tween()
	t.tween_property(l, "position", world_pos + Vector2(0, -22), 0.5).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.5)
	t.tween_callback(l.queue_free)


## count 개 입자를 무작위 방향으로 분출.
func debris(world_pos: Vector2, color: Color, count: int) -> void:
	if not is_instance_valid(world):
		return
	for i in count:
		var r := ColorRect.new()
		r.color = color
		r.size = Vector2(3, 3)
		r.position = world_pos
		world.add_child(r)
		var dir := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(14, 40)
		var t := create_tween()
		t.tween_property(r, "position", world_pos + dir, 0.35).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(r, "modulate:a", 0.0, 0.35)
		t.tween_callback(r.queue_free)


## 노드 modulate 점멸 후 원복(피격·파손 강조).
func flash(node: CanvasItem, color: Color) -> void:
	if not is_instance_valid(node):
		return
	var orig: Color = node.modulate
	var t := create_tween()
	t.tween_property(node, "modulate", color, 0.04)
	t.tween_property(node, "modulate", orig, 0.16)
