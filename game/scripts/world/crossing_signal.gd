class_name CrossingSignal
extends Node2D
var previous := false
func _process(_delta: float) -> void:
	var now := TrafficSafety.green()
	if now != previous: previous = now; queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(-5,-24,10,24), Color(0.12,0.12,0.18))
	draw_circle(Vector2(0,-17),3,Color(0.3,0.9,0.4) if TrafficSafety.green() else Color(0.95,0.25,0.2))
