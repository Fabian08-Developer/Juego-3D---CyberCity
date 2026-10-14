class_name Buildings
extends RefCounted
## Edificios de la ciudad. Cada parcela (lot) es {x, z, w, d, facing: "N"|"S"};
## el frente del edificio se construye en +Z local y se gira según `facing`.

const FILLER_WALLS := ["#b8b2a7", "#8e9aa6", "#c7a98c", "#7d8a7a", "#a39188", "#d4cfc4", "#6f7b8a", "#9b8b7a", "#c4b59a"]
const GROUND_H := 4.2
const WALL_T := 0.3


static func _root(parent: Node3D, lot: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(lot["x"], Config.SIDEWALK_H, lot["z"])
	n.rotation.y = PI if lot["facing"] == "N" else 0.0
	parent.add_child(n)
	return n


static func _to_world(n: Node3D, local: Vector3) -> Vector3:
	return n.transform * local


## Edificio residencial / de oficinas (sin interior). Devuelve su nodo raíz.
static func filler(parent: Node3D, city: CityData, lot: Dictionary, rng: RandomNumberGenerator, label := "", map_color := Color("#5b5f66")) -> Node3D:
	var n := _root(parent, lot)
	var w: float = lot["w"]
	var d: float = lot["d"]
	var floors := rng.randi_range(3, 9)
	var h := floors * 3.4 - Config.SIDEWALK_H
	var curtain := rng.randf() < 0.3
	var wall: String = FILLER_WALLS[rng.randi_range(0, FILLER_WALLS.size() - 1)]
	var facade := Mats.facade(wall, curtain, rng.randi_range(0, 2))
	var trim := Mats.color("#4a4f57", 0.8)
	var setback := curtain and floors >= 7
	var body_h := h - 6.8 if setback else h
	Geo.box(n, Vector3(w, body_h, d), Vector3(0, body_h / 2.0, 0), facade)
	_architecture(n, w, d, body_h, wall, curtain, rng)
	if setback:
		Geo.box(n, Vector3(w - 3.0, 6.8, d - 3.0), Vector3(0, body_h + 3.4, 0), facade, false)
		_parapet(n, w - 3.0, d - 3.0, h, trim)
	# Entrada con marquesina y lámpara
	Geo.box(n, Vector3(1.8, 2.5, 0.12), Vector3(0, 1.25, d / 2.0 + 0.06), Mats.color("#3a2c22", 0.6), false)
	Geo.box(n, Vector3(3.2, 0.14, 1.5), Vector3(0, 2.95, d / 2.0 + 0.75), trim, false)
	Geo.box(n, Vector3(0.5, 0.06, 0.5), Vector3(0, 2.86, d / 2.0 + 0.75), Mats.night_emissive("#ffe2a8", 0.2, 5.0), false, false)
	# Azotea: equipos de aire acondicionado, tanque y antena
	for i in rng.randi_range(1, 3):
		var p := Vector3(rng.randf_range(-w / 4.0, w / 4.0), h + 0.45, rng.randf_range(-d / 4.0, d / 4.0))
		Geo.box(n, Vector3(1.4, 0.9, 1.0), p, Mats.color("#9aa1a9", 0.6, 0.3), false)
	Geo.mesh(n, Geo.cylinder_mesh(0.9, 0.9, 1.8, 12), Vector3(-w / 4.0, h + 0.9, d / 5.0), trim)
	if rng.randf() < 0.4:
		Geo.mesh(n, Geo.cylinder_mesh(0.04, 0.06, 4.0, 6), Vector3(w / 4.0, h + 2.0, -d / 4.0), Mats.color("#c9ced4", 0.3, 0.8))
	var color := Color("#4b6a85") if curtain else map_color
	city.add_shape(lot["x"] - w / 2.0, lot["z"] - d / 2.0, lot["x"] + w / 2.0, lot["z"] + d / 2.0, color, label)
	return n


## Zócalo, cornisas por piso, pretil y balcones según el estilo del edificio.
static func _architecture(n: Node3D, w: float, d: float, h: float, wall: String, curtain: bool, rng: RandomNumberGenerator) -> void:
	var base := Color(wall).darkened(0.35)
	var trim := Mats.color("#4a4f57", 0.8)
	Geo.box(n, Vector3(w + 0.14, 1.0, d + 0.14), Vector3(0, 0.5, 0), Mats.color(base.to_html(false), 0.9), false)
	if not curtain:
		var ledge := Mats.color(Color(wall).lightened(0.25).to_html(false), 0.8)
		var y := 3.4 - Config.SIDEWALK_H
		while y < h - 1.0:
			Geo.box(n, Vector3(w + 0.22, 0.14, d + 0.22), Vector3(0, y, 0), ledge, false)
			y += 3.4
		if rng.randf() < 0.55:
			_balconies(n, w, d, h, rng)
	else:
		# Aletas verticales de la fachada de vidrio
		var fin := Mats.color("#aab4bf", 0.35, 0.6)
		for x in [-w / 2.0 + 0.05, w / 2.0 - 0.05]:
			Geo.box(n, Vector3(0.18, h, 0.35), Vector3(x, h / 2.0, d / 2.0 + 0.1), fin, false)
	_parapet(n, w, d, h, trim)


static func _parapet(n: Node3D, w: float, d: float, h: float, mat: Material) -> void:
	var t := 0.25
	var ph := 0.9
	Geo.box(n, Vector3(w + 0.1, ph, t), Vector3(0, h + ph / 2.0, d / 2.0 - t / 2.0 + 0.05), mat, false)
	Geo.box(n, Vector3(w + 0.1, ph, t), Vector3(0, h + ph / 2.0, -d / 2.0 + t / 2.0 - 0.05), mat, false)
	Geo.box(n, Vector3(t, ph, d), Vector3(w / 2.0 - t / 2.0 + 0.05, h + ph / 2.0, 0), mat, false)
	Geo.box(n, Vector3(t, ph, d), Vector3(-w / 2.0 + t / 2.0 - 0.05, h + ph / 2.0, 0), mat, false)


## Balcones con baranda de vidrio en la fachada principal (desde el segundo piso).
static func _balconies(n: Node3D, w: float, d: float, h: float, rng: RandomNumberGenerator) -> void:
	var slab := Mats.color("#d8d4cc", 0.8)
	var rail := Mats.glass("#bfe3f5", 0.35)
	var metal := Mats.color("#3d434b", 0.4, 0.6)
	var cols := [-w / 4.0, w / 4.0] if rng.randf() < 0.6 else [0.0]
	var y := 3.4 - Config.SIDEWALK_H
	while y < h - 2.0:
		for x in cols:
			var z := d / 2.0 + 0.6
			Geo.box(n, Vector3(3.0, 0.14, 1.2), Vector3(x, y, z), slab, false)
			Geo.box(n, Vector3(3.0, 0.95, 0.04), Vector3(x, y + 0.55, z + 0.58), rail, false, false)
			Geo.box(n, Vector3(3.04, 0.05, 0.06), Vector3(x, y + 1.04, z + 0.58), metal, false, false)
			if rng.randf() < 0.35:
				Geo.mesh(n, Geo.sphere_mesh(0.28, 8, 5), Vector3(x + 1.0, y + 0.35, z + 0.2), Mats.color("#3c9a3f", 0.9))
		y += 3.4


## Punto frente a la puerta de un edificio (en mundo).
static func door_point(n: Node3D, lot: Dictionary, out := 1.4) -> Vector3:
	return _to_world(n, Vector3(0, 0, float(lot["d"]) / 2.0 + out))


## Negocio con planta baja recorrible: vitrina, puerta automática, mostrador, cajero(a) y mobiliario.
static func business(parent: Node3D, city: CityData, lot: Dictionary, def: Dictionary, on_shop: Callable) -> Node3D:
	var n := _root(parent, lot)
	var w: float = lot["w"]
	var d: float = lot["d"]
	var h := float(def.get("height", 8))
	var gh := GROUND_H
	var t := WALL_T
	var accent := Color(str(def.get("accent", "#00aaff")))
	var wall_mat := Mats.color(str(def.get("wall", "#cccccc")), 0.85)
	var inner_mat := Mats.color(str(def.get("inner", "#efe9df")), 0.9)
	var dark := Mats.color("#2b2b2b", 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(def.get("id", "x"))

	# --- Muros de la planta baja ---
	Geo.box(n, Vector3(w, gh, t), Vector3(0, gh / 2.0, -d / 2.0 + t / 2.0), wall_mat)
	Geo.box(n, Vector3(t, gh, d), Vector3(-w / 2.0 + t / 2.0, gh / 2.0, 0), wall_mat)
	Geo.box(n, Vector3(t, gh, d), Vector3(w / 2.0 - t / 2.0, gh / 2.0, 0), wall_mat)
	# Recubrimiento interior
	Geo.box(n, Vector3(w - 2 * t, gh - 0.05, 0.02), Vector3(0, gh / 2.0, -d / 2.0 + t + 0.01), inner_mat, false, false)
	Geo.box(n, Vector3(0.02, gh - 0.05, d - 2 * t), Vector3(-w / 2.0 + t + 0.01, gh / 2.0, 0), inner_mat, false, false)
	Geo.box(n, Vector3(0.02, gh - 0.05, d - 2 * t), Vector3(w / 2.0 - t - 0.01, gh / 2.0, 0), inner_mat, false, false)

	# --- Fachada: zócalo, vitrinas, franja superior y puerta automática ---
	var door_w := 2.4
	var seg := (w - door_w) / 2.0
	var fz := d / 2.0 - t / 2.0
	for side in [-1.0, 1.0]:
		var cx: float = side * (door_w / 2.0 + seg / 2.0)
		Geo.box(n, Vector3(seg, 0.5, t), Vector3(cx, 0.25, fz), wall_mat)
		Geo.box(n, Vector3(seg, 2.6, 0.08), Vector3(cx, 1.8, fz), Mats.glass("#9fd3e6", 0.22), true, false)
		for k in 3:
			var mx: float = cx - seg / 2.0 + seg * float(k) / 2.0
			Geo.box(n, Vector3(0.1, 2.6, 0.14), Vector3(mx, 1.8, fz), dark, false)
	Geo.box(n, Vector3(w, gh - 3.1, t), Vector3(0, 3.1 + (gh - 3.1) / 2.0, fz), wall_mat)
	Geo.box(n, Vector3(door_w, 0.5, 0.06), Vector3(0, 2.85, fz), Mats.glass("#9fd3e6", 0.3), false, false)
	var door := SlidingDoor.new(door_w - 0.1, 2.6)
	door.position = Vector3(0, 0, fz)
	n.add_child(door)

	# Piso interior
	Geo.box(n, Vector3(w - 2 * t, 0.02, d - 2 * t), Vector3(0, 0.011, 0), Mats.ground("tiles"), false, false)

	# --- Pisos superiores (su cara inferior es el techo de la tienda) ---
	var upper := h - gh
	Geo.box(n, Vector3(w, upper, d), Vector3(0, gh + upper / 2.0, 0), Mats.facade(str(def.get("wall", "#cccccc")), false, 1))
	var ledge := Mats.color(Color(str(def.get("wall", "#cccccc"))).lightened(0.25).to_html(false), 0.8)
	var ly := gh + 3.4
	while ly < h - 1.0:
		Geo.box(n, Vector3(w + 0.22, 0.14, d + 0.22), Vector3(0, ly, 0), ledge, false)
		ly += 3.4
	_parapet(n, w, d, h, Mats.color("#4a4f57", 0.8))
	Geo.box(n, Vector3(w + 0.1, 0.25, 0.5), Vector3(0, gh + 0.1, d / 2.0 + 0.1), Mats.color("#3a3f47", 0.8), false)

	# --- Toldo y letrero luminoso ---
	var awning := Geo.box(n, Vector3(w - 1.2, 0.08, 1.7), Vector3(0, 3.05, d / 2.0 + 0.8), Mats.color(accent.to_html(false), 0.7), false)
	awning.rotation.x = 0.25
	var sign_w := minf(w - 2.0, 12.0)
	Geo.box(n, Vector3(sign_w, 0.85, 0.14), Vector3(0, 3.68, d / 2.0 + 0.08), Mats.emissive(accent.to_html(false), 0.5), false)
	var sign := Geo.label(n, str(def.get("name", "Negocio")), Vector3(0, 3.7, d / 2.0 + 0.17), 72, Color(1.4, 1.4, 1.4), 0.008)
	sign.outline_size = 10
	Geo.label(n, "ABIERTO", Vector3(seg / 2.0 + door_w / 2.0, 2.6, d / 2.0 + 0.03), 40, Color(0.3, 2.0, 0.8), 0.006)

	# --- Iluminación interior ---
	var panel_mat := Mats.emissive("#ffffff", 1.5)
	for z in [-d / 4.0, d / 6.0]:
		Geo.box(n, Vector3(2.6, 0.05, 0.7), Vector3(0, gh - 0.03, z), panel_mat, false, false)
	var light := OmniLight3D.new()
	light.position = Vector3(0, gh - 0.6, 0)
	light.omni_range = maxf(w, d) * 0.85
	light.light_energy = 1.3
	light.light_color = Color("#fff3e0")
	n.add_child(light)

	# --- Mostrador y personal ---
	var counter_z := -d / 2.0 + 2.6
	Geo.box(n, Vector3(4.2, 1.05, 0.8), Vector3(0, 0.525, counter_z), Mats.color(accent.darkened(0.3).to_html(false), 0.6))
	Geo.box(n, Vector3(4.4, 0.06, 0.95), Vector3(0, 1.08, counter_z), Mats.ground("wood"), false)
	Geo.box(n, Vector3(0.45, 0.3, 0.05), Vector3(1.2, 1.3, counter_z + 0.1), Mats.emissive("#0b1520", 0.4), false)
	var clerk := Person.new().setup(Person.random_colors(rng))
	clerk.position = Vector3(0, 0, -d / 2.0 + 1.5)
	n.add_child(clerk)
	var prompt := "Hablar con el asesor de %s" % def.get("name", "") if def.get("items", []).is_empty() else "Comprar en %s" % def.get("name", "")
	Interactable.create(n, Vector3(0, 0, counter_z + 1.2), prompt, func(): on_shop.call(def), 1.8)

	match str(def.get("style", "shelves")):
		"tables":
			_tables(n, w, d, rng)
		"bank":
			_bank(n, city, w, d)
		"books":
			_shelves(n, w, d, rng, true)
		"tech":
			_tech(n, w, d)
		_:
			_shelves(n, w, d, rng, false)

	var door_pos := door_point(n, lot)
	var inward := n.transform.basis * Vector3(0, 0, -1)
	city.businesses[def["id"]] = {
		"def": def,
		"door": door_pos,
		"inside": _to_world(n, Vector3(0, 0, d / 2.0 - 2.0)),
		"look_yaw": atan2(-inward.x, -inward.z),
	}
	city.add_spot(str(def["id"]), door_pos)
	city.add_shape(lot["x"] - w / 2.0, lot["z"] - d / 2.0, lot["x"] + w / 2.0, lot["z"] + d / 2.0, accent, str(def.get("type", "")))
	return n


## Estanterías laterales con productos de colores (MultiMesh con color por instancia).
static func _shelves(n: Node3D, w: float, d: float, rng: RandomNumberGenerator, books: bool) -> void:
	var shelf_mat := Mats.color("#7a5230" if books else "#e8e8e8", 0.7)
	var length := d - 6.0
	var zc := 0.8
	var xs := [-w / 2.0 + WALL_T + 0.35, w / 2.0 - WALL_T - 0.35, -2.4, 2.4]
	var heights := [2.1, 2.1, 1.5, 1.5]
	var widths := [0.6, 0.6, 0.9, 0.9]
	var xforms: Array = []
	var colors: Array = []
	for i in xs.size():
		var x: float = xs[i]
		var sh: float = heights[i]
		var sw: float = widths[i]
		var len_i := length if i < 2 else length * 0.55
		Geo.box(n, Vector3(sw, sh, len_i), Vector3(x, sh / 2.0, zc), shelf_mat)
		var levels := [0.55, 1.05, 1.55] if sh > 2.0 else [0.55, 1.05]
		for y in levels:
			for k in int(len_i / 0.35):
				if rng.randf() < 0.15:
					continue
				var size := Vector3(0.18, rng.randf_range(0.18, 0.4), 0.26) if books else Vector3(0.26, rng.randf_range(0.18, 0.34), 0.24)
				var pz := zc - len_i / 2.0 + 0.2 + k * 0.35
				for side in [-1.0, 1.0]:
					if i < 2 and side * x > 0:
						continue  # estantes de pared: solo cara interior
					var px: float = x + side * (sw / 2.0)
					var b := Basis.from_scale(size)
					xforms.append(Transform3D(b, Vector3(px, float(y) + size.y / 2.0, pz)))
					colors.append(Color.from_hsv(rng.randf(), rng.randf_range(0.4, 0.85), rng.randf_range(0.55, 0.95)))
	_colored_multimesh(n, xforms, colors)


static func _colored_multimesh(n: Node3D, xforms: Array, colors: Array) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Geo.box_mesh(Vector3.ONE)
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.6
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	n.add_child(mmi)


## Mesas y sillas (cafetería, panadería, restaurante) y vitrina refrigerada.
static func _tables(n: Node3D, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var wood := Mats.ground("wood")
	var metal := Mats.color("#3d434b", 0.4, 0.6)
	var chair := Mats.color("#2f2f2f", 0.7)
	var spots := [Vector3(-w / 4.0, 0, 1.0), Vector3(w / 4.0, 0, 1.0), Vector3(-w / 4.0, 0, d / 2.0 - 2.6), Vector3(w / 4.0, 0, d / 2.0 - 2.6)]
	for p in spots:
		Geo.mesh(n, Geo.cylinder_mesh(0.55, 0.55, 0.05, 16), p + Vector3(0, 0.75, 0), wood)
		Geo.mesh(n, Geo.cylinder_mesh(0.05, 0.05, 0.75, 8), p + Vector3(0, 0.375, 0), metal)
		Geo.add_cylinder_collider(n, 0.6, 0.8, p + Vector3(0, 0.4, 0))
		for side in [-1.0, 1.0]:
			Geo.box(n, Vector3(0.45, 0.45, 0.45), p + Vector3(side * 0.95, 0.225, 0), chair)
			Geo.box(n, Vector3(0.08, 0.5, 0.45), p + Vector3(side * 1.18, 0.7, 0), chair, false)
		# Taza de café sobre la mesa
		if rng.randf() < 0.7:
			Geo.mesh(n, Geo.cylinder_mesh(0.05, 0.04, 0.1, 8), p + Vector3(0.15, 0.82, 0.1), Mats.color("#f5f5f5", 0.4))
	# Vitrina de postres junto al mostrador
	Geo.box(n, Vector3(1.6, 0.9, 0.7), Vector3(-3.4, 0.45, -d / 2.0 + 2.6), Mats.color("#d9d4c7", 0.6))
	Geo.box(n, Vector3(1.6, 0.5, 0.7), Vector3(-3.4, 1.15, -d / 2.0 + 2.6), Mats.glass("#d8f3ff", 0.35), false, false)
	Geo.box(n, Vector3(1.6, 0.06, 0.7), Vector3(-3.4, 1.42, -d / 2.0 + 2.6), Mats.emissive("#fff3d6", 1.2), false, false)


## Banco: ventanillas con vidrio, sala de espera y cajero automático en la fachada.
static func _bank(n: Node3D, city: CityData, w: float, d: float) -> void:
	var cz := -d / 2.0 + 2.6
	Geo.box(n, Vector3(w - 2.0, 1.05, 0.6), Vector3(0, 0.525, cz), Mats.color("#cfd6dd", 0.5))
	Geo.box(n, Vector3(w - 2.0, 1.1, 0.04), Vector3(0, 1.65, cz), Mats.glass("#cdeeff", 0.3), false, false)
	var chair := Mats.color("#1f3a68", 0.6)
	for i in 4:
		Geo.box(n, Vector3(0.5, 0.45, 0.5), Vector3(-1.8 + i * 1.2, 0.225, 1.2), chair)
	# Cajero automático exterior (lugar de eventos: skimmer)
	var atm_local := Vector3(w / 2.0 - 2.2, 0.0, d / 2.0 + 0.3)
	Geo.box(n, Vector3(0.9, 1.7, 0.5), atm_local + Vector3(0, 0.85, 0), Mats.color("#2b2f3a", 0.4, 0.4))
	Geo.box(n, Vector3(0.5, 0.35, 0.03), atm_local + Vector3(0, 1.35, 0.26), Mats.emissive("#00a5c8", 1.0), false, false)
	Geo.label(n, "CAJERO 24H", atm_local + Vector3(0, 1.85, 0.26), 32, Color.WHITE, 0.006)
	city.add_spot("bank_atm", _to_world(n, atm_local + Vector3(0, 0, 1.0)))


## Tienda de tecnología: mesas de exhibición con portátiles encendidos.
static func _tech(n: Node3D, w: float, d: float) -> void:
	var table := Mats.color("#f2f2f2", 0.4)
	var screen := Mats.emissive("#3fb6ff", 1.4)
	var body := Mats.color("#9aa1a9", 0.3, 0.6)
	for p in [Vector3(-w / 4.0, 0, 0.5), Vector3(w / 4.0, 0, 0.5), Vector3(0, 0, d / 2.0 - 3.0)]:
		Geo.box(n, Vector3(2.6, 0.9, 1.2), p + Vector3(0, 0.45, 0), table)
		for k in 3:
			var lp: Vector3 = p + Vector3(-0.8 + k * 0.8, 0.92, 0)
			Geo.box(n, Vector3(0.5, 0.02, 0.35), lp, body, false, false)
			var s := Geo.box(n, Vector3(0.5, 0.32, 0.02), lp + Vector3(0, 0.16, -0.17), screen, false, false)
			s.rotation.x = -0.25
