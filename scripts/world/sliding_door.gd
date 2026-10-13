class_name SlidingDoor
extends Node3D
## Puerta automática de vidrio: se abre cuando el jugador se acerca.

var width := 2.2
var height := 2.6
var _left: MeshInstance3D
var _right: MeshInstance3D
var _open := 0.0
var _player: Node3D


func _init(w := 2.2, h := 2.6) -> void:
	width = w
	height = h


func _ready() -> void:
	var panel := Vector3(width / 2.0, height, 0.06)
	var mat := Mats.glass("#bfe9ff", 0.35)
	_left = Geo.box(self, panel, Vector3(-width / 4.0, height / 2.0, 0), mat, false, false)
	_right = Geo.box(self, panel, Vector3(width / 4.0, height / 2.0, 0), mat, false, false)
	var frame := Mats.color("#2b2b2b", 0.5)
	Geo.box(self, Vector3(width + 0.3, 0.15, 0.2), Vector3(0, height + 0.075, 0), frame, false)


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var near := _player.global_position.distance_to(global_position) < 3.5
	_open = move_toward(_open, 1.0 if near else 0.0, delta * 2.5)
	var shift := _open * width * 0.48
	_left.position.x = -width / 4.0 - shift
	_right.position.x = width / 4.0 + shift
