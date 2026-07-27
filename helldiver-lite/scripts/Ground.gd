extends Node2D
## 바닥/정적 요소 드로잉 프록시 — World 자식이라 Juice 셰이크에 함께 흔들린다.
## 실제 드로잉 내용은 Run.draw_ground()가 정의.

var run: Node2D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if is_instance_valid(run):
		run.draw_ground(self)
