extends Node
## Prueba automática de humo. Ejecutar:
##   godot --headless --path . -- --smoke-test
## Con ventana (o Xvfb) también guarda capturas:
##   godot --path . -- --smoke-test --shots=user://shots
## Recorre los flujos principales y termina con código 0 si todo salió bien.

var main: Node
var shots_dir := ""
var _failures: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	print("[smoke] %s %s" % ["OK  " if cond else "FAIL", what])
	if not cond:
		_failures.append(what)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [shots_dir, name])
	print("[smoke] captura ", name)


func _look(pos: Vector3, yaw: float, pitch := -0.15) -> void:
	main.player.spawn(pos, yaw)
	main.player.set("_pitch", pitch)
	await _wait(0.6)


func _night_probe() -> void:
	GameState.minutes = 20 * 60
	await _look(Vector3(-8, 0.3, -20), 0.3, 0.02)
	if main.ui.is_open():
		main.ui.close()
	main.started = false  # congelar el reloj para dar tiempo al cálculo de la luz ambiental
	await _shot("night_0_inmediato")
	for i in 60:
		await get_tree().process_frame
	await _shot("night_a_base")
	for l in main.city.night_lights:
		l.visible = false
	await _frames(20)
	await _shot("night_b_sin_farolas")
	main.day_night.env.ambient_light_energy = 0.0
	await _frames(20)
	await _shot("night_c_sin_ambiente")
	main.day_night.env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	main.day_night.env.fog_enabled = false
	await _frames(20)
	await _shot("night_d_sin_reflejos_ni_niebla")
	get_tree().quit(0)


func _run() -> void:
	await _wait(0.5)
	main._start_game(false)
	if "--night-probe" in OS.get_cmdline_user_args():
		await _night_probe()
		return
	_check(main.started and not get_tree().paused, "inicio de partida")
	await _wait(1.0)
	await _shot("01_casa_parque")

	# Generación de todos los tipos de reto
	for id in ChallengeBank.FILES:
		var ch := ChallengeBank.generate(id)
		var rows: Array = ch["rows"]
		var bad := rows.filter(func(r): return r["bad"]).size()
		_check(rows.size() >= 4 and bad >= 1 and str(ch["title"]).find("{") < 0, "reto %s (%d filas, %d maliciosas)" % [id, rows.size(), bad])

	# Jornada: forzar la llegada de incidentes
	GameState.minutes = Config.SHIFT_START + 200.0
	main.work_day.update()
	_check(main.work_day.pending().size() > 0, "incidentes programados (%d)" % main.work_day.pending().size())

	# Consola SOC: los tres pasos
	main._open_console()
	await _wait(0.3)
	_check(get_tree().paused, "la consola pausa el juego")
	await _shot("05_consola_soc")
	var console: SocConsole = main.ui._center.get_child(0).get_child(0)
	var inc: Dictionary = main.work_day.pending()[0]
	var selected := {0: true}
	console._render_action(inc, selected)
	await _wait(0.2)
	console._render_result(inc, selected, 0)
	await _wait(0.3)
	await _shot("06_resultado_incidente")
	_check(inc["status"] == "resolved", "incidente resuelto con puntaje %d" % int(inc["result"]["score"]))
	main.ui.close()
	_check(not get_tree().paused, "cerrar la consola reanuda el juego")

	# Tienda
	var money_before := GameState.money
	var cafe: Dictionary = main.city.businesses["cafeteria"]["def"]
	main._open_shop(cafe)
	await _wait(0.3)
	await _shot("07_tienda")
	var items: Array = cafe["items"]
	var energy_before := GameState.energy
	GameState.energy = 50.0
	main.ui.close()
	GameState.spend(int(items[0]["price"]))
	_check(GameState.money == money_before - int(items[0]["price"]), "compra en la cafetería")
	GameState.energy = energy_before

	# Evento de ciudad
	main.events._spawn()
	_check(not main.events.active.is_empty(), "aparece un evento de ciudad")
	if not main.events.active.is_empty():
		var ev: Dictionary = main.events.active[0]["def"]
		main._open_event(ev)
		await _wait(0.3)
		await _shot("08_evento_ciudad")
		var res: Dictionary = main.events.resolve(ev, 1)
		_check(res.has("outcome"), "evento resuelto (%s)" % res["outcome"])
		main.ui.close()

	# Paseo: el jugador camina
	var start: Vector3 = main.player.global_position
	Input.action_press("move_forward")
	await _wait(1.5)
	Input.action_release("move_forward")
	_check(main.player.global_position.distance_to(start) > 2.0, "el jugador camina (%.1f m)" % main.player.global_position.distance_to(start))

	# Vistas de la ciudad
	GameState.minutes = 10 * 60
	main.day_night.update(GameState.minutes)
	await _look(Vector3(0, 0.3, 14), 0.0, -0.05)
	await _shot("02_parque_hacia_cybershield")
	await _look(Vector3(-40, 0.3, -24), -PI / 2.0 + 0.5, -0.12)
	await _shot("03_calle_comercial")
	var shop: Dictionary = main.city.businesses["supermercado"]
	await _look(shop["door"] + Vector3(0, 0.1, 0), shop["look_yaw"], -0.05)
	await _shot("04_fachada_supermercado")
	main.player.toggle_camera()
	await _look(shop["inside"] + Vector3(0, 0.1, 0), shop["look_yaw"], -0.15)
	await _shot("04b_interior_supermercado")
	var cafe_place: Dictionary = main.city.businesses["cafeteria"]
	await _look(cafe_place["inside"] + Vector3(0, 0.1, 0), cafe_place["look_yaw"], -0.2)
	await _shot("04c_interior_cafeteria")
	await _look(Vector3(0, 0.3, -46), 0.0, -0.05)
	await _shot("09_oficina_soc")
	main.player.toggle_camera()
	GameState.minutes = 20 * 60
	main.day_night.update(GameState.minutes)
	await _look(Vector3(-8, 0.3, -20), 0.3, 0.02)
	if main.ui.is_open():
		await _shot("11_resumen_dia")
		main.ui.close()
	await _wait(0.5)
	await _shot("10_noche")

	# Fin de jornada, casa y nuevo día
	var day := GameState.day
	main._on_home()
	await _wait(0.2)
	main._sleep()
	_check(GameState.day == day + 1 and not get_tree().paused, "dormir inicia el día %d" % GameState.day)

	# Menú de pausa y calidad
	main._open_pause()
	await _wait(0.2)
	main._set_quality(1)
	await _wait(0.2)
	main.ui.close()
	_check(GameState.quality == 1, "cambio de calidad gráfica")

	print("[smoke] %s" % ("TODO OK" if _failures.is_empty() else "FALLOS: %s" % ", ".join(PackedStringArray(_failures))))
	get_tree().quit(0 if _failures.is_empty() else 1)
