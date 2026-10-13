class_name SocConsole
extends VBoxContainer
## Consola del SOC. Flujo de cada incidente:
##   1) marcar los elementos sospechosos  2) elegir la respuesta  3) revisar resultados explicados.

var work_day: WorkDay
var on_close := Callable()
var on_toast := Callable()  # (texto, tipo)
var _list: VBoxContainer
var _main: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	custom_minimum_size = Vector2(1180, 700)
	add_theme_constant_override("separation", 12)
	var header := UiKit.hbox()
	var titles := UiKit.vbox(2)
	titles.add_child(UiKit.label("Consola SOC · CyberShield", 26, UiKit.CYAN))
	titles.add_child(UiKit.label("Día %d · %s · %s" % [GameState.day, GameState.clock_text(), GameState.career_title()], 14, UiKit.MUTED))
	header.add_child(titles)
	header.add_child(UiKit.spacer())
	header.add_child(UiKit.button("Salir (Esc)", func(): on_close.call()))
	add_child(header)

	var body := UiKit.hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(300, 0)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(list_scroll)
	_list = UiKit.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_main = UiKit.vbox(10)
	_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_main)

	var pending := work_day.pending()
	_render_list(pending[0] if not pending.is_empty() else {})
	if pending.is_empty():
		_render_idle()
	else:
		_render_select(pending[0])


func _render_list(active: Dictionary) -> void:
	UiKit.clear(_list)
	var all := work_day.pending()
	var done := work_day.incidents.filter(func(i): return i["status"] != "pending")
	done.reverse()
	all.append_array(done)
	if all.is_empty():
		_list.add_child(UiKit.label("Aún no hay incidentes hoy.", 14, UiKit.MUTED))
	for inc in all:
		var ch: Dictionary = inc["ch"]
		var status := ""
		match str(inc["status"]):
			"pending":
				status = "Plazo: %d min" % maxi(0, int(float(inc["deadline"]) - GameState.minutes))
			"resolved":
				status = "Resuelto: %d/100" % int(inc["result"]["score"])
			_:
				status = "Expirado"
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = "[%s] %s\n%s\n%s" % [ch["severity"], ch["name"], ch["title"], status]
		b.add_theme_color_override("font_color", UiKit.severity_color(ch["severity"]) if inc["status"] == "pending" else UiKit.MUTED)
		if not active.is_empty() and active["id"] == inc["id"]:
			b.add_theme_stylebox_override("normal", UiKit.box(Color(0, 0.9, 1, 0.14), UiKit.CYAN, 8, 10))
		if inc["status"] == "pending":
			b.pressed.connect(func(): _render_list(inc); _render_select(inc))
		else:
			b.disabled = true
		_list.add_child(b)


func _render_idle() -> void:
	UiKit.clear(_main)
	var before := GameState.minutes < Config.SHIFT_START
	var t := GameState.today
	var lines := [
		"cybershield-soc ~$ status",
		"Turno aún no iniciado: comienza a las 08:00." if before else "Sin alertas pendientes. Monitoreando la red…",
		"",
		"Incidentes resueltos hoy: %d" % int(t["resolved"]),
		"Incidentes expirados hoy: %d" % int(t["expired"]),
		"Reputación: %d/100" % int(GameState.reputation),
		"Carrera: %s (%d XP)" % [GameState.career_title(), GameState.xp],
		"",
		"Consejo: mientras no haya alertas puedes salir a la ciudad.",
		"Te avisaremos cuando llegue una nueva.",
	]
	var term := UiKit.panel(UiKit.box(Color("#020a10"), Color(0, 0.9, 1, 0.25), 8, 14))
	var l := UiKit.label("\n".join(PackedStringArray(lines)), 15, UiKit.GREEN, true)
	l.add_theme_font_override("font", UiKit.mono())
	term.add_child(l)
	_main.add_child(term)


func _header(inc: Dictionary) -> void:
	var ch: Dictionary = inc["ch"]
	var row := UiKit.hbox(10)
	var sev := UiKit.panel(UiKit.box(UiKit.severity_color(ch["severity"]), UiKit.severity_color(ch["severity"]), 4, 4))
	sev.add_child(UiKit.label(str(ch["severity"]).to_upper(), 12, Color("#001018")))
	row.add_child(sev)
	row.add_child(UiKit.label("%s · Incidente #%d" % [ch["name"], inc["id"]], 14, UiKit.MUTED))
	_main.add_child(row)
	_main.add_child(UiKit.label(str(ch["title"]), 22))
	_main.add_child(UiKit.label(str(ch["briefing"]), 15, UiKit.MUTED, true))


func _table(inc: Dictionary, selected: Dictionary, review: bool) -> Control:
	var ch: Dictionary = inc["ch"]
	var columns: Array = ch["columns"]
	var rows: Array = ch["rows"]
	var term := UiKit.panel(UiKit.box(Color("#020a10"), Color(0, 0.9, 1, 0.25), 8, 10))
	var table := UiKit.vbox(6)
	term.add_child(table)
	var head := UiKit.hbox(8)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(40, 0)
	head.add_child(pad)
	for c in columns:
		var hl := UiKit.label(str(c), 13, UiKit.CYAN, true)
		hl.custom_minimum_size = Vector2(60, 0)
		head.add_child(hl)
	table.add_child(head)
	table.add_child(HSeparator.new())
	for i in rows.size():
		var r: Dictionary = rows[i]
		var line := UiKit.hbox(8)
		if review:
			var ok: bool = bool(r["bad"]) == selected.has(i)
			var mark := UiKit.label("OK" if ok else "X", 14, UiKit.GREEN if ok else UiKit.RED)
			mark.custom_minimum_size = Vector2(40, 0)
			line.add_child(mark)
		else:
			var cb := CheckBox.new()
			cb.focus_mode = Control.FOCUS_NONE
			cb.custom_minimum_size = Vector2(40, 0)
			cb.toggled.connect(func(on: bool):
				if on:
					selected[i] = true
				else:
					selected.erase(i)
				for cell_label in line.get_children():
					if cell_label is Label:
						cell_label.add_theme_color_override("font_color", Color("#ff8fa3") if on else UiKit.TEXT)
			)
			line.add_child(cb)
		for cell in r["cells"]:
			var cl := UiKit.label(str(cell), 13, UiKit.TEXT, true)
			cl.custom_minimum_size = Vector2(60, 0)
			cl.add_theme_font_override("font", UiKit.mono())
			if review and selected.has(i):
				cl.add_theme_color_override("font_color", Color("#ffb3c0"))
			line.add_child(cl)
		table.add_child(line)
		if review:
			var verdict := "MALICIOSO / VULNERABLE" if r["bad"] else "LEGÍTIMO"
			var why := UiKit.label("    %s — %s" % [verdict, r["why"]], 13, UiKit.AMBER if r["bad"] else UiKit.MUTED, true)
			table.add_child(why)
		table.add_child(HSeparator.new())
	return term


func _render_select(inc: Dictionary) -> void:
	UiKit.clear(_main)
	_scroll.scroll_vertical = 0
	var selected := {}
	_header(inc)
	_main.add_child(UiKit.label("Paso 1 de 2: %s  (marca las casillas)" % inc["ch"]["instruction"], 16, UiKit.TEXT, true))
	_main.add_child(_table(inc, selected, false))
	var actions := UiKit.hbox()
	actions.add_child(UiKit.label("Analiza ruta, firma, versión, dominio u origen de cada elemento.", 13, UiKit.MUTED))
	actions.add_child(UiKit.spacer())
	actions.add_child(UiKit.button("Continuar →", func(): _render_action(inc, selected), true))
	_main.add_child(actions)


func _render_action(inc: Dictionary, selected: Dictionary) -> void:
	UiKit.clear(_main)
	_scroll.scroll_vertical = 0
	var ch: Dictionary = inc["ch"]
	_header(inc)
	_main.add_child(UiKit.label("Paso 2 de 2: %s" % ch["action"]["question"], 17, UiKit.TEXT, true))
	var state := {"choice": -1}
	var submit := UiKit.button("Enviar respuesta", func(): _render_result(inc, selected, state["choice"]), true)
	submit.disabled = true
	var buttons: Array = []
	var options: Array = ch["action"]["options"]
	for i in options.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = str(options[i]["text"])
		b.pressed.connect(func():
			state["choice"] = i
			for other in buttons:
				other.button_pressed = other == b
			submit.disabled = false
		)
		buttons.append(b)
		_main.add_child(b)
	var row := UiKit.hbox()
	row.add_child(UiKit.button("← Volver", func(): _render_select(inc)))
	row.add_child(UiKit.spacer())
	row.add_child(submit)
	_main.add_child(row)


func _render_result(inc: Dictionary, selected: Dictionary, choice: int) -> void:
	var ch: Dictionary = inc["ch"]
	var result := ChallengeBank.score(ch, selected, choice)
	var reward := work_day.resolve(inc, result)
	_render_list(inc)
	UiKit.clear(_main)
	_scroll.scroll_vertical = 0
	_header(inc)
	var s: int = result["score"]
	var color := UiKit.GREEN if s >= 80 else (UiKit.AMBER if s >= 50 else UiKit.RED)
	var top := UiKit.hbox(20)
	var left := UiKit.vbox(2)
	left.add_child(UiKit.label("%d/100" % s, 44, color))
	left.add_child(UiKit.label("%d/%d elementos bien clasificados · respuesta %s" % [result["rows_ok"], result["rows_total"], "correcta" if result["action_ok"] else "incorrecta"], 14, UiKit.MUTED))
	top.add_child(left)
	top.add_child(UiKit.spacer())
	top.add_child(UiKit.label("+$%d\n%+d reputación\n+%d XP" % [reward["pay"], reward["rep"], reward["xp"]], 16, UiKit.TEXT))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(18, 0)
	top.add_child(pad)
	_main.add_child(top)
	_main.add_child(_table(inc, selected, true))
	var options: Array = ch["action"]["options"]
	for i in options.size():
		var o: Dictionary = options[i]
		var correct: bool = o["correct"]
		if not correct and i != choice:
			continue
		var c := UiKit.GREEN if correct else UiKit.RED
		var p := UiKit.panel(UiKit.box(Color(c.r, c.g, c.b, 0.1), c, 8, 10))
		var v := UiKit.vbox(4)
		v.add_child(UiKit.label(("Respuesta correcta: " if correct else "Tu respuesta: ") + str(o["text"]), 15, UiKit.TEXT, true))
		v.add_child(UiKit.label(str(o["feedback"]), 13, UiKit.MUTED, true))
		p.add_child(v)
		_main.add_child(p)
	var row := UiKit.hbox()
	row.add_child(UiKit.spacer())
	row.add_child(UiKit.button("Cerrar incidente", func(): _next(), true))
	_main.add_child(row)
	if on_toast.is_valid():
		on_toast.call("Incidente #%d cerrado: %d/100 (+$%d)" % [inc["id"], s, reward["pay"]], "good" if s >= 60 else "alert")


func _next() -> void:
	var pending := work_day.pending()
	_render_list(pending[0] if not pending.is_empty() else {})
	if pending.is_empty():
		_render_idle()
	else:
		_render_select(pending[0])
