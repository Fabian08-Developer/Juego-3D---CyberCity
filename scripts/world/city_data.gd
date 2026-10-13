class_name CityData
extends RefCounted
## Información que la ciudad publica para el resto del juego (minimapa, eventos, marcadores).

## Formas del minimapa: {rect: Rect2 (x,z en metros), color: Color, label: String}
var map_shapes: Array = []
## Puntos con nombre: "hq", "workstation", "home", "spawn"…
var markers := {}
## Lugares donde pueden ocurrir eventos de ciudad: nombre -> Array[Vector3]
var event_spots := {}
## Luces que solo se encienden de noche.
var night_lights: Array = []
## Datos de cada negocio colocado: id -> {def, door: Vector3}
var businesses := {}


func add_shape(x0: float, z0: float, x1: float, z1: float, color: Color, label := "") -> void:
	map_shapes.append({"rect": Rect2(x0, z0, x1 - x0, z1 - z0), "color": color, "label": label})


func add_spot(spot: String, pos: Vector3) -> void:
	if not event_spots.has(spot):
		event_spots[spot] = []
	event_spots[spot].append(pos)
