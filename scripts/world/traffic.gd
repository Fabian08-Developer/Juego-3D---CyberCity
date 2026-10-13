class_name Traffic
extends Node3D
## Tráfico con semáforos: los vehículos respetan la luz roja, guardan distancia
## con el de adelante y frenan si el jugador cruza delante de ellos.

const N := Config.BLOCKS + 1
const CYCLE := 33.0
const SPAN := Config.HALF + 30.0
const STOP_BACK := Config.ROAD / 2.0 + 1.6
const Y := Config.SIDEWALK_H
const COLORS := ["#c0392b", "#2980b9", "#ecf0f1", "#2c3e50", "#16a085", "#8e44ad", "#7f8c8d", "#d35400", "#27ae60"]

var player: Node3D
var _cars: Array = []
var _lanes := {}
var _offsets: Array = []
var _lamps: Array = []
var _centers: Array = []
var _time := 0.0
var _light_acc := 1.0
var _head_mat: StandardMaterial3D
var _tail_mat: StandardMaterial3D


func _ready() -> void:
	for k in N:
		_centers.append(Config.road_center(k))
	_head_mat = Mats.night_emissive("#fff8d0", 0.4, 6.0)
	_tail_mat = Mats.night_emissive("#ff2020", 0.6, 3.0)
	_build_traffic_lights()
	_spawn_cars()


## 0 = rojo, 1 = amarillo, 2 = verde para el eje de circulación dado.
func light_state(ix: int, iz: int, axis: String) -> int:
	var t := fmod(_time + float(_offsets[ix * N + iz]), CYCLE)
	if axis == "x":
		if t < 12.0:
			return 2
		if t < 15.0:
			return 1
		return 0
	if t >= 16.5 and t < 28.5:
		return 2
	if t >= 28.5 and t < 31.5:
		return 1
	return 0


func _lamp_mats() -> Array:
	var out := []
	for hex in ["#ff2a2a", "#ffbf1f", "#2aff6a"]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex).darkened(0.6)
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = 0.05
		out.append(m)
	return out


func _build_traffic_lights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var pole_mat := Mats.color("#2d3138", 0.5, 0.5)
	var housing := Mats.color("#15181d", 0.6)
	var r := Config.ROAD / 2.0 + 0.7
	for ix in N:
		for iz in N:
			_offsets.append(rng.randf() * CYCLE)
			var mats := {"x": _lamp_mats(), "z": _lamp_mats()}
			_lamps.append(mats)
			var cx: float = _centers[ix]
			var cz: float = _centers[iz]
			var poles := [
				[Vector3(cx - r, Y, cz + r), -PI / 2.0, "x"],
				[Vector3(cx + r, Y, cz - r), PI / 2.0, "x"],
				[Vector3(cx - r, Y, cz - r), PI, "z"],
				[Vector3(cx + r, Y, cz + r), 0.0, "z"],
			]
			for p in poles:
				var node := Node3D.new()
				node.position = p[0]
				node.rotation.y = p[1]
				add_child(node)
				Geo.mesh(node, Geo.cylinder_mesh(0.08, 0.1, 3.6, 8), Vector3(0, 1.8, 0), pole_mat)
				Geo.box(node, Vector3(0.38, 1.1, 0.28), Vector3(0, 3.6, 0.05), housing, false)
				var lamp_set: Array = mats[p[2]]
				for i in 3:
					Geo.mesh(node, Geo.sphere_mesh(0.12, 10, 6), Vector3(0, 3.95 - i * 0.35, 0.2), lamp_set[i], false)
				Geo.add_cylinder_collider(node, 0.12, 3.0, Vector3(0, 1.5, 0))


func _update_lights() -> void:
	for ix in N:
		for iz in N:
			var mats: Dictionary = _lamps[ix * N + iz]
			for axis in ["x", "z"]:
				var state := light_state(ix, iz, axis)
				var lamp_set: Array = mats[axis]
				for i in 3:
					var active := (i == 0 and state == 0) or (i == 1 and state == 1) or (i == 2 and state == 2)
					lamp_set[i].emission_energy_multiplier = 5.0 if active else 0.05


func _spawn_cars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var kinds := ["sedan", "sedan", "suv", "taxi", "sedan", "suv"]
	for k in N:
		var c: float = _centers[k]
		var lanes := [["x", 1, c + Config.LANE_OFFSET], ["x", -1, c - Config.LANE_OFFSET], ["z", 1, c - Config.LANE_OFFSET], ["z", -1, c + Config.LANE_OFFSET]]
		for lane in lanes:
			var key := "%s|%d|%d" % [lane[0], lane[1], k]
			_lanes[key] = []
			for i in 2:
				var kind: String = "bus" if (k == 1 and lane[0] == "x" and lane[1] == 1 and i == 0) else kinds[rng.randi_range(0, kinds.size() - 1)]
				var car := _make_car(kind, rng)
				add_child(car)
				var data := {
					"node": car, "axis": lane[0], "dir": lane[1], "lane": lane[2], "road": k,
					"s": -SPAN + (i + rng.randf() * 0.4) * SPAN, "speed": 0.0,
					"max": rng.randf_range(8.0, 12.0) * (0.7 if kind == "bus" else 1.0),
					"len": 10.0 if kind == "bus" else 4.5, "key": key,
				}
				_cars.append(data)
				_lanes[key].append(data)


func _make_car(kind: String, rng: RandomNumberGenerator) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	var paint_hex: String = COLORS[rng.randi_range(0, COLORS.size() - 1)]
	if kind == "taxi":
		paint_hex = "#f4c20d"
	elif kind == "bus":
		paint_hex = "#e8e8e8"
	var paint := Mats.color(paint_hex, 0.3, 0.5)
	var glass := Mats.color("#1b2a38", 0.1, 0.8)
	var w := 1.9
	var length := 4.3
	var h := 1.6
	match kind:
		"bus":
			w = 2.5
			length = 10.0
			h = 3.0
			Geo.box(body, Vector3(w, 2.5, length), Vector3(0, 1.65, 0), paint, false)
			Geo.box(body, Vector3(w + 0.02, 0.9, length - 1.6), Vector3(0, 2.15, -0.3), glass, false)
			Geo.box(body, Vector3(w + 0.02, 0.3, length), Vector3(0, 1.1, 0), Mats.color("#00a5c8", 0.4), false)
			Geo.box(body, Vector3(w - 0.3, 1.2, 0.05), Vector3(0, 2.2, length / 2.0), glass, false)
			var route := Geo.label(body, "C1 · Centro", Vector3(0, 2.75, length / 2.0 + 0.04), 40, Color(1.8, 1.4, 0.3), 0.008)
			route.outline_size = 0
		"suv":
			w = 2.0
			length = 4.6
			h = 1.9
			Geo.box(body, Vector3(w, 0.9, length), Vector3(0, 0.75, 0), paint, false)
			Geo.box(body, Vector3(w - 0.15, 0.75, 2.9), Vector3(0, 1.55, -0.3), glass, false)
		_:
			Geo.box(body, Vector3(w, 0.7, length), Vector3(0, 0.6, 0), paint, false)
			Geo.box(body, Vector3(w - 0.2, 0.6, 2.2), Vector3(0, 1.25, -0.2), glass, false)
			if kind == "taxi":
				Geo.box(body, Vector3(0.7, 0.22, 0.3), Vector3(0, 1.66, -0.2), Mats.emissive("#fff3b0", 1.5), false)
	var r := 0.5 if kind == "bus" else 0.35
	var wheel := Mats.color("#111111", 0.9)
	for x in [-w / 2.0, w / 2.0]:
		for z in [length / 2.0 - 0.9, -length / 2.0 + 0.9]:
			var wm := Geo.mesh(body, Geo.cylinder_mesh(r, r, 0.28, 14), Vector3(x, r, z), wheel)
			wm.rotation.z = PI / 2.0
	var front_y := 0.75 if kind != "bus" else 0.9
	for x in [-w / 2.0 + 0.35, w / 2.0 - 0.35]:
		Geo.box(body, Vector3(0.38, 0.16, 0.05), Vector3(x, front_y, length / 2.0 + 0.01), _head_mat, false, false)
		Geo.box(body, Vector3(0.38, 0.16, 0.05), Vector3(x, front_y, -length / 2.0 - 0.01), _tail_mat, false, false)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, h, length)
	cs.shape = shape
	cs.position.y = h / 2.0 + 0.1
	body.add_child(cs)
	return body


func _physics_process(delta: float) -> void:
	_time += delta
	_light_acc += delta
	if _light_acc > 0.2:
		_light_acc = 0.0
		_update_lights()
	var p := player.global_position if player != null else Vector3(9999, 0, 9999)
	for car in _cars:
		var dir: int = car["dir"]
		var s: float = car["s"]
		var length: float = car["len"]
		var axis: String = car["axis"]
		var desired: float = car["max"]

		# 1) Distancia con el vehículo de adelante en el mismo carril
		for other in _lanes[car["key"]]:
			if is_same(other, car):
				continue
			var d := wrapf((float(other["s"]) - s) * dir, 0.0, 2.0 * SPAN)
			var gap := d - (length + float(other["len"])) / 2.0
			if gap < 14.0:
				desired = minf(desired, maxf(0.0, (gap - 2.5) * 1.1))

		# 2) El jugador cruzando por delante
		var p_along := p.x if axis == "x" else p.z
		var p_side := p.z if axis == "x" else p.x
		var ahead := (p_along - s) * dir
		if ahead > 0.0 and ahead < length / 2.0 + 8.0 and absf(p_side - float(car["lane"])) < 1.9 and p.y < 1.5:
			desired = 0.0

		# 3) Semáforo de la próxima intersección
		var front := s + dir * length / 2.0
		var best := INF
		var best_state := 2
		for idx in _centers.size():
			var stop_line: float = float(_centers[idx]) - dir * STOP_BACK
			var dist := (stop_line - front) * dir
			if dist < -0.5 or dist > 35.0:
				continue
			if dist < best:
				best = dist
				var ix: int = idx if axis == "x" else int(car["road"])
				var iz: int = int(car["road"]) if axis == "x" else idx
				best_state = light_state(ix, iz, axis)
		if best < INF and best_state != 2 and (best_state == 0 or best > 4.0):
			desired = minf(desired, maxf(0.0, best * 1.2))

		# 4) Acelerar / frenar y avanzar
		var speed: float = car["speed"]
		if desired > speed:
			speed = minf(desired, speed + 3.5 * delta)
		else:
			speed = maxf(desired, speed - 9.0 * delta)
		s += dir * speed * delta
		if s > SPAN:
			s -= 2.0 * SPAN
		elif s < -SPAN:
			s += 2.0 * SPAN
		car["s"] = s
		car["speed"] = speed
		var node: AnimatableBody3D = car["node"]
		if axis == "x":
			node.position = Vector3(s, 0, float(car["lane"]))
			node.rotation.y = PI / 2.0 if dir > 0 else -PI / 2.0
		else:
			node.position = Vector3(float(car["lane"]), 0, s)
			node.rotation.y = 0.0 if dir > 0 else PI
