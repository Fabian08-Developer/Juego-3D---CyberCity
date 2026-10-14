class_name Vehicles
extends RefCounted
## Modelos de vehículos con silueta real (perfil lateral extruido). Miran hacia +Z.
## Devuelven {node, length, width, height} para que el tráfico ajuste distancias y colisiones.

const PAINTS := ["#c0392b", "#2c6fb7", "#ecf0f1", "#1f2a36", "#16a085", "#7d3c98", "#95a5a6", "#d35400", "#2e7d32", "#8b1e3f"]

static var _mesh_cache := {}


static func _profile_mesh(key: String, pts: Array, width: float) -> ArrayMesh:
	var k := "%s|%.2f" % [key, width]
	if not _mesh_cache.has(k):
		var profile := PackedVector2Array()
		for p in pts:
			profile.append(Vector2(p[0], p[1]))
		_mesh_cache[k] = Geo.extrude(profile, width)
	return _mesh_cache[k]


static func _paint(hex: String) -> StandardMaterial3D:
	var m := Mats.color(hex, 0.25, 0.55)
	m.clearcoat_enabled = true
	m.clearcoat = 0.6
	return m


## Ruedas con llanta, colocadas en los ejes indicados.
static func _wheels(node: Node3D, width: float, axles: Array, r: float) -> void:
	var tire := Mats.color("#151515", 0.9)
	var rim := Mats.color("#c9ced4", 0.25, 0.85)
	for z in axles:
		for side in [-1.0, 1.0]:
			var x: float = side * (width / 2.0 - 0.08)
			var t := Geo.mesh(node, Geo.cylinder_mesh(r, r, 0.26, 18), Vector3(x, r, z), tire)
			t.rotation.z = PI / 2.0
			var h := Geo.mesh(node, Geo.cylinder_mesh(r * 0.58, r * 0.58, 0.27, 12), Vector3(x + side * 0.01, r, z), rim)
			h.rotation.z = PI / 2.0


static func _lights(node: Node3D, width: float, length: float, y: float, head: Material, tail: Material) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * (width / 2.0 - 0.3)
		Geo.box(node, Vector3(0.36, 0.13, 0.06), Vector3(x, y, length / 2.0 + 0.01), head, false, false)
		Geo.box(node, Vector3(0.34, 0.12, 0.06), Vector3(x, y + 0.02, -length / 2.0 - 0.01), tail, false, false)
	var plate := Mats.color("#f2f2f2", 0.5)
	Geo.box(node, Vector3(0.45, 0.13, 0.03), Vector3(0, y - 0.22, length / 2.0 + 0.02), plate, false, false)
	Geo.box(node, Vector3(0.45, 0.13, 0.03), Vector3(0, y - 0.22, -length / 2.0 - 0.02), plate, false, false)


static func build(kind: String, rng: RandomNumberGenerator, head: Material, tail: Material) -> Dictionary:
	var node := Node3D.new()
	var glass := Mats.color("#16222e", 0.08, 0.9)
	var dark := Mats.color("#1d1f22", 0.7)
	var hex: String = PAINTS[rng.randi_range(0, PAINTS.size() - 1)]
	var info := {"node": node, "length": 4.4, "width": 1.85, "height": 1.5}
	match kind:
		"bus":
			var w := 2.55
			var l := 11.0
			var body := _paint("#e9ecef")
			Geo.box(node, Vector3(w, 2.7, l), Vector3(0, 1.75, 0), body, false)
			Geo.box(node, Vector3(w + 0.02, 0.35, l + 0.02), Vector3(0, 0.95, 0), Mats.color("#00a5c8", 0.4), false)
			for i in 6:
				var z := -l / 2.0 + 1.2 + i * 1.55
				Geo.box(node, Vector3(w + 0.04, 1.05, 1.3), Vector3(0, 2.25, z), glass, false)
			Geo.box(node, Vector3(w - 0.25, 1.4, 0.06), Vector3(0, 2.15, l / 2.0 + 0.01), glass, false)
			Geo.box(node, Vector3(0.05, 1.9, 1.1), Vector3(w / 2.0 + 0.01, 1.45, l / 2.0 - 1.4), glass, false)
			Geo.box(node, Vector3(w - 0.3, 0.35, 0.06), Vector3(0, 3.0, l / 2.0 + 0.02), Mats.emissive("#ffb020", 2.2), false, false)
			var route := Geo.label(node, "C1 · Centro", Vector3(0, 3.0, l / 2.0 + 0.06), 36, Color(0.1, 0.1, 0.1), 0.007)
			route.outline_size = 0
			Geo.box(node, Vector3(w - 0.4, 0.25, 2.5), Vector3(0, 3.2, -1.5), Mats.color("#ced4da", 0.6), false)
			_wheels(node, w, [l / 2.0 - 1.7, -l / 2.0 + 2.2], 0.52)
			_lights(node, w, l, 0.75, head, tail)
			info = {"node": node, "length": l, "width": w, "height": 3.3}
		"suv":
			var w := 1.95
			var l := 4.7
			var body := _paint(hex)
			var pts := [[-2.35, 0.38], [-2.35, 1.05], [-2.15, 1.15], [2.05, 1.12], [2.35, 0.95], [2.38, 0.38]]
			Geo.mesh(node, _profile_mesh("suv_body", pts, w), Vector3.ZERO, body)
			var cab := [[-2.2, 1.12], [-2.1, 1.82], [0.75, 1.84], [1.4, 1.12]]
			Geo.mesh(node, _profile_mesh("suv_cab", cab, w - 0.12), Vector3.ZERO, glass)
			Geo.box(node, Vector3(w - 0.08, 0.07, 2.95), Vector3(0, 1.86, -0.72), body, false)
			for z in [-2.15, -0.75, 0.68]:
				Geo.box(node, Vector3(w - 0.06, 0.7, 0.1), Vector3(0, 1.47, z), body, false)
			Geo.box(node, Vector3(1.4, 0.06, 2.4), Vector3(0, 1.93, -0.7), dark, false)
			Geo.box(node, Vector3(w - 0.1, 0.28, 0.08), Vector3(0, 0.55, l / 2.0 + 0.04), dark, false)
			_wheels(node, w, [1.45, -1.5], 0.4)
			_lights(node, w, l, 0.88, head, tail)
			info = {"node": node, "length": l, "width": w, "height": 1.95}
		"pickup":
			var w := 1.95
			var l := 5.2
			var body := _paint(["#b23a48", "#495057", "#2b6cb0", "#e9ecef"][rng.randi_range(0, 3)])
			var pts := [[-2.6, 0.4], [-2.6, 1.05], [2.3, 1.05], [2.6, 0.9], [2.62, 0.4]]
			Geo.mesh(node, _profile_mesh("pickup_body", pts, w), Vector3.ZERO, body)
			var cab := [[-0.5, 1.05], [-0.45, 1.8], [0.9, 1.8], [1.55, 1.05]]
			Geo.mesh(node, _profile_mesh("pickup_cab", cab, w - 0.1), Vector3.ZERO, glass)
			Geo.box(node, Vector3(w - 0.06, 0.07, 1.4), Vector3(0, 1.83, 0.2), body, false)
			Geo.box(node, Vector3(w - 0.06, 0.75, 0.12), Vector3(0, 1.42, -0.5), body, false)
			Geo.box(node, Vector3(w - 0.3, 0.05, 1.95), Vector3(0, 1.07, -1.55), dark, false)
			_wheels(node, w, [1.65, -1.7], 0.42)
			_lights(node, w, l, 0.85, head, tail)
			info = {"node": node, "length": l, "width": w, "height": 1.85}
		_:
			# Sedán (y taxi)
			var w := 1.82
			var l := 4.45
			var taxi := kind == "taxi"
			var body := _paint("#f4c20d" if taxi else hex)
			var pts := [[-2.22, 0.36], [-2.26, 0.72], [-2.05, 0.96], [-1.35, 1.0], [1.15, 1.0], [2.05, 0.86], [2.26, 0.66], [2.22, 0.36]]
			Geo.mesh(node, _profile_mesh("sedan_body", pts, w), Vector3.ZERO, body)
			var cab := [[-1.35, 1.0], [-0.85, 1.42], [0.45, 1.43], [1.12, 1.0]]
			Geo.mesh(node, _profile_mesh("sedan_cab", cab, w - 0.14), Vector3.ZERO, glass)
			Geo.box(node, Vector3(w - 0.12, 0.05, 1.25), Vector3(0, 1.45, -0.2), body, false)
			Geo.box(node, Vector3(w - 0.08, 0.42, 0.09), Vector3(0, 1.21, -0.25), body, false)
			Geo.box(node, Vector3(w - 0.1, 0.25, 0.08), Vector3(0, 0.5, l / 2.0 + 0.02), dark, false)
			if taxi:
				Geo.box(node, Vector3(0.75, 0.22, 0.32), Vector3(0, 1.58, -0.2), Mats.emissive("#fff3b0", 1.4), false)
				var t := Geo.label(node, "TAXI", Vector3(0, 1.58, -0.03), 28, Color(0.1, 0.1, 0.1), 0.006)
				t.outline_size = 0
			for side in [-1.0, 1.0]:
				Geo.box(node, Vector3(0.14, 0.1, 0.18), Vector3(side * (w / 2.0 + 0.05), 1.05, 0.95), body, false)
			_wheels(node, w, [1.35, -1.35], 0.36)
			_lights(node, w, l, 0.78, head, tail)
			info = {"node": node, "length": l, "width": w, "height": 1.5}
	return info
