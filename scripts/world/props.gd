class_name Props
extends RefCounted
## Mobiliario urbano. Los elementos repetidos se envían al Batcher (MultiMesh).

## Árbol con tronco y varias copas; `variant` cambia el tono y la forma.
static func tree(batch: Batcher, parent: Node3D, pos: Vector3, scale := 1.0, variant := 0) -> void:
	var trunk_mat := Mats.color("#5e4128", 0.95)
	var leaves := ["#2f7d32", "#3c9a3f", "#4f8f2a", "#2e6b3a"]
	var leaf_mat := Mats.color(leaves[variant % leaves.size()], 0.95)
	var leaf_light := Mats.color(Color(leaves[variant % leaves.size()]).lightened(0.18).to_html(false), 0.95)
	var s := Vector3.ONE * scale
	batch.add(Geo.cylinder_mesh(0.12, 0.22, 2.6, 8), trunk_mat, Transform3D(Basis.from_scale(s), pos + Vector3(0, 1.3, 0) * scale))
	var rot := Basis(Vector3.UP, float(variant) * 1.7 + pos.x * 0.37)
	var clumps := [
		[Vector3(0, 3.1, 0), 1.45, leaf_mat],
		[Vector3(0.75, 3.6, -0.35), 1.05, leaf_light],
		[Vector3(-0.7, 3.45, 0.45), 1.0, leaf_mat],
		[Vector3(0.1, 4.25, 0.15), 0.85, leaf_light],
		[Vector3(-0.2, 3.0, -0.75), 0.8, leaf_mat],
	]
	for c in clumps:
		var r: float = c[1]
		var b := rot.scaled(Vector3(r, r * 0.9, r) * scale)
		batch.add(Geo.sphere_mesh(1.0, 9, 6), c[2], Transform3D(b, pos + rot * (c[0] as Vector3) * scale))
	Geo.add_cylinder_collider(parent, 0.25 * scale, 2.4 * scale, pos + Vector3(0, 1.2 * scale, 0))


## Arbusto bajo (sin colisión).
static func bush(batch: Batcher, pos: Vector3, scale := 1.0, variant := 0) -> void:
	var mats := [Mats.color("#2f6b2f", 0.95), Mats.color("#3f7f34", 0.95), Mats.color("#356b45", 0.95)]
	var m: Material = mats[variant % mats.size()]
	var rot := Basis(Vector3.UP, pos.z * 0.71 + pos.x * 0.29)
	for o in [Vector3(0, 0.35, 0), Vector3(0.45, 0.3, 0.1), Vector3(-0.4, 0.28, -0.1), Vector3(0.05, 0.3, 0.42)]:
		batch.add(Geo.sphere_mesh(0.45, 8, 5), m, Transform3D(rot.scaled(Vector3.ONE * scale), pos + rot * (o as Vector3) * scale))


## Jardinera con flores de colores.
static func flower_bed(batch: Batcher, parent: Node3D, center: Vector3, size: Vector2, rng: RandomNumberGenerator) -> void:
	var border := Mats.color("#8d8578", 0.9)
	var soil := Mats.color("#4a3626", 1.0)
	Geo.box(parent, Vector3(size.x, 0.3, size.y), center + Vector3(0, 0.15, 0), border, true)
	Geo.box(parent, Vector3(size.x - 0.3, 0.05, size.y - 0.3), center + Vector3(0, 0.31, 0), soil, false, false)
	var petals := [Mats.color("#e63946", 0.8), Mats.color("#f4a261", 0.8), Mats.color("#ffd166", 0.8), Mats.color("#c77dff", 0.8), Mats.color("#ffffff", 0.8)]
	var stem := Mats.color("#3f7f34", 0.9)
	var count := int(size.x * size.y * 3.0)
	for i in count:
		var p := center + Vector3(rng.randf_range(-size.x / 2.0 + 0.3, size.x / 2.0 - 0.3), 0.33, rng.randf_range(-size.y / 2.0 + 0.3, size.y / 2.0 - 0.3))
		batch.add(Geo.cylinder_mesh(0.015, 0.02, 0.3, 5), stem, Transform3D(Basis(), p + Vector3(0, 0.15, 0)), false)
		batch.add(Geo.sphere_mesh(0.1, 8, 4), stem, Transform3D(Basis.from_scale(Vector3(1.4, 0.5, 1.4)), p + Vector3(0, 0.04, 0)), false)
		batch.add(Geo.sphere_mesh(0.085, 7, 4), petals[rng.randi_range(0, petals.size() - 1)], Transform3D(Basis.from_scale(Vector3(1.2, 0.7, 1.2)), p + Vector3(0, 0.32, 0)), false)


## Farola orientada hacia `facing` (ángulo Y). Añade una luz nocturna.
static func street_light(batch: Batcher, parent: Node3D, city: CityData, pos: Vector3, facing: float, lamp_mat: Material) -> void:
	var metal := Mats.color("#3d434b", 0.4, 0.6)
	var b := Basis(Vector3.UP, facing)
	batch.add(Geo.cylinder_mesh(0.08, 0.11, 5.6, 8), metal, Transform3D(b, pos + Vector3(0, 2.8, 0)))
	batch.add(Geo.box_mesh(Vector3(0.08, 0.08, 1.5)), metal, Transform3D(b, pos + b * Vector3(0, 5.5, 0.65)))
	batch.add(Geo.box_mesh(Vector3(0.5, 0.14, 0.32)), lamp_mat, Transform3D(b, pos + b * Vector3(0, 5.4, 1.3)), false)
	var light := OmniLight3D.new()
	light.position = pos + b * Vector3(0, 5.1, 1.3)
	light.omni_range = 14.0
	light.light_energy = 2.6
	light.light_color = Color("#ffd9a0")
	light.visible = false
	parent.add_child(light)
	city.night_lights.append(light)
	Geo.add_cylinder_collider(parent, 0.15, 3.0, pos + Vector3(0, 1.5, 0))


static func bench(batch: Batcher, parent: Node3D, pos: Vector3, facing: float) -> void:
	var wood := Mats.ground("wood")
	var metal := Mats.color("#3d434b", 0.4, 0.6)
	var b := Basis(Vector3.UP, facing)
	batch.add(Geo.box_mesh(Vector3(1.8, 0.08, 0.5)), wood, Transform3D(b, pos + b * Vector3(0, 0.45, 0)))
	batch.add(Geo.box_mesh(Vector3(1.8, 0.45, 0.06)), wood, Transform3D(b, pos + b * Vector3(0, 0.75, -0.22)))
	for x in [-0.75, 0.75]:
		batch.add(Geo.box_mesh(Vector3(0.06, 0.45, 0.45)), metal, Transform3D(b, pos + b * Vector3(x, 0.22, 0)))
	var size := Vector3(1.8, 0.9, 0.5)
	if absf(sin(facing)) > 0.7:
		size = Vector3(0.5, 0.9, 1.8)
	Geo.add_box_collider(parent, size, pos + Vector3(0, 0.45, 0))


static func trash_bin(batch: Batcher, parent: Node3D, pos: Vector3) -> void:
	batch.add(Geo.cylinder_mesh(0.28, 0.24, 0.9, 10), Mats.color("#2f6f4f", 0.6), Transform3D(Basis(), pos + Vector3(0, 0.45, 0)))
	batch.add(Geo.cylinder_mesh(0.3, 0.3, 0.06, 10), Mats.color("#24563d", 0.6), Transform3D(Basis(), pos + Vector3(0, 0.92, 0)))
	Geo.add_cylinder_collider(parent, 0.3, 1.0, pos + Vector3(0, 0.5, 0))


static func hydrant(batch: Batcher, parent: Node3D, pos: Vector3) -> void:
	var red := Mats.color("#c0392b", 0.5)
	batch.add(Geo.cylinder_mesh(0.14, 0.16, 0.6, 10), red, Transform3D(Basis(), pos + Vector3(0, 0.3, 0)))
	batch.add(Geo.sphere_mesh(0.15, 10, 5), red, Transform3D(Basis(), pos + Vector3(0, 0.62, 0)))
	Geo.add_cylinder_collider(parent, 0.18, 0.8, pos + Vector3(0, 0.4, 0))


## Fuente con chorro de partículas.
static func fountain(parent: Node3D, pos: Vector3) -> void:
	var stone := Mats.color("#b9b5ab", 0.8)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.25, 0.6, 0.85, 0.8)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic = 0.3
	Geo.mesh(parent, Geo.cylinder_mesh(3.2, 3.4, 0.6, 28), pos + Vector3(0, 0.3, 0), stone)
	Geo.mesh(parent, Geo.cylinder_mesh(2.95, 2.95, 0.1, 28), pos + Vector3(0, 0.52, 0), water, false)
	Geo.mesh(parent, Geo.cylinder_mesh(0.3, 0.45, 2.0, 12), pos + Vector3(0, 1.2, 0), stone)
	Geo.mesh(parent, Geo.cylinder_mesh(1.1, 0.6, 0.3, 18), pos + Vector3(0, 2.2, 0), stone)
	Geo.add_cylinder_collider(parent, 3.3, 1.2, pos + Vector3(0, 0.6, 0))

	var particles := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 3.5
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	particles.process_material = pm
	var drop := SphereMesh.new()
	drop.radius = 0.05
	drop.height = 0.1
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = water
	particles.draw_pass_1 = drop
	particles.amount = 220
	particles.lifetime = 1.0
	particles.position = pos + Vector3(0, 2.4, 0)
	parent.add_child(particles)


## Parada de bus con techo de vidrio y banca.
static func bus_stop(batch: Batcher, parent: Node3D, pos: Vector3, facing: float) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = facing
	parent.add_child(node)
	var metal := Mats.color("#3d434b", 0.4, 0.6)
	for x in [-1.8, 1.8]:
		Geo.box(node, Vector3(0.1, 2.6, 0.1), Vector3(x, 1.3, -0.6), metal, true)
	Geo.box(node, Vector3(4.0, 0.08, 1.6), Vector3(0, 2.62, 0), Mats.glass("#9fd3e6", 0.45), false)
	Geo.box(node, Vector3(3.6, 2.2, 0.05), Vector3(0, 1.4, -0.65), Mats.glass("#9fd3e6", 0.3), true, false)
	Geo.box(node, Vector3(1.2, 1.8, 0.1), Vector3(-2.4, 1.2, -0.6), Mats.emissive("#00a5c8", 0.6), true)
	Geo.label(node, "PARADA", Vector3(-2.4, 1.6, -0.54), 48, Color.WHITE, 0.008)
	Geo.label(node, "Ruta C1", Vector3(-2.4, 1.15, -0.54), 32, Color.WHITE, 0.008)
	bench(batch, parent, pos + Basis(Vector3.UP, facing) * Vector3(0, 0, -0.2), facing)
