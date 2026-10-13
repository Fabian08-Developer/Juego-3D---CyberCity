extends Node3D
## Punto de entrada: construye la ciudad, el jugador, los sistemas y la interfaz,
## y coordina el reloj del día, la jornada laboral y los eventos.

const RECEPTION_TIPS := [
	"Recepción: \"Recuerda no dejar pasar a nadie detrás de ti sin tarjeta (tailgating).\"",
	"Recepción: \"Hoy llegó un USB sin remitente. Lo enviamos a TI para análisis; no lo conectes.\"",
	"Recepción: \"Bloquea tu pantalla (Win + L) cada vez que te levantes del puesto.\"",
	"Recepción: \"Alguien llamó diciendo ser de soporte y pidió tu contraseña. No se la dimos.\"",
]
const COWORKER_TIPS := [
	"\"En phishing fíjate en el dominio real: lo que está justo antes de .com, .co o .lat.\"",
	"\"Un svchost.exe fuera de System32 siempre es sospechoso.\"",
	"\"Si ves fuerza bruta seguida de un inicio de sesión exitoso, la cuenta ya está comprometida.\"",
	"\"Ante ransomware: aislar primero, nunca pagar, y restaurar desde copias offline.\"",
	"\"Las reglas 'temporales' del firewall suelen quedarse para siempre. Revísalas.\"",
	"\"Una frase de contraseña larga con MFA vale más que P@ssw0rd!\"",
	"\"Si subes de nivel te llegan incidentes más complejos: intrusiones, firewall y ransomware.\"",
]

var city: CityData
var player: Player
var day_night: DayNight
var work_day: WorkDay
var events: CityEvents
var ui: UiRoot
var started := false
var _low_energy_warned := false
var _ending := false


func _ready() -> void:
	InputSetup.ensure_actions()
	randomize()
	var world := Node3D.new()
	world.name = "Ciudad"
	add_child(world)
	city = CityBuilder.build(world, {
		"on_business": _open_shop,
		"on_home": _on_home,
		"on_workstation": _open_console,
		"on_reception": func(): ui.toast(RECEPTION_TIPS.pick_random()),
		"on_coworker": func(who: String): ui.toast("%s: %s" % [who, COWORKER_TIPS.pick_random()], "info", 7.0),
		"on_elevator": func(): ui.toast("Los pisos superiores (laboratorio forense, sala de crisis) llegarán en una próxima versión."),
		"alert_lines": _alert_lines,
	})

	day_night = DayNight.new()
	add_child(day_night)
	day_night.setup(self, city)

	player = Player.new()
	add_child(player)

	var traffic := Traffic.new()
	traffic.player = player
	add_child(traffic)
	var pedestrians := Pedestrians.new()
	pedestrians.player = player
	add_child(pedestrians)

	work_day = WorkDay.new()
	add_child(work_day)
	work_day.shift_started.connect(func(): ui.toast("Tu turno comenzó. Revisa la consola del SOC en CyberShield.", "info", 6.0))
	work_day.incident_spawned.connect(func(inc): ui.toast("Nueva alerta [%s]: %s" % [inc["ch"]["severity"], inc["ch"]["title"]], "alert", 6.0))
	work_day.incident_expired.connect(func(inc): ui.toast("El incidente #%d escaló por falta de respuesta (-%d reputación)" % [inc["id"], int(Config.INCIDENT_EXPIRED_PENALTY)], "alert", 6.0))
	work_day.shift_ended.connect(_on_shift_ended)

	events = CityEvents.new()
	events.city = city
	add_child(events)
	events.event_appeared.connect(func(ev): ui.toast("Algo ocurre en la ciudad: %s (busca el \"!\" en el mapa)" % ev["title"], "info", 6.0))
	events.event_opened.connect(_open_event)

	ui = UiRoot.new()
	add_child(ui)
	ui.hud.minimap.city = city
	ui.pause_requested.connect(_open_pause)
	GameState.leveled_up.connect(func(title): ui.toast("¡Ascenso! Ahora eres %s. Llegarán incidentes más complejos." % title, "good", 8.0))

	_spawn_at_home()
	day_night.update(GameState.minutes)
	get_tree().paused = true
	ui.open(Dialogs.start_menu(GameState.has_save(), _start_game), Callable(), false, 860.0)

	if "--smoke-test" in OS.get_cmdline_user_args():
		var test: Node = load("res://scripts/debug/smoke_test.gd").new()
		test.set("main", self)
		add_child(test)


func _spawn_at_home() -> void:
	var home: Vector3 = city.markers.get("home", Vector3(0, Config.SIDEWALK_H, 10))
	player.spawn(home + Vector3(0, 0.1, 0), 0.0)


func _start_game(continue_game: bool) -> void:
	if continue_game and GameState.load_game():
		pass
	else:
		GameState.delete_save()
		GameState.new_game()
	GameState.minutes = Config.DAY_START
	work_day.plan_day()
	events.reset_day()
	_spawn_at_home()
	day_night.apply_quality(GameState.quality)
	started = true
	ui.started = true
	ui.hud.visible = true
	ui.close()
	ui.toast("Día %d. Tu turno en CyberShield empieza a las 08:00. ¡Buena suerte!" % GameState.day, "info", 6.0)


func _process(delta: float) -> void:
	if not started:
		return
	var minutes := delta * Config.TIME_SCALE
	GameState.minutes += minutes
	GameState.add_energy(-Config.ENERGY_DRAIN_PER_MINUTE * minutes)
	var low := GameState.energy < Config.LOW_ENERGY
	player.speed_multiplier = 0.7 if low else 1.0
	if low and not _low_energy_warned:
		_low_energy_warned = true
		ui.toast("Tu energía está baja: caminarás más lento. Toma un café en Café Byte.", "alert")
	elif GameState.energy > Config.LOW_ENERGY + 10.0:
		_low_energy_warned = false

	day_night.update(GameState.minutes)
	work_day.update()
	events.update()
	ui.hud.refresh(player, work_day.pending(), _objective())
	ui.hud.minimap.targets = _map_targets()

	if GameState.reputation <= 0.0 and not _ending:
		_ending = true
		ui.open(Dialogs.day_summary(true, Callable(), _restart), Callable(), false, 900.0)
	elif GameState.minutes >= Config.NIGHT_END and not ui.is_open():
		ui.toast("Es muy tarde: te vas a dormir.", "info")
		_sleep()


func _objective() -> String:
	var pending := work_day.pending().size()
	var m := GameState.minutes
	if pending > 0:
		return "%d incidente(s) pendiente(s): ve a tu estación de trabajo en el SOC de CyberShield." % pending
	if m < Config.SHIFT_START:
		return "Ve a CyberShield (la torre azul al norte del parque). Tu turno empieza a las 08:00."
	if m >= Config.SHIFT_END:
		return "Jornada terminada: disfruta la ciudad de noche o ve a casa a dormir."
	if GameState.energy < Config.LOW_ENERGY:
		return "Energía baja: pasa por Café Byte, la panadería o el MegaMarket."
	if not events.active.is_empty():
		return "Hay situaciones de seguridad en la ciudad (marcadas con \"!\"). Investígalas."
	return "Sin alertas. Recorre la ciudad; te avisaremos cuando llegue una nueva."


func _map_targets() -> Array:
	var out := []
	var m := GameState.minutes
	if not work_day.pending().is_empty() or (m < Config.SHIFT_START):
		out.append({"pos": city.markers["hq"], "color": UiKit.RED})
	for p in events.positions():
		out.append({"pos": p, "color": UiKit.AMBER})
	if m >= Config.SHIFT_END:
		out.append({"pos": city.markers["home"], "color": UiKit.GREEN})
	return out


func _alert_lines() -> Array:
	var out := []
	if work_day == null:
		return out
	for inc in work_day.pending():
		out.append("[%s] %s" % [str(inc["ch"]["severity"]).to_upper(), inc["ch"]["title"]])
	return out


# ---------------------------------------------------------------- Interacciones

func _open_console() -> void:
	var console := SocConsole.new()
	console.work_day = work_day
	console.on_close = func(): ui.close()
	console.on_toast = func(text, kind): ui.toast(text, kind)
	ui.open(console, Callable(), true, 1240.0)


func _open_shop(def: Dictionary) -> void:
	var on_buy := func(item: Dictionary):
		var price := int(item.get("price", 0))
		if not GameState.spend(price):
			ui.toast("No tienes suficiente dinero.", "alert")
			return
		GameState.add_energy(float(item.get("energy", 0)))
		GameState.add_reputation(float(item.get("reputation", 0)))
		GameState.add_xp(int(item.get("xp", 0)))
		var bad := float(item.get("reputation", 0)) < 0.0
		ui.toast("Compraste %s%s" % [item["name"], " — ¡mala idea!" if bad else ""], "alert" if bad else "good")
	ui.open(Dialogs.shop(def, on_buy, ui.close), Callable(), true, 720.0)


func _open_event(def: Dictionary) -> void:
	ui.open(Dialogs.city_event(def, func(i): return events.resolve(def, i), ui.close), Callable(), true, 720.0)


func _on_home() -> void:
	if GameState.minutes < Config.SHIFT_END:
		var text := "Todavía no termina tu jornada (hasta las 17:00). Puedes descansar un rato: recuperas energía, pero pasan 45 minutos y los incidentes siguen corriendo."
		ui.open(Dialogs.info("Tu apartamento", text, [["Salir", ui.close], ["Descansar 45 min (+30 energía)", _rest_at_home]]))
	else:
		var text := "¿Terminar el día y dormir? Recibirás tu salario de $%d." % GameState.salary()
		ui.open(Dialogs.info("Tu apartamento", text, [["Todavía no", ui.close], ["Dormir hasta mañana", _sleep]]))


func _rest_at_home() -> void:
	GameState.minutes += 45.0
	GameState.add_energy(30.0)
	ui.close()
	ui.toast("Descansaste un poco. Ahora son las %s." % GameState.clock_text(), "good")


func _on_shift_ended() -> void:
	ui.open(Dialogs.day_summary(false, ui.close, _sleep), Callable(), true, 900.0)


func _open_pause() -> void:
	ui.open(Dialogs.pause_menu(ui.close, _set_quality, _save_and_menu), Callable(), true, 760.0)


func _set_quality(q: int) -> void:
	GameState.quality = q
	day_night.apply_quality(q)
	ui.close()
	_open_pause()


func _save_and_menu() -> void:
	GameState.save_game()
	_restart()


func _sleep() -> void:
	var pay := GameState.salary()
	GameState.earn(pay)
	GameState.start_next_day()
	work_day.plan_day()
	events.reset_day()
	_spawn_at_home()
	_low_energy_warned = false
	if ui.is_open():
		ui.close()
	ui.toast("Día %d. Salario recibido: +$%d. ¡A trabajar!" % [GameState.day, pay], "good", 6.0)


func _restart() -> void:
	if GameState.reputation <= 0.0:
		GameState.delete_save()
	get_tree().paused = false
	get_tree().reload_current_scene()
