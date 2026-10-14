class_name Person
extends Node3D
## Personaje estilizado (jugador y NPC) con proporciones redondeadas, peinados y estilos de ropa.
## Mira hacia +Z. Las extremidades cuelgan de pivotes (hombros y caderas) para animarlas.

const SKINS := ["#f1c27d", "#e0ac69", "#c68642", "#8d5524", "#ffdbac", "#d4a373"]
const SHIRTS := ["#3b82f6", "#ef4444", "#10b981", "#f59e0b", "#8b5cf6", "#ec4899", "#64748b", "#f8fafc", "#0ea5e9", "#14b8a6"]
const PANTS := ["#1f2937", "#374151", "#1e3a8a", "#78350f", "#111827", "#4b5563", "#3f6212"]
const HAIRS := ["#1b1b1b", "#3b2412", "#6b4423", "#c9a36b", "#7a7a7a", "#a0522d"]
const STYLES := ["casual", "casual", "formal", "skirt", "hoodie"]
const HAIR_STYLES := ["short", "short", "long", "bun", "cap"]

static var _mesh_cache := {}

var leg_l := Node3D.new()
var leg_r := Node3D.new()
var arm_l := Node3D.new()
var arm_r := Node3D.new()
var _phase := randf() * TAU
var _meshes: Array = []


static func random_colors(rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	return {
		"skin": SKINS[r.randi_range(0, SKINS.size() - 1)],
		"shirt": SHIRTS[r.randi_range(0, SHIRTS.size() - 1)],
		"pants": PANTS[r.randi_range(0, PANTS.size() - 1)],
		"hair": HAIRS[r.randi_range(0, HAIRS.size() - 1)],
		"style": STYLES[r.randi_range(0, STYLES.size() - 1)],
		"hair_style": HAIR_STYLES[r.randi_range(0, HAIR_STYLES.size() - 1)],
	}


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var key := "cap|%.3f|%.3f" % [radius, height]
	if not _mesh_cache.has(key):
		var m := CapsuleMesh.new()
		m.radius = radius
		m.height = height
		m.radial_segments = 12
		m.rings = 4
		_mesh_cache[key] = m
	return _mesh_cache[key]


func setup(c: Dictionary, badge := false) -> Person:
	var style: String = c.get("style", "casual")
	var hair_style: String = c.get("hair_style", "short")
	var skin: String = c["skin"]
	var shirt: String = c["shirt"]
	var pants: String = c["pants"]
	var hair: String = c["hair"]

	# Torso y cadera
	_add(self, _capsule(0.2, 0.7), Vector3(0, 1.22, 0), shirt, Vector3(1.25, 1.0, 0.8))
	_add(self, _capsule(0.17, 0.42), Vector3(0, 0.95, 0), pants if style != "skirt" else shirt, Vector3(1.3, 1.0, 0.85))
	if style == "formal":
		_add(self, Geo.box_mesh(Vector3(0.1, 0.42, 0.02)), Vector3(0, 1.3, 0.175), "#f8fafc", Vector3.ONE)
		_add(self, Geo.box_mesh(Vector3(0.05, 0.34, 0.02)), Vector3(0, 1.27, 0.19), "#7f1d1d", Vector3.ONE)
		_add(self, _capsule(0.215, 0.72), Vector3(0, 1.22, -0.01), pants, Vector3(1.27, 1.0, 0.78))
	elif style == "hoodie":
		_add(self, _capsule(0.13, 0.3), Vector3(0, 1.52, -0.1), shirt, Vector3(1.3, 0.8, 0.8))
	elif style == "skirt":
		var skirt := CylinderMesh.new()
		skirt.top_radius = 0.2
		skirt.bottom_radius = 0.3
		skirt.height = 0.42
		skirt.radial_segments = 14
		_add(self, skirt, Vector3(0, 0.78, 0), pants, Vector3(1.0, 1.0, 0.8))
	if badge:
		_add(self, Geo.box_mesh(Vector3(0.08, 0.11, 0.02)), Vector3(0.11, 1.18, 0.17), "#00e5ff", Vector3.ONE)
		_add(self, Geo.box_mesh(Vector3(0.015, 0.3, 0.015)), Vector3(0.06, 1.38, 0.16), "#0f172a", Vector3.ONE)

	# Cuello y cabeza
	_add(self, Geo.cylinder_mesh(0.06, 0.07, 0.12, 10), Vector3(0, 1.6, 0), skin, Vector3.ONE)
	_add(self, Geo.sphere_mesh(0.15, 16, 10), Vector3(0, 1.77, 0), skin, Vector3(0.95, 1.1, 1.0))
	for x in [-0.055, 0.055]:
		_add(self, Geo.sphere_mesh(0.02, 8, 4), Vector3(x, 1.8, 0.135), "#111111", Vector3.ONE)
	_add(self, Geo.sphere_mesh(0.025, 8, 4), Vector3(0, 1.75, 0.15), skin, Vector3(0.8, 1.0, 1.0))
	match hair_style:
		"long":
			_add(self, Geo.sphere_mesh(0.16, 14, 8), Vector3(0, 1.84, -0.02), hair, Vector3(1.0, 0.75, 1.02))
			_add(self, Geo.box_mesh(Vector3(0.3, 0.32, 0.08)), Vector3(0, 1.66, -0.12), hair, Vector3.ONE)
		"bun":
			_add(self, Geo.sphere_mesh(0.16, 14, 8), Vector3(0, 1.84, -0.02), hair, Vector3(1.0, 0.72, 1.02))
			_add(self, Geo.sphere_mesh(0.07, 10, 6), Vector3(0, 1.93, -0.12), hair, Vector3.ONE)
		"cap":
			_add(self, Geo.sphere_mesh(0.16, 14, 8), Vector3(0, 1.85, 0), shirt, Vector3(1.0, 0.65, 1.02))
			_add(self, Geo.box_mesh(Vector3(0.24, 0.025, 0.14)), Vector3(0, 1.85, 0.17), shirt, Vector3.ONE)
		_:
			_add(self, Geo.sphere_mesh(0.16, 14, 8), Vector3(0, 1.85, -0.015), hair, Vector3(1.0, 0.68, 1.02))

	# Extremidades
	var sleeve := pants if style == "formal" else shirt
	_limb(arm_l, Vector3(-0.29, 1.5, 0), 0.055, 0.62, sleeve, skin, false)
	_limb(arm_r, Vector3(0.29, 1.5, 0), 0.055, 0.62, sleeve, skin, false)
	var leg_color := skin if style == "skirt" else pants
	_limb(leg_l, Vector3(-0.11, 0.9, 0), 0.075, 0.86, leg_color, "#222222", true)
	_limb(leg_r, Vector3(0.11, 0.9, 0), 0.075, 0.86, leg_color, "#222222", true)
	return self


func _add(parent: Node3D, m: Mesh, pos: Vector3, hex: String, scale_v: Vector3) -> MeshInstance3D:
	var mi := Geo.mesh(parent, m, pos, Mats.color(hex, 0.75), true)
	mi.scale = scale_v
	_meshes.append(mi)
	return mi


func _limb(pivot: Node3D, pos: Vector3, radius: float, length: float, hex: String, end_hex: String, foot: bool) -> void:
	pivot.position = pos
	add_child(pivot)
	_add(pivot, _capsule(radius, length), Vector3(0, -length / 2.0 + 0.02, 0), hex, Vector3.ONE)
	if foot:
		_add(pivot, _capsule(0.06, 0.26), Vector3(0, -length + 0.04, 0.06), end_hex, Vector3.ONE).rotation.x = PI / 2.0
	else:
		_add(pivot, Geo.sphere_mesh(0.055, 10, 6), Vector3(0, -length + 0.01, 0), end_hex, Vector3.ONE)


## speed: velocidad horizontal en m/s (0 = reposo).
func animate(delta: float, speed: float) -> void:
	if speed > 0.1:
		_phase += delta * (4.0 + speed * 1.3)
		var amp := minf(0.85, 0.35 + speed * 0.08)
		var s := sin(_phase) * amp
		leg_l.rotation.x = s
		leg_r.rotation.x = -s
		arm_l.rotation.x = -s * 0.8
		arm_r.rotation.x = s * 0.8
	else:
		var k := minf(1.0, delta * 10.0)
		for p in [leg_l, leg_r, arm_l, arm_r]:
			p.rotation.x = lerpf(p.rotation.x, 0.0, k)


## Pose de trabajo frente al teclado.
func set_typing(t: float) -> void:
	arm_l.rotation.x = -1.2 + sin(t * 14.0) * 0.08
	arm_r.rotation.x = -1.2 + cos(t * 13.0) * 0.08


## En primera persona el cuerpo sigue proyectando sombra pero no se ve.
func set_shadow_only(on: bool) -> void:
	for mi in _meshes:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
