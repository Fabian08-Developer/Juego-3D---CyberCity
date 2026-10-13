class_name Hud
extends Control
## Interfaz en pantalla: estado, carrera, objetivo, minimapa, alertas, avisos y ayuda.

const TEXT_MONEY := Color("#ffe08a")

var minimap := Minimap.new()
var _clock: Label
var _career: Label
var _xp: ProgressBar
var _energy: ProgressBar
var _rep: ProgressBar
var _money: Label
var _objective: Label
var _alerts: VBoxContainer
var _prompt_panel: PanelContainer
var _prompt: Label
var _crosshair: Label
var _help: PanelContainer
var _toasts: VBoxContainer
var _alerts_key := ""
var _fill_ok := UiKit.box(UiKit.AMBER, Color(0, 0, 0, 0), 4, 0, 0)
var _fill_low := UiKit.box(UiKit.RED, Color(0, 0, 0, 0), 4, 0, 0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- Estado (arriba a la izquierda) ---
	var status := UiKit.panel()
	status.position = Vector2(16, 16)
	status.custom_minimum_size = Vector2(290, 0)
	add_child(status)
	var col := UiKit.vbox(5)
	status.add_child(col)
	_clock = UiKit.label("Día 1 · 07:30", 24, UiKit.CYAN)
	col.add_child(_clock)
	_career = UiKit.label("", 13, UiKit.MUTED)
	col.add_child(_career)
	_xp = UiKit.bar(Color("#7c5cff"), 250)
	col.add_child(_xp)
	_energy = UiKit.bar(UiKit.AMBER)
	col.add_child(_row("Energía", _energy))
	_rep = UiKit.bar(UiKit.GREEN)
	col.add_child(_row("Reputación", _rep))
	_money = UiKit.label("$0", 17, TEXT_MONEY)
	col.add_child(_money)

	# --- Objetivo (arriba al centro) ---
	var obj_panel := UiKit.panel()
	obj_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 16)
	obj_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(obj_panel)
	_objective = UiKit.label("", 15)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.custom_minimum_size = Vector2(520, 0)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_panel.add_child(_objective)

	_toasts = UiKit.vbox(8)
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 90)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	# --- Minimapa y alertas (arriba a la derecha) ---
	var right := UiKit.vbox(10)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(right)
	var map_panel := UiKit.panel(UiKit.box(UiKit.PANEL, Color(0, 0.9, 1, 0.35), 10, 4))
	map_panel.add_child(minimap)
	right.add_child(map_panel)
	var alerts_panel := UiKit.panel()
	alerts_panel.custom_minimum_size = Vector2(238, 0)
	right.add_child(alerts_panel)
	_alerts = UiKit.vbox(4)
	alerts_panel.add_child(_alerts)

	# --- Aviso de interacción (abajo al centro) ---
	_prompt_panel = UiKit.panel(UiKit.box(Color(0, 0, 0, 0.72), UiKit.CYAN, 8, 10))
	_prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 150)
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_panel.visible = false
	add_child(_prompt_panel)
	var prow := UiKit.hbox(10)
	_prompt_panel.add_child(prow)
	var key := UiKit.panel(UiKit.box(UiKit.CYAN, UiKit.CYAN, 4, 4))
	key.add_child(UiKit.label(" E ", 15, Color("#00131a")))
	prow.add_child(key)
	_prompt = UiKit.label("", 16)
	prow.add_child(_prompt)

	# --- Mira (primera persona) ---
	_crosshair = UiKit.label("+", 22, Color(1, 1, 1, 0.85))
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_crosshair)

	# --- Ayuda (abajo a la izquierda) ---
	_help = UiKit.panel()
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_help)
	_help.add_child(UiKit.label("WASD mover · Shift correr · Espacio saltar · E interactuar · V cámara 1ª/3ª · Rueda zoom · H ocultar ayuda · Esc menú", 13, UiKit.MUTED))


func _row(text: String, bar: ProgressBar) -> HBoxContainer:
	var r := UiKit.hbox(8)
	var l := UiKit.label(text, 13, UiKit.MUTED)
	l.custom_minimum_size = Vector2(90, 0)
	r.add_child(l)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(bar)
	return r


func toggle_help() -> void:
	_help.visible = not _help.visible


func toast(text: String, kind := "info", seconds := 5.0) -> void:
	var color := UiKit.CYAN
	if kind == "alert":
		color = UiKit.RED
	elif kind == "good":
		color = UiKit.GREEN
	var sb := UiKit.box(Color(0.02, 0.06, 0.1, 0.94), color, 8, 10, 0)
	sb.border_width_left = 4
	var p := UiKit.panel(sb)
	var l := UiKit.label(text, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(460, 0)
	p.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > 4:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	get_tree().create_timer(seconds).timeout.connect(_expire_toast.bind(p))


func _expire_toast(p) -> void:
	if is_instance_valid(p):
		p.queue_free()


func refresh(player: Player, pending: Array, objective: String) -> void:
	_clock.text = "Día %d · %s" % [GameState.day, GameState.clock_text()]
	_career.text = "%s · %d XP" % [GameState.career_title(), GameState.xp]
	_xp.value = GameState.career_progress() * 100.0
	_energy.value = GameState.energy
	var low := GameState.energy < Config.LOW_ENERGY
	_energy.add_theme_stylebox_override("fill", _fill_low if low else _fill_ok)
	_rep.value = GameState.reputation
	_money.text = "$ %d" % GameState.money
	_objective.text = objective
	_crosshair.visible = player.first_person
	var it := player.current_interactable
	_prompt_panel.visible = it != null
	if it != null:
		_prompt.text = it.get_prompt()
	minimap.player_pos = player.global_position
	minimap.player_yaw = player.get_yaw()
	_refresh_alerts(pending)


func _refresh_alerts(pending: Array) -> void:
	var key := ""
	for inc in pending:
		key += "%d:%d|" % [inc["id"], int((float(inc["deadline"]) - GameState.minutes) / 5.0)]
	if key == _alerts_key and _alerts.get_child_count() > 0:
		return
	_alerts_key = key
	UiKit.clear(_alerts)
	_alerts.add_child(UiKit.label("ALERTAS SOC", 12, UiKit.MUTED))
	if pending.is_empty():
		_alerts.add_child(UiKit.label("Sin alertas pendientes", 13, UiKit.GREEN))
		return
	for inc in pending:
		var left := maxi(0, int(float(inc["deadline"]) - GameState.minutes))
		var row := UiKit.hbox(6)
		var name_l := UiKit.label(str(inc["ch"]["name"]), 13)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.custom_minimum_size = Vector2(150, 0)
		row.add_child(name_l)
		var color := UiKit.RED if left < 20 else (UiKit.AMBER if left < 45 else UiKit.GREEN)
		row.add_child(UiKit.label("%d min" % left, 13, color))
		_alerts.add_child(row)
