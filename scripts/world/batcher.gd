class_name Batcher
extends RefCounted
## Agrupa props repetidos (árboles, farolas, pasos de cebra…) en MultiMeshInstance3D:
## una sola llamada de dibujo por pareja malla/material.

var _batches := {}


func add(m: Mesh, mat: Material, xform: Transform3D, shadow := true) -> void:
	var key := "%d|%d" % [m.get_instance_id(), mat.get_instance_id()]
	if not _batches.has(key):
		_batches[key] = {"mesh": m, "mat": mat, "shadow": shadow, "xforms": []}
	_batches[key]["xforms"].append(xform)


func flush(parent: Node) -> void:
	for key in _batches:
		var b: Dictionary = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = b["mesh"]
		var xforms: Array = b["xforms"]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = b["mat"]
		if not b["shadow"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
	_batches.clear()
