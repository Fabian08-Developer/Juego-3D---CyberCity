class_name Pedestrians
extends Node3D
## Peatones que recorren las aceras y el parque. Se detienen si el jugador les bloquea el paso.

var player: Node3D
var _walkers: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var y := Config.SIDEWALK_H
	for n in 22:
		var bi := rng.randi_range(0, Config.BLOCKS - 1)
		var bj := rng.randi_range(0, Config.BLOCKS - 1)
		if bi == 1 and bj == 1:
			bj = 2  # el parque tiene sus propios paseantes
		var cx := Config.block_center(bi)
		var cz := Config.block_center(bj)
		var e := Config.BLOCK / 2.0 - 1.6
		var path := [Vector3(cx - e, y, cz - e), Vector3(cx + e, y, cz - e), Vector3(cx + e, y, cz + e), Vector3(cx - e, y, cz + e)]
		if rng.randf() < 0.5:
			path.reverse()
		_add(path, rng)
	# Paseantes alrededor de la fuente del parque
	for n in 6:
		var path := []
		var radius := rng.randf_range(10.5, 12.5)
		for k in 12:
			var a := k * TAU / 12.0
			path.append(Vector3(cos(a) * radius, y, sin(a) * radius))
		if n % 2 == 0:
			path.reverse()
		_add(path, rng)


func _add(path: Array, rng: RandomNumberGenerator) -> void:
	var person := Person.new().setup(Person.random_colors(rng))
	add_child(person)
	_walkers.append({"p": person, "path": path, "seg": rng.randi_range(0, path.size() - 1), "k": rng.randf(), "speed": rng.randf_range(1.0, 1.6)})


func _process(delta: float) -> void:
	var pp := player.global_position if player != null else Vector3(9999, 0, 9999)
	for w in _walkers:
		var person: Person = w["p"]
		var path: Array = w["path"]
		var seg: int = w["seg"]
		var a: Vector3 = path[seg]
		var b: Vector3 = path[(seg + 1) % path.size()]
		var seg_len := maxf(0.01, a.distance_to(b))
		var dir := (b - a) / seg_len
		var blocked := (pp - person.position).dot(dir) > 0.0 and pp.distance_to(person.position) < 1.3
		var speed: float = 0.0 if blocked else w["speed"]
		var k: float = w["k"] + speed * delta / seg_len
		if k >= 1.0:
			k -= 1.0
			seg = (seg + 1) % path.size()
			w["seg"] = seg
			a = path[seg]
			b = path[(seg + 1) % path.size()]
		w["k"] = k
		person.position = a.lerp(b, k)
		person.rotation.y = atan2(b.x - a.x, b.z - a.z)
		person.animate(delta, speed)
