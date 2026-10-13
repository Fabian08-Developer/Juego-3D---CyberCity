class_name UiRoot
extends CanvasLayer
## Capa de interfaz: HUD + ventanas modales. Mientras hay una ventana abierta el juego se pausa.

signal pause_requested

var hud := Hud.new()
var started := false
var _overlay := ColorRect.new()
var _center := CenterContainer.new()
var _dialog: Control = null
var _on_close := Callable()
var _closable := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.make_theme()
	add_child(root)
	hud.visible = false
	root.add_child(hud)
	_overlay.color = Color(0, 0.04, 0.07, 0.72)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	root.add_child(_overlay)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.visible = false
	root.add_child(_center)


func is_open() -> bool:
	return _dialog != null


## Muestra `content` en una ventana centrada y pausa el juego.
func open(content: Control, on_close := Callable(), closable := true, min_width := 640.0) -> void:
	close(false)
	var panel := UiKit.panel(UiKit.box(Color(0.02, 0.06, 0.1, 0.97), Color(0, 0.9, 1, 0.4), 14, 26))
	panel.custom_minimum_size = Vector2(min_width, 0)
	panel.add_child(content)
	_center.add_child(panel)
	_dialog = panel
	_on_close = on_close
	_closable = closable
	_overlay.visible = true
	_center.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close(resume := true) -> void:
	if _dialog == null:
		return
	_dialog.queue_free()
	_dialog = null
	_overlay.visible = false
	_center.visible = false
	var cb := _on_close
	_on_close = Callable()
	if resume and started:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if cb.is_valid():
		cb.call()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if is_open():
			if _closable:
				close()
		elif started:
			pause_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_help") and started and not is_open():
		hud.toggle_help()
	elif event is InputEventMouseButton and event.pressed and started and not is_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toast(text: String, kind := "info", seconds := 5.0) -> void:
	hud.toast(text, kind, seconds)
