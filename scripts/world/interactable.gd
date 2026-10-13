class_name Interactable
extends Node3D
## Punto con el que el jugador interactúa pulsando E. El jugador elige el más cercano.

signal used

@export var prompt := "Interactuar"
@export var radius := 2.0
## Opcional: devuelve el texto del aviso dinámicamente.
var prompt_func := Callable()


func _ready() -> void:
	add_to_group("interactables")


func get_prompt() -> String:
	if prompt_func.is_valid():
		return prompt_func.call()
	return prompt


static func create(parent: Node, pos: Vector3, text: String, callback: Callable, r := 2.0) -> Interactable:
	var it := Interactable.new()
	it.prompt = text
	it.radius = r
	it.position = pos
	it.used.connect(callback)
	parent.add_child(it)
	return it
