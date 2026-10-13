class_name Person
extends Node3D
## Personaje low-poly articulado (jugador y NPC). Mira hacia +Z.

const SKINS := ["#f1c27d", "#e0ac69", "#c68642", "#8d5524", "#ffdbac"]
const SHIRTS := ["#3b82f6", "#ef4444", "#10b981", "#f59e0b", "#8b5cf6", "#ec4899", "#64748b", "#f8fafc", "#0ea5e9"]
const PANTS := ["#1f2937", "#374151", "#1e3a8a", "#78350f", "#111827", "#4b5563"]
const HAIRS := ["#1b1b1b", "#3b2412", "#6b4423", "#c9a36b", "#7a7a7a"]

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
	}


func setup(colors: Dictionary, badge := false) -> Person:
	_part(self, Vector3(0.5, 0.65, 0.28), Vector3(0, 1.2, 0), colors["shirt"])
	_part(self, Vector3(0.3, 0.32, 0.3), Vector3(0, 1.72, 0), colors["skin"])
	_part(self, Vector3(0.32, 0.1, 0.32), Vector3(0, 1.9, 0), colors["hair"])
	_part(self, Vector3(0.32, 0.18, 0.06), Vector3(0, 1.8, -0.15), colors["hair"])
	_part(self, Vector3(0.2, 0.05, 0.02), Vector3(0, 1.75, 0.16), "#111111")
	if badge:
		_part(self, Vector3(0.1, 0.13, 0.02), Vector3(0.14, 1.32, 0.15), "#00e5ff")
	_limb(leg_l, Vector3(-0.13, 0.88, 0), 0.88, 0.2, colors["pants"], true)
	_limb(leg_r, Vector3(0.13, 0.88, 0), 0.88, 0.2, colors["pants"], true)
	_limb(arm_l, Vector3(-0.33, 1.5, 0), 0.62, 0.15, colors["shirt"], false)
	_limb(arm_r, Vector3(0.33, 1.5, 0), 0.62, 0.15, colors["shirt"], false)
	_part(arm_l, Vector3(0.13, 0.12, 0.13), Vector3(0, -0.68, 0), colors["skin"])
	_part(arm_r, Vector3(0.13, 0.12, 0.13), Vector3(0, -0.68, 0), colors["skin"])
	return self


func _part(parent: Node3D, size: Vector3, pos: Vector3, hex: String) -> void:
	var mi := Geo.mesh(parent, Geo.box_mesh(size), pos, Mats.color(hex, 0.8), true)
	_meshes.append(mi)


func _limb(pivot: Node3D, pos: Vector3, length: float, width: float, hex: String, foot: bool) -> void:
	pivot.position = pos
	add_child(pivot)
	_part(pivot, Vector3(width, length, width), Vector3(0, -length / 2.0, 0), hex)
	if foot:
		_part(pivot, Vector3(width + 0.02, 0.08, width + 0.12), Vector3(0, -length + 0.04, 0.05), "#222222")


## speed: velocidad horizontal en m/s (0 = reposo).
func animate(delta: float, speed: float) -> void:
	if speed > 0.1:
		_phase += delta * (4.0 + speed * 1.3)
		var amp := minf(0.9, 0.35 + speed * 0.08)
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
