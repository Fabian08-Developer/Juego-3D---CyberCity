class_name CityBuilder
extends RefCounted
## Construye la ciudad: suelo, calles, manzanas, parque, negocios, sede y mobiliario.
##
## Distribución (3x3 manzanas):
##   [ residencial + ferretería ] [ CyberShield ] [ residencial ]
##   [ calle comercial (4)      ] [   Parque    ] [ calle comercial (4) ]
##   [ residencial              ] [ tu casa     ] [ residencial ]

static func load_json(path: String) -> Variant:
	var txt := FileAccess.get_file_as_string(path)
	if txt.is_empty():
		push_error("No se pudo leer " + path)
		return null
	return JSON.parse_string(txt)


static func build(root: Node3D, hooks: Dictionary) -> CityData:
	var city := CityData.new()
	var batch := Batcher.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var lamp_mat := Mats.night_emissive("#fff6d5", 0.3, 6.0)

	_ground(root, batch)
	_roads(root, batch)

	var data = load_json("res://data/businesses.json")
	var queue: Array = data if data is Array else []
	for i in Config.BLOCKS:
		for j in Config.BLOCKS:
			var cx := Config.block_center(i)
			var cz := Config.block_center(j)
			_block_slab(root, cx, cz)
			_block_street_lights(batch, root, city, cx, cz, lamp_mat)
			if i == 1 and j == 1:
				_park(root, batch, city, cx, cz, lamp_mat)
				continue
			if i == 1 and j == 0:
				var hq := HQ.new()
				hq.name = "CyberShield"
				root.add_child(hq)
				hq.build(city, hooks)
				continue
			var quota := 4 if j == 1 else (1 if i == 0 and j == 0 else 0)
			var lots := _block_lots(cx, cz)
			if cz < 0:
				lots.reverse()  # primero las parcelas que miran hacia el centro
			for lot in lots:
				if quota > 0 and not queue.is_empty():
					quota -= 1
					Buildings.business(root, city, lot, queue.pop_front(), hooks["on_business"])
				elif i == 1 and j == 2 and lot["facing"] == "N" and float(lot["x"]) < 0.0:
					var home := Buildings.filler(root, city, lot, rng, "Casa", Color("#2fae6a"))
					Interactable.create(home, Vector3(0, 0, float(lot["d"]) / 2.0 + 1.3), "Tu apartamento (descansar / dormir)", hooks["on_home"], 2.0)
					Geo.label(home, "Residencias Los Andaquíes", Vector3(0, 3.4, float(lot["d"]) / 2.0 + 0.05), 40, Color.WHITE, 0.008)
					city.markers["home"] = Buildings.door_point(home, lot, 1.6)
				else:
					Buildings.filler(root, city, lot, rng)
			_block_props(batch, root, city, cx, cz, rng)

	_outskirts(root, batch)
	batch.flush(root)
	return city


static func _ground(root: Node3D, batch: Batcher) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	var ground := Geo.mesh(root, plane, Vector3(0, -0.01, 0), Mats.ground("grass"), false)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Geo.add_box_collider(root, Vector3(900, 2, 900), Vector3(0, -1, 0))
	# Colinas lejanas (Florencia está rodeada de montañas)
	var hill := Mats.color("#3f6e34", 1.0)
	for k in 14:
		var a := k * TAU / 14.0 + 0.2
		var r := 330.0 + fmod(k * 37.0, 60.0)
		var s := 70.0 + fmod(k * 53.0, 50.0)
		batch.add(Geo.sphere_mesh(1.0, 16, 8), hill, Transform3D(Basis.from_scale(Vector3(s * 1.6, s * 0.55, s)), Vector3(cos(a) * r, -s * 0.15, sin(a) * r)), false)


static func _roads(root: Node3D, batch: Batcher) -> void:
	var length := Config.SIZE + 120.0
	var mat := Mats.road().duplicate() as StandardMaterial3D
	mat.uv1_scale = Vector3(1, length / 16.0, 1)
	var plane := PlaneMesh.new()
	plane.size = Vector2(Config.ROAD, length)
	for k in Config.BLOCKS + 1:
		var c := Config.road_center(k)
		var v := Geo.mesh(root, plane, Vector3(c, 0.01, 0), mat, false)
		v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var h := Geo.mesh(root, plane, Vector3(0, 0.014, c), mat, false)
		h.rotation.y = PI / 2.0
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Intersecciones lisas y pasos de cebra
	var square := PlaneMesh.new()
	square.size = Vector2(Config.ROAD, Config.ROAD)
	var stripe := PlaneMesh.new()
	stripe.size = Vector2(0.6, 2.6)
	var asphalt := Mats.ground("asphalt")
	var white := Mats.color("#e9e9e9", 0.8)
	var off := Config.ROAD / 2.0 + 1.5
	for a in Config.BLOCKS + 1:
		for b in Config.BLOCKS + 1:
			var x := Config.road_center(a)
			var z := Config.road_center(b)
			batch.add(square, asphalt, Transform3D(Basis(), Vector3(x, 0.018, z)), false)
			for s in range(-4, 5):
				var o := s * 1.25
				batch.add(stripe, white, Transform3D(Basis(), Vector3(x + o, 0.022, z - off)), false)
				batch.add(stripe, white, Transform3D(Basis(), Vector3(x + o, 0.022, z + off)), false)
				var rot := Basis(Vector3.UP, PI / 2.0)
				batch.add(stripe, white, Transform3D(rot, Vector3(x - off, 0.022, z + o)), false)
				batch.add(stripe, white, Transform3D(rot, Vector3(x + off, 0.022, z + o)), false)


static func _block_slab(root: Node3D, cx: float, cz: float) -> void:
	Geo.box(root, Vector3(Config.BLOCK, Config.SIDEWALK_H, Config.BLOCK), Vector3(cx, Config.SIDEWALK_H / 2.0, cz), Mats.ground("sidewalk"), true, false)
	# Bordillo
	var curb := Mats.color("#8f8c86", 0.9)
	var h := Config.BLOCK / 2.0
	for side in [-1.0, 1.0]:
		Geo.box(root, Vector3(Config.BLOCK, 0.16, 0.25), Vector3(cx, 0.08, cz + side * (h - 0.125)), curb, false, false)
		Geo.box(root, Vector3(0.25, 0.16, Config.BLOCK), Vector3(cx + side * (h - 0.125), 0.08, cz), curb, false, false)


## Cuatro parcelas por manzana (dos al norte, dos al sur), con acera de 3 m.
static func _block_lots(cx: float, cz: float) -> Array:
	var lots := []
	for facing in ["N", "S"]:
		var z := cz + (-10.0 if facing == "N" else 10.0)
		for dx in [-9.0, 9.0]:
			lots.append({"x": cx + dx, "z": z, "w": 16.0, "d": 14.0, "facing": facing})
	return lots


static func _block_street_lights(batch: Batcher, root: Node3D, city: CityData, cx: float, cz: float, lamp_mat: Material) -> void:
	var e := Config.BLOCK / 2.0 - 0.8
	var y := Config.SIDEWALK_H
	for o in [-14.0, 0.0, 14.0]:
		Props.street_light(batch, root, city, Vector3(cx + o, y, cz - e), PI, lamp_mat)
		Props.street_light(batch, root, city, Vector3(cx + o, y, cz + e), 0.0, lamp_mat)
		Props.street_light(batch, root, city, Vector3(cx - e, y, cz + o), -PI / 2.0, lamp_mat)
		Props.street_light(batch, root, city, Vector3(cx + e, y, cz + o), PI / 2.0, lamp_mat)


static func _block_props(batch: Batcher, root: Node3D, city: CityData, cx: float, cz: float, rng: RandomNumberGenerator) -> void:
	var y := Config.SIDEWALK_H
	var e := Config.BLOCK / 2.0 - 0.9
	for dz in [-7.0, 7.0]:
		Props.tree(batch, root, Vector3(cx - e, y, cz + dz), 0.85, rng.randi_range(0, 2))
		Props.tree(batch, root, Vector3(cx + e, y, cz + dz), 0.85, rng.randi_range(0, 2))
	for dz in [-3.0, 3.0]:
		Props.bush(batch, Vector3(cx - e, y, cz + dz), 0.7, rng.randi_range(0, 2))
		Props.bush(batch, Vector3(cx + e, y, cz + dz), 0.7, rng.randi_range(0, 2))
	Props.trash_bin(batch, root, Vector3(cx - 4.5, y, cz - e))
	Props.trash_bin(batch, root, Vector3(cx + 4.5, y, cz + e))
	Props.hydrant(batch, root, Vector3(cx + e, y, cz - 3.5))
	var c := Config.BLOCK / 2.0 - 1.6
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			city.add_spot("street", Vector3(cx + sx * c, y, cz + sz * c))


static func _park(root: Node3D, batch: Batcher, city: CityData, cx: float, cz: float, lamp_mat: Material) -> void:
	var y := Config.SIDEWALK_H
	var size := Config.BLOCK - 6.0
	var grass := PlaneMesh.new()
	grass.size = Vector2(size, size)
	Geo.mesh(root, grass, Vector3(cx, y + 0.005, cz), Mats.ground("park_grass"), false)
	var path := PlaneMesh.new()
	path.size = Vector2(3.5, size)
	var pm := Mats.ground("path")
	Geo.mesh(root, path, Vector3(cx, y + 0.01, cz), pm, false)
	Geo.mesh(root, path, Vector3(cx, y + 0.011, cz), pm, false).rotation.y = PI / 2.0
	Geo.mesh(root, Geo.cylinder_mesh(7.5, 7.5, 0.02, 40), Vector3(cx, y + 0.012, cz), pm, false)
	Props.fountain(root, Vector3(cx, y, cz))
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		var p := Vector3(cx + cos(a) * 8.6, y, cz + sin(a) * 8.6)
		Props.bench(batch, root, p, atan2(cx - p.x, cz - p.z))
		city.add_spot("park_bench", p + Vector3(cos(a), 0, sin(a)) * -1.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for qx in [-1.0, 1.0]:
		for qz in [-1.0, 1.0]:
			for i in 5:
				var x: float = cx + qx * rng.randf_range(4.0, 15.5)
				var z: float = cz + qz * rng.randf_range(4.0, 15.5)
				if Vector2(x - cx, z - cz).length() < 9.5 or absf(x - cx) < 2.6 or absf(z - cz) < 2.6:
					continue
				Props.tree(batch, root, Vector3(x, y, z), rng.randf_range(0.9, 1.3), rng.randi_range(0, 2))
	for p in [Vector3(cx + 2.6, y, cz - 12), Vector3(cx - 2.6, y, cz + 12), Vector3(cx - 12, y, cz + 2.6), Vector3(cx + 12, y, cz - 2.6)]:
		Props.street_light(batch, root, city, p, 0.0, lamp_mat)
	# Jardineras con flores junto a los caminos y arbustos en el borde del parque
	var frng := RandomNumberGenerator.new()
	frng.seed = 21
	for q in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		Props.flower_bed(batch, root, Vector3(cx + q.x * 4.6, y, cz + q.y * 12.5), Vector2(2.4, 5.0), frng)
		Props.flower_bed(batch, root, Vector3(cx + q.x * 12.5, y, cz + q.y * 4.6), Vector2(5.0, 2.4), frng)
	for k in 24:
		var t := float(k) / 24.0 * TAU
		var r := size / 2.0 - 0.6
		var bp := Vector3(cx + clampf(cos(t) * r * 1.5, -r, r), y, cz + clampf(sin(t) * r * 1.5, -r, r))
		if absf(bp.x - cx) < 2.8 or absf(bp.z - cz) < 2.8:
			continue
		Props.bush(batch, bp, frng.randf_range(0.8, 1.2), k)
	Props.bus_stop(batch, root, Vector3(cx + 8, y, cz + 18.4), 0.0)
	city.add_spot("bus_stop", Vector3(cx + 8, y, cz + 19.4))
	city.add_shape(cx - size / 2.0, cz - size / 2.0, cx + size / 2.0, cz + size / 2.0, Color("#3f7f34"), "Parque")


static func _outskirts(root: Node3D, batch: Batcher) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var roads: Array = []
	for k in Config.BLOCKS + 1:
		roads.append(Config.road_center(k))
	var placed := 0
	while placed < 170:
		var a := rng.randf() * TAU
		var r := Config.HALF + 10.0 + rng.randf() * 45.0
		var x := cos(a) * r
		var z := sin(a) * r
		var on_road := false
		for c in roads:
			if absf(x - c) < 8.0 or absf(z - c) < 8.0:
				on_road = true
		if on_road:
			continue
		Props.tree(batch, root, Vector3(x, 0, z), rng.randf_range(1.0, 1.9), rng.randi_range(0, 2))
		placed += 1
