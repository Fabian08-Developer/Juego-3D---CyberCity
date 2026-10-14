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


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	# Godot considera frontal el sentido horario: se ordena el triángulo según la normal deseada.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = c
		c = tmp
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


## Extruye un perfil lateral (puntos en el plano Z-Y) a lo ancho del eje X. Ideal para carrocerías.
static func extrude(profile: PackedVector2Array, width: float) -> ArrayMesh:
	var poly := profile.duplicate()
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width / 2.0
	var tris := Geometry2D.triangulate_polygon(poly)
	for side in [-1.0, 1.0]:
		var n := Vector3(side, 0, 0)
		for i in range(0, tris.size(), 3):
			var p0 := poly[tris[i]]
			var p1 := poly[tris[i + 1]]
			var p2 := poly[tris[i + 2]]
			_tri(st, Vector3(side * hw, p0.y, p0.x), Vector3(side * hw, p1.y, p1.x), Vector3(side * hw, p2.y, p2.x), n)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var e := b - a
		var n := Vector3(0, -e.x, e.y).normalized()
		var al := Vector3(-hw, a.y, a.x)
		var ar := Vector3(hw, a.y, a.x)
		var bl := Vector3(-hw, b.y, b.x)
		var br := Vector3(hw, b.y, b.x)
		_tri(st, al, bl, br, n)
		_tri(st, al, br, ar, n)
	return st.commit()
