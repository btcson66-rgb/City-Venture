class_name CafeDayChart
extends Control
var rows: Array=[]
var metric: String="served"
func _ready() -> void:custom_minimum_size=Vector2(440,65)
func _draw() -> void:
	var title: String={"served":"Customers (people)","rev":"Revenue (dollars)","gross_margin":"Gross margin (%)"}[metric]
	draw_string(UIK.num_font(),Vector2(4,10),I18n.t(title),HORIZONTAL_ALIGNMENT_LEFT,420,8,Art.C_MUTED)
	if rows.is_empty():return
	var high:=1.0
	var low:=0.0
	for row in rows:high=maxf(high,float(row.get(metric,0)));low=minf(low,float(row.get(metric,0)))
	var previous:=Vector2.ZERO
	for i in rows.size():
		var value:=float(rows[i].get(metric,0))
		var at:=Vector2(6+i*400.0/maxi(1,rows.size()-1),57-(value-low)/maxf(1,high-low)*38)
		if i>0:draw_line(previous,at,Art.C_SKY,1.5)
		draw_circle(at,1.5,Art.C_GOLD);previous=at
	draw_string(UIK.num_font(),Vector2(350,10),"%.1f"%float(rows[-1].get(metric,0)),HORIZONTAL_ALIGNMENT_LEFT,85,8,Art.C_WHITE)
