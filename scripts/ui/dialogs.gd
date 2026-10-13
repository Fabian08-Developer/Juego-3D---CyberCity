class_name Dialogs
extends RefCounted
## Contenido de las ventanas: menú principal, pausa, tiendas, eventos, resumen del día.

static func start_menu(has_save: bool, on_start: Callable) -> Control:
	var v := UiKit.vbox(14)
	var title := UiKit.label("CYBERCITY", 54, UiKit.CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UiKit.label("Un día en la vida de un(a) Ingeniero(a) en Ciberseguridad", 18, UiKit.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var intro := (
		"Recorre la ciudad, entra a sus negocios y llega a tiempo a CyberShield. Desde la consola del SOC detectarás "
		+ "vulnerabilidades, identificarás malware, frenarás intrusos, desarmarás campañas de phishing y responderás a "
		+ "ransomware. En la calle también te esperan situaciones de seguridad: USB abandonados, cajeros alterados, "
		+ "Wi-Fi falsos y más. Asciende de Analista Junior a CISO."
	)
	v.add_child(UiKit.label(intro, 15, UiKit.MUTED, true))
	v.add_child(_controls_grid())
	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if has_save:
		row.add_child(UiKit.button("Continuar partida (Día %d)" % _saved_day(), func(): on_start.call(true), true))
		row.add_child(UiKit.button("Nueva partida", func(): on_start.call(false)))
	else:
		row.add_child(UiKit.button("Comenzar jornada", func(): on_start.call(false), true))
	row.add_child(UiKit.button("Salir", func(): (Engine.get_main_loop() as SceneTree).quit()))
	v.add_child(row)
	return v


static func _saved_day() -> int:
	var data = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	return int(data.get("day", 1)) if data is Dictionary else 1


static func _controls_grid() -> Control:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 26)
	g.add_theme_constant_override("v_separation", 6)
	for pair in [["W A S D", "Moverse"], ["Ratón", "Mirar"], ["Shift", "Correr"], ["Espacio", "Saltar"], ["E", "Interactuar"], ["V", "Cámara 1ª / 3ª"], ["Rueda", "Zoom (3ª persona)"], ["H", "Ocultar ayuda"], ["Esc", "Menú / cerrar"]]:
		var h := UiKit.hbox(8)
		var k := UiKit.panel(UiKit.box(UiKit.CYAN, UiKit.CYAN, 4, 4))
		k.add_child(UiKit.label(" %s " % pair[0], 13, Color("#00131a")))
		h.add_child(k)
		h.add_child(UiKit.label(pair[1], 14, UiKit.MUTED))
		g.add_child(h)
	return g


static func pause_menu(on_resume: Callable, on_quality: Callable, on_menu: Callable) -> Control:
	var v := UiKit.vbox(12)
	v.add_child(UiKit.label("Pausa", 30, UiKit.CYAN))
	v.add_child(UiKit.label("Día %d · %s · %s" % [GameState.day, GameState.clock_text(), GameState.career_title()], 15, UiKit.MUTED))
	v.add_child(_controls_grid())
	var names := ["Baja", "Media", "Alta"]
	var q := UiKit.hbox(8)
	q.add_child(UiKit.label("Calidad gráfica:", 15))
	for i in 3:
		var b := UiKit.button(names[i], func(): on_quality.call(i), i == GameState.quality)
		q.add_child(b)
	v.add_child(q)
	var row := UiKit.hbox(12)
	row.add_child(UiKit.button("Continuar", on_resume, true))
	row.add_child(UiKit.button("Guardar y salir al menú", on_menu))
	v.add_child(row)
	return v


static func shop(def: Dictionary, on_buy: Callable, on_close: Callable) -> Control:
	var v := UiKit.vbox(10)
	var head := UiKit.hbox()
	var titles := UiKit.vbox(2)
	titles.add_child(UiKit.label(str(def.get("name", "")), 28, UiKit.CYAN))
	titles.add_child(UiKit.label("%s · %s" % [def.get("type", ""), def.get("greeting", "")], 14, UiKit.MUTED))
	head.add_child(titles)
	head.add_child(UiKit.spacer())
	var wallet := UiKit.label("", 16)
	head.add_child(wallet)
	v.add_child(head)
	var items: Array = def.get("items", [])
	var buttons: Array = []
	var refresh := func():
		wallet.text = "$ %d   ·   Energía %d" % [GameState.money, int(GameState.energy)]
		for i in buttons.size():
			buttons[i].disabled = GameState.money < int(items[i].get("price", 0))
	if items.is_empty():
		v.add_child(UiKit.label("Aquí no se venden productos. Un asesor te atiende con gusto.", 15, UiKit.MUTED, true))
	for item in items:
		var row := UiKit.panel(UiKit.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.1), 8, 10))
		var h := UiKit.hbox(12)
		row.add_child(h)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var effects := []
		if item.has("energy"):
			effects.append("+%d energía" % int(item["energy"]))
		if item.has("reputation"):
			effects.append("%+d reputación" % int(item["reputation"]))
		if item.has("xp"):
			effects.append("+%d XP" % int(item["xp"]))
		info.add_child(UiKit.label("%s   %s" % [item["name"], "  ·  ".join(PackedStringArray(effects))], 16))
		info.add_child(UiKit.label(str(item.get("description", "")), 13, UiKit.MUTED, true))
		h.add_child(info)
		var price := int(item.get("price", 0))
		var b := UiKit.button("$%d" % price if price > 0 else "Gratis", func():
			on_buy.call(item)
			refresh.call()
		)
		b.custom_minimum_size = Vector2(90, 0)
		buttons.append(b)
		h.add_child(b)
		v.add_child(row)
	refresh.call()
	if def.has("tip"):
		var tip := UiKit.panel(UiKit.box(Color(0, 0.9, 1, 0.06), UiKit.CYAN, 6, 12))
		tip.add_child(UiKit.label("Tip de seguridad: " + str(def["tip"]), 14, UiKit.TEXT, true))
		v.add_child(tip)
	var foot := UiKit.hbox()
	foot.add_child(UiKit.spacer())
	foot.add_child(UiKit.button("Salir", on_close, true))
	v.add_child(foot)
	return v


static func city_event(def: Dictionary, on_choose: Callable, on_close: Callable) -> Control:
	var v := UiKit.vbox(12)
	v.add_child(UiKit.label("Situación de seguridad", 14, UiKit.AMBER))
	v.add_child(UiKit.label(str(def.get("title", "")), 26, UiKit.CYAN))
	v.add_child(UiKit.label(str(def.get("description", "")), 16, UiKit.TEXT, true))
	v.add_child(UiKit.label("¿Qué haces?", 15, UiKit.MUTED))
	var options: Array = def.get("options", [])
	var box := UiKit.vbox(8)
	v.add_child(box)
	for i in options.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = str(options[i]["text"])
		b.pressed.connect(func():
			var result: Dictionary = on_choose.call(i)
			UiKit.clear(box)
			var good: bool = result["outcome"] == "good"
			var bad: bool = result["outcome"] == "bad"
			var c := UiKit.GREEN if good else (UiKit.RED if bad else UiKit.AMBER)
			var p := UiKit.panel(UiKit.box(Color(c.r, c.g, c.b, 0.1), c, 8, 12))
			var inner := UiKit.vbox(6)
			inner.add_child(UiKit.label("¡Bien hecho!" if good else ("Mala decisión" if bad else "Podría ser mejor"), 20, c))
			inner.add_child(UiKit.label(str(result["feedback"]), 15, UiKit.TEXT, true))
			inner.add_child(UiKit.label("+%d XP   ·   %+d reputación" % [int(result["xp"]), int(result["rep"])], 14, UiKit.MUTED))
			p.add_child(inner)
			box.add_child(p)
			var foot := UiKit.hbox()
			foot.add_child(UiKit.spacer())
			foot.add_child(UiKit.button("Continuar", on_close, true))
			box.add_child(foot)
		)
		box.add_child(b)
	return v


static func info(title: String, text: String, buttons: Array) -> Control:
	var v := UiKit.vbox(12)
	v.add_child(UiKit.label(title, 26, UiKit.CYAN))
	v.add_child(UiKit.label(text, 16, UiKit.TEXT, true))
	var row := UiKit.hbox(10)
	row.add_child(UiKit.spacer())
	for i in buttons.size():
		var spec: Array = buttons[i]
		row.add_child(UiKit.button(str(spec[0]), spec[1], i == buttons.size() - 1))
	v.add_child(row)
	return v


static func day_summary(fired: bool, on_explore: Callable, on_sleep: Callable) -> Control:
	var t := GameState.today
	var scores: Array = t["scores"]
	var avg := 0
	if not scores.is_empty():
		var total := 0
		for s in scores:
			total += int(s)
		avg = int(round(float(total) / scores.size()))
	var v := UiKit.vbox(12)
	v.add_child(UiKit.label("Has sido despedido" if fired else "Fin de la jornada · Día %d" % GameState.day, 28, UiKit.RED if fired else UiKit.CYAN))
	v.add_child(UiKit.label("Tu reputación llegó a 0: demasiados incidentes sin atender o mal resueltos." if fired else "Este es el resumen de tu turno en el SOC.", 15, UiKit.MUTED, true))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	var events_total := int(t["events_good"]) + int(t["events_bad"])
	var stats := [
		[str(t["resolved"]), "Resueltos"],
		[str(t["expired"]), "Expirados"],
		[str(avg), "Puntaje medio"],
		["$%d" % int(t["earned"]), "Ganado hoy"],
		["%d / %d" % [int(t["events_good"]), events_total], "Eventos bien resueltos"],
	]
	for pair in stats:
		var p := UiKit.panel(UiKit.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.12), 8, 12))
		p.custom_minimum_size = Vector2(150, 0)
		var c := UiKit.vbox(2)
		var big := UiKit.label(pair[0], 26, UiKit.CYAN)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(big)
		var small := UiKit.label(pair[1], 13, UiKit.MUTED)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(small)
		p.add_child(c)
		grid.add_child(p)
	v.add_child(grid)
	v.add_child(UiKit.label("Reputación: %d/100 (%+d hoy)   ·   %s   ·   Salario al dormir: $%d" % [int(GameState.reputation), int(round(float(t["rep_delta"]))), GameState.career_title(), GameState.salary()], 15))
	var row := UiKit.hbox(12)
	row.add_child(UiKit.spacer())
	if fired:
		row.add_child(UiKit.button("Empezar de nuevo", on_sleep, true))
	else:
		row.add_child(UiKit.button("Seguir explorando la ciudad (noche)", on_explore))
		row.add_child(UiKit.button("Ir a dormir → siguiente día", on_sleep, true))
	v.add_child(row)
	return v
