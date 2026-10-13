class_name CityEvents
extends Node3D
## Situaciones de seguridad en la calle (USB abandonado, skimmers, Wi-Fi falso, tailgating…).
## Aparecen como un "!" flotante; al interactuar el jugador elige qué hacer.

signal event_appeared(ev: Dictionary)
signal event_opened(ev: Dictionary)

const REWARDS := {
	"good": {"xp": 30, "rep": 2.0},
	"neutral": {"xp": 8, "rep": 0.0},
	"bad": {"xp": 0, "rep": -3.0},
}

var city: CityData
var active: Array = []  # [{def, node, expires}]
var _defs: Array = []
var _next_at := 0.0


func _ready() -> void:
	var data = CityBuilder.load_json("res://data/city_events.json")
	_defs = data if data is Array else []
	reset_day()


func reset_day() -> void:
	for a in active:
		a["node"].queue_free()
	active.clear()
	_next_at = GameState.minutes + randf_range(20.0, 50.0)


func update() -> void:
	var now := GameState.minutes
	for a in active.duplicate():
		if now >= float(a["expires"]):
			_remove(a)
	if now >= _next_at and active.size() < 2:
		_spawn()
		_next_at = now + randf_range(70.0, 130.0)


func _spawn() -> void:
	var options := _defs.filter(func(d): return not active.any(func(a): return a["def"]["id"] == d["id"]))
	options.shuffle()
	for def in options:
		var spots: Array = []
		for s in def.get("spots", []):
			spots.append_array(city.event_spots.get(s, []))
		if spots.is_empty():
			continue
		var pos: Vector3 = spots.pick_random()
		var node := _marker(pos, def)
		var entry := {"def": def, "node": node, "expires": GameState.minutes + 180.0}
		active.append(entry)
		event_appeared.emit(def)
		return


func _marker(pos: Vector3, def: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var mark := Geo.label(root, "!", Vector3(0, 2.4, 0), 160, Color(2.0, 1.6, 0.2), 0.01, true)
	mark.outline_size = 24
	mark.no_depth_test = true
	var ring := Geo.mesh(root, Geo.cylinder_mesh(0.9, 0.9, 0.03, 24), Vector3(0, 0.03, 0), Mats.emissive("#ffc21f", 2.5), false)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color("#ffc21f")
	light.light_energy = 1.5
	light.omni_range = 4.0
	light.position = Vector3(0, 1.5, 0)
	root.add_child(light)
	var it := Interactable.create(root, Vector3.ZERO, "Investigar: " + str(def.get("title", "")), func(): event_opened.emit(def), 2.2)
	it.set_meta("event_id", def["id"])
	var tween := root.create_tween().set_loops()
	tween.tween_property(mark, "position:y", 2.7, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mark, "position:y", 2.4, 0.8).set_trans(Tween.TRANS_SINE)
	return root


func _remove(entry: Dictionary) -> void:
	active.erase(entry)
	var node: Node = entry["node"]
	node.queue_free()


## Aplica la decisión del jugador y devuelve el resultado {outcome, feedback, xp, rep}.
func resolve(def: Dictionary, option_index: int) -> Dictionary:
	var opt: Dictionary = def["options"][option_index]
	var outcome := str(opt.get("outcome", "neutral"))
	var reward: Dictionary = REWARDS.get(outcome, REWARDS["neutral"])
	GameState.add_xp(int(reward["xp"]))
	GameState.add_reputation(float(reward["rep"]))
	if outcome == "good":
		GameState.today["events_good"] += 1
	elif outcome == "bad":
		GameState.today["events_bad"] += 1
	for a in active.duplicate():
		if a["def"]["id"] == def["id"]:
			_remove(a)
	return {"outcome": outcome, "feedback": opt.get("feedback", ""), "xp": reward["xp"], "rep": reward["rep"]}


## Posiciones de los eventos activos (para el minimapa).
func positions() -> Array:
	var out := []
	for a in active:
		out.append((a["node"] as Node3D).global_position)
	return out
