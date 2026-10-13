class_name Minimap
extends Control
## Minimapa con el norte arriba: calles, edificios, jugador y objetivos.

const RANGE := Config.HALF + 10.0

var city: CityData
var player_pos := Vector3.ZERO
var player_yaw := 0.0
## [{pos: Vector3, color: Color}]
var targets: Array = []
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(230, 230)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _to_map(x: float, z: float) -> Vector2:
	return Vector2((x + RANGE) / (2.0 * RANGE), (z + RANGE) / (2.0 * RANGE)) * size


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#132a1c"))
	var road_w := Config.ROAD / (2.0 * RANGE) * size.x
	for k in Config.BLOCKS + 1:
		var c := _to_map(Config.road_center(k), Config.road_center(k))
		draw_rect(Rect2(c.x - road_w / 2.0, 0, road_w, size.y), Color("#3a3d42"))
		draw_rect(Rect2(0, c.y - road_w / 2.0, size.x, road_w), Color("#3a3d42"))
	if city != null:
		for s in city.map_shapes:
			var r: Rect2 = s["rect"]
			var a := _to_map(r.position.x, r.position.y)
			var b := _to_map(r.end.x, r.end.y)
			draw_rect(Rect2(a, b - a), s["color"])
		for s in city.map_shapes:
			var text: String = s["label"]
			if text in ["CyberShield", "Parque", "Casa"]:
				var r: Rect2 = s["rect"]
				var p := _to_map(r.get_center().x, r.get_center().y)
				draw_string(font, p + Vector2(-40, 4), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color.WHITE)
	for t in targets:
		var tp: Vector3 = t["pos"]
		var p := _to_map(tp.x, tp.z)
		var col: Color = t["color"]
		draw_arc(p, 5.0 + (sin(_t * 5.0) + 1.0) * 3.0, 0, TAU, 24, col, 2.0)
		draw_circle(p, 3.0, col)
	var pp := _to_map(player_pos.x, player_pos.z)
	var pts := PackedVector2Array([Vector2(0, -8), Vector2(6, 6), Vector2(0, 2), Vector2(-6, 6)])
	for i in pts.size():
		pts[i] = pp + pts[i].rotated(-player_yaw)
	draw_colored_polygon(pts, UiKit.CYAN)
	draw_string(font, Vector2(size.x / 2.0 - 4, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0.9, 1, 0.4), false, 1.0)
