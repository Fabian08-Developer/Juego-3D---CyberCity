class_name Geo
extends RefCounted
## Atajos para crear mallas, colisiones y textos 3D.

static var _mesh_cache := {}


static func box_mesh(size: Vector3) -> BoxMesh:
	var key := "box|%s" % size
	if not _mesh_cache.has(key):
		var m := BoxMesh.new()
		m.size = size
		_mesh_cache[key] = m
	return _mesh_cache[key]


static func cylinder_mesh(top: float, bottom: float, height: float, segments := 12) -> CylinderMesh:
	var key := "cyl|%s|%s|%s|%d" % [top, bottom, height, segments]
	if not _mesh_cache.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = segments
		m.rings = 1
		_mesh_cache[key] = m
	return _mesh_cache[key]


static func sphere_mesh(radius: float, segments := 10, rings := 6) -> SphereMesh:
	var key := "sph|%s|%d|%d" % [radius, segments, rings]
	if not _mesh_cache.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = segments
		m.rings = rings
		_mesh_cache[key] = m
	return _mesh_cache[key]


static func mesh(parent: Node, m: Mesh, pos: Vector3, mat: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Caja visible; con `collide` añade un StaticBody3D con la misma forma.
static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, collide := true, shadow := true) -> MeshInstance3D:
	var mi := mesh(parent, box_mesh(size), pos, mat, shadow)
	if collide:
		add_box_collider(mi, size, Vector3.ZERO)
	return mi


static func add_box_collider(parent: Node, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.position = pos
	body.add_child(cs)
	parent.add_child(body)
	return body


static func add_cylinder_collider(parent: Node, radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.position = pos
	body.add_child(cs)
	parent.add_child(body)
	return body


static func label(parent: Node, text: String, pos: Vector3, font_size := 64, color := Color.WHITE, pixel := 0.01, billboard := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = int(font_size / 8.0)
	l.outline_modulate = Color(0, 0, 0, 0.75)
	l.position = pos
	l.double_sided = false
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	return l
