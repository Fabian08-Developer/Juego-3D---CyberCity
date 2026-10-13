class_name HQ
extends Node3D
## Sede de CyberShield: lobby, oficina abierta, SOC con muro de pantallas en vivo,
## cuarto de servidores, sala de reuniones y torre de 40 m.

const X0 := -16.0
const X1 := 16.0
const Z0 := -66.0  # fondo
const Z1 := -40.0  # fachada (mira al sur, hacia el parque)
const FH := 5.0
const DOOR := 1.5

var hooks := {}
var _coworkers: Array = []
var _alert_label: Label3D
var _monitor_labels: Array = []
var _bars: Array = []
var _dots: Array = []
var _leds: Array = []
var _time := 0.0
var _acc := 1.0
var _y := Config.SIDEWALK_H


func build(city: CityData, hook_map: Dictionary) -> void:
	hooks = hook_map
	_shell()
	_tower()
	_lobby()
	_office()
	_soc_wall()
	_server_room()
	_meeting_room()
	_plaza(city)
	city.add_shape(X0, Z0, X1, Z1, Color("#00b8d9"), "CyberShield")
	city.markers["hq"] = Vector3(0, _y, Z1 + 3.0)
	city.markers["workstation"] = Vector3(0, _y, -56.6)


func _p(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, _y + y, z)


func _wall(x0: float, z0: float, x1: float, z1: float, mat: Material, y0 := 0.0, y1 := FH, collide := true) -> MeshInstance3D:
	return Geo.box(self, Vector3(x1 - x0, y1 - y0, z1 - z0), _p((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), mat, collide)


func _shell() -> void:
	var wall := Mats.color("#dfe3e8", 0.9)
	var dark := Mats.color("#1d2430", 0.5)
	var glass := Mats.glass("#7fc8ff", 0.25)
	_wall(X0, Z0, X1, Z0 + 0.4, wall)
	_wall(X0, Z0, X0 + 0.4, Z1, wall)
	_wall(X1 - 0.4, Z0, X1, Z1, wall)
	_wall(X0, Z1 - 0.2, -DOOR, Z1, glass)
	_wall(DOOR, Z1 - 0.2, X1, Z1, glass)
	_wall(-DOOR, Z1 - 0.3, DOOR, Z1, dark, 3.0, FH, false)
	for x in [X0 + 0.2, -DOOR - 0.15, DOOR + 0.15, X1 - 0.2, -8.0, 8.0]:
		_wall(x - 0.15, Z1 - 0.35, x + 0.15, Z1 + 0.05, dark, 0.0, FH, false)
	var door := SlidingDoor.new(DOOR * 2.0 - 0.1, 3.0)
	door.position = _p(0, 0, Z1 - 0.1)
	add_child(door)
	# Piso y paneles de luz
	Geo.box(self, Vector3(X1 - X0 - 0.8, 0.02, Z1 - Z0 - 0.6), _p(0, 0.011, (Z0 + Z1) / 2.0), Mats.ground("tiles"), false, false)
	var panel := Mats.emissive("#ffffff", 1.6)
	for x in [-10.0, 0.0, 10.0]:
		for z in [-62.0, -55.0, -48.0, -43.0]:
			Geo.box(self, Vector3(2.6, 0.05, 0.8), _p(x, FH - 0.04, z), panel, false, false)
	for pos in [Vector3(-7, 0, -55), Vector3(7, 0, -55), Vector3(0, 0, -45), Vector3(0, 0, -61)]:
		var light := OmniLight3D.new()
		light.position = _p(pos.x, FH - 0.6, pos.z)
		light.omni_range = 14.0
		light.light_energy = 1.2
		light.light_color = Color("#f4f8ff")
		add_child(light)


func _tower() -> void:
	var h := 40.0
	var w := X1 - X0
	var d := Z1 - Z0
	Geo.box(self, Vector3(w, h, d), _p(0, FH + h / 2.0, (Z0 + Z1) / 2.0), Mats.facade("#0e2233", true, 3), false)
	var dark := Mats.color("#151b24", 0.6)
	Geo.box(self, Vector3(w + 0.6, 0.6, d + 0.6), _p(0, FH + 0.3, (Z0 + Z1) / 2.0), dark, false)
	Geo.box(self, Vector3(w - 6, 3.0, d - 6), _p(0, FH + h + 1.5, (Z0 + Z1) / 2.0), dark, false)
	Geo.mesh(self, Geo.cylinder_mesh(0.12, 0.2, 8.0, 8), _p(6, FH + h + 7.0, -53), dark)
	Geo.mesh(self, Geo.sphere_mesh(0.3), _p(6, FH + h + 11.2, -53), Mats.emissive("#ff2030", 4.0), false)
	var big := Geo.label(self, "CYBERSHIELD", _p(0, FH + h - 4.0, Z1 + 0.06), 256, Color(0.4, 1.8, 2.2), 0.014)
	big.outline_size = 0
	Geo.label(self, "CYBERSHIELD", _p(0, 3.95, Z1 + 0.1), 96, Color(0.4, 1.8, 2.2), 0.01)
	Geo.label(self, "Seguridad digital para tu empresa", _p(0, 3.4, Z1 + 0.1), 40, Color(0.85, 0.95, 1.0), 0.008)


func _desk(x: float, z: float, screen_text := "") -> void:
	var top := Mats.color("#f4f4f2", 0.6)
	var leg := Mats.color("#555b63", 0.4, 0.5)
	Geo.box(self, Vector3(2.4, 0.06, 1.0), _p(x, 0.75, z), top, false)
	for sx in [-1.1, 1.1]:
		Geo.box(self, Vector3(0.06, 0.75, 0.9), _p(x + sx, 0.375, z), leg, false)
	Geo.add_box_collider(self, Vector3(2.4, 0.8, 1.0), _p(x, 0.4, z))
	var screen := Mats.emissive("#0b2236", 0.8)
	for mx in [-0.45, 0.45]:
		var mon := Geo.box(self, Vector3(0.8, 0.5, 0.05), _p(x + mx, 1.13, z - 0.25), screen, false)
		mon.rotation.y = 0.15 if mx < 0 else -0.15
		Geo.box(self, Vector3(0.06, 0.3, 0.06), _p(x + mx, 0.9, z - 0.28), leg, false)
		if screen_text != "":
			var l := Geo.label(self, screen_text, _p(x + mx, 1.15, z - 0.22), 20, Color(0.3, 1.6, 1.9), 0.004)
			l.rotation.y = mon.rotation.y
			_monitor_labels.append(l)
	Geo.box(self, Vector3(0.6, 0.03, 0.2), _p(x, 0.79, z + 0.15), Mats.color("#1d2430"), false)
	Geo.box(self, Vector3(0.6, 0.9, 0.6), _p(x, 0.45, z + 1.0), Mats.color("#262c36", 0.7), false)


func _lobby() -> void:
	# Recepción
	Geo.box(self, Vector3(4.0, 1.1, 1.0), _p(-8, 0.55, -44), Mats.color("#1d2430", 0.4))
	Geo.box(self, Vector3(4.2, 0.06, 1.15), _p(-8, 1.12, -44), Mats.ground("wood"), false)
	Geo.label(self, "RECEPCIÓN", _p(-8, 0.7, -43.48), 40, Color(0.4, 1.8, 2.2), 0.007)
	var receptionist := Person.new().setup(Person.random_colors(), true)
	receptionist.position = _p(-8, 0, -45.2)
	add_child(receptionist)
	Interactable.create(self, _p(-8, 0, -42.4), "Hablar con recepción", hooks.get("on_reception", func(): pass), 1.8)
	# Torniquetes de acceso (decorativos)
	var metal := Mats.color("#9aa1a9", 0.3, 0.7)
	for x in [-2.2, -0.6, 0.6, 2.2]:
		Geo.box(self, Vector3(0.25, 1.0, 1.0), _p(x, 0.5, -46.5), metal, false)
		Geo.box(self, Vector3(0.12, 0.08, 0.12), _p(x, 1.05, -46.2), Mats.emissive("#3ddc84", 2.0), false, false)
	# Sofá y plantas
	var sofa := Mats.color("#2b3a55", 0.8)
	Geo.box(self, Vector3(3.0, 0.45, 0.9), _p(8, 0.225, -43), sofa)
	Geo.box(self, Vector3(3.0, 0.6, 0.2), _p(8, 0.7, -43.4), sofa, false)
	for x in [-4.0, 4.0, 13.5]:
		Geo.mesh(self, Geo.cylinder_mesh(0.35, 0.3, 0.6, 12), _p(x, 0.3, Z1 - 1.2), Mats.color("#3a3a3a"))
		Geo.mesh(self, Geo.sphere_mesh(0.6, 8, 5), _p(x, 1.1, Z1 - 1.2), Mats.color("#2f8f3a", 0.9))
		Geo.add_cylinder_collider(self, 0.4, 1.4, _p(x, 0.7, Z1 - 1.2))
	# Ascensores
	for z in [-45.0, -42.5]:
		Geo.box(self, Vector3(0.1, 2.6, 1.8), _p(X0 + 0.46, 1.3, z), Mats.color("#b8c0c8", 0.2, 0.9), false)
	Geo.label(self, "ASCENSORES", _p(X0 + 0.55, 2.95, -43.75), 32, Color.WHITE, 0.007).rotation.y = PI / 2.0
	Interactable.create(self, _p(X0 + 1.6, 0, -43.75), "Ascensor (pisos 2-12)", hooks.get("on_elevator", func(): pass), 1.6)


func _office() -> void:
	# Estación de trabajo del jugador frente al muro del SOC
	_desk(0, -58.0, "SOC CONSOLE\nsin alertas")
	Interactable.create(self, _p(0, 0, -56.6), "Usar estación de trabajo (Consola SOC)", hooks.get("on_workstation", func(): pass), 1.6)
	# Compañeros
	var names := ["Laura (Analista N2)", "Diego (Threat Hunter)", "Sofía (Analista N1)", "Andrés (Ing. de redes)"]
	var spots := [Vector3(-5, 0, -51), Vector3(5, 0, -51), Vector3(-5, 0, -47.5), Vector3(5, 0, -47.5)]
	for i in spots.size():
		var p: Vector3 = spots[i]
		_desk(p.x, p.z)
		var person := Person.new().setup(Person.random_colors(), true)
		person.position = _p(p.x, 0, p.z + 0.85)
		person.rotation.y = PI
		add_child(person)
		_coworkers.append(person)
		var who: String = names[i]
		Interactable.create(self, _p(p.x + 1.4, 0, p.z + 1.2), "Hablar con " + who, func(): hooks.get("on_coworker", func(_n): pass).call(who), 1.3)


func _soc_wall() -> void:
	var dark := Mats.color("#0d131b", 0.5)
	var panel := Mats.emissive("#04121c", 0.6)
	var titles := ["MAPA DE AMENAZAS", "TRÁFICO DE RED", "ALERTAS ACTIVAS"]
	for i in 3:
		var x := -9.0 + i * 9.0
		Geo.box(self, Vector3(8.0, 3.6, 0.1), _p(x, 2.75, Z0 + 0.46), dark, false)
		Geo.box(self, Vector3(7.6, 3.2, 0.05), _p(x, 2.75, Z0 + 0.53), panel, false, false)
		Geo.label(self, titles[i], _p(x - 2.0, 4.05, Z0 + 0.57), 36, Color(0.3, 1.6, 1.9), 0.008)
	# Mapa: puntos que parpadean
	for k in 14:
		var dot_mat := Mats.emissive("#ff5470" if k % 3 == 0 else "#00e5ff", 3.0).duplicate() as StandardMaterial3D
		var dot := Geo.box(self, Vector3(0.12, 0.12, 0.02), _p(-12.2 + fmod(k * 2.37, 6.4), 1.6 + fmod(k * 1.13, 2.0), Z0 + 0.57), dot_mat, false, false)
		_dots.append(dot)
	# Tráfico: barras animadas
	var bar_mat := Mats.emissive("#3ddc84", 2.5)
	for k in 24:
		var bar := Geo.box(self, Vector3(0.18, 1.0, 0.02), _p(-3.3 + k * 0.28, 1.4, Z0 + 0.57), bar_mat, false, false)
		_bars.append(bar)
	# Alertas: texto en vivo
	_alert_label = Geo.label(self, "", _p(9, 2.55, Z0 + 0.57), 52, Color(1.0, 0.75, 0.3), 0.006)
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.width = 1150
	_alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _server_room() -> void:
	var glass := Mats.glass("#7fc8ff", 0.22)
	_wall(10.0, -58.0, 10.15, -54.0, glass)
	_wall(10.0, -51.5, 10.15, -48.0, glass)
	_wall(10.0, -48.15, X1 - 0.4, -48.0, glass)
	_wall(10.0, -58.15, X1 - 0.4, -58.0, glass)
	Geo.label(self, "CUARTO DE SERVIDORES · Acceso restringido", _p(10.2, 3.6, -52.75), 28, Color(1, 0.4, 0.45), 0.007).rotation.y = -PI / 2.0
	var rack := Mats.color("#15191f", 0.5, 0.4)
	for i in 5:
		var z := -57.0 + i * 1.8
		Geo.box(self, Vector3(1.0, 2.4, 1.3), _p(14.7, 1.2, z), rack)
		for j in 6:
			var led_mat := Mats.emissive("#00ff88" if j % 3 else "#00bfff", 2.0).duplicate() as StandardMaterial3D
			_leds.append(led_mat)
			Geo.box(self, Vector3(0.02, 0.05, 0.7), _p(14.18, 0.5 + j * 0.32, z), led_mat, false, false)
	var cold := OmniLight3D.new()
	cold.position = _p(13, 4.2, -53)
	cold.light_color = Color("#9fd8ff")
	cold.light_energy = 0.9
	cold.omni_range = 7.0
	add_child(cold)


func _meeting_room() -> void:
	var glass := Mats.glass("#7fc8ff", 0.22)
	_wall(-10.15, -58.0, -10.0, -54.0, glass)
	_wall(-10.15, -51.5, -10.0, -48.0, glass)
	_wall(X0 + 0.4, -48.15, -10.0, -48.0, glass)
	_wall(X0 + 0.4, -58.15, -10.0, -58.0, glass)
	Geo.box(self, Vector3(2.0, 0.08, 4.5), _p(-13, 0.76, -53), Mats.ground("wood"))
	Geo.add_box_collider(self, Vector3(2.0, 0.8, 4.5), _p(-13, 0.4, -53))
	for z in [-54.5, -53.0, -51.5]:
		for side in [-1.0, 1.0]:
			Geo.box(self, Vector3(0.5, 0.5, 0.5), _p(-13 + side * 1.4, 0.25, z), Mats.color("#262c36", 0.7), false)
	Geo.box(self, Vector3(0.05, 2.0, 4.0), _p(X0 + 0.45, 2.0, -53), Mats.color("#fbfbf8", 0.3), false)
	var board := Geo.label(self, "Respuesta a incidentes (NIST)\n1. Preparación\n2. Detección y análisis\n3. Contención, erradicación\n    y recuperación\n4. Lecciones aprendidas", _p(X0 + 0.5, 2.0, -53), 30, Color("#1d4ed8"), 0.006)
	board.rotation.y = PI / 2.0
	board.outline_size = 0
	board.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _plaza(city: CityData) -> void:
	var stone := Mats.color("#9ea3a8", 0.8)
	# Monolito con el logo
	Geo.box(self, Vector3(4.0, 2.2, 0.6), _p(-9, 1.1, -34.5), Mats.color("#151b24", 0.4))
	Geo.label(self, "CyberShield S.A.", _p(-9, 1.4, -34.18), 48, Color(0.4, 1.8, 2.2), 0.008)
	Geo.label(self, "Centro de Operaciones de Seguridad", _p(-9, 0.9, -34.18), 28, Color.WHITE, 0.007)
	# Jardineras y astas
	for x in [-13.0, 13.0]:
		Geo.box(self, Vector3(3.0, 0.6, 3.0), _p(x, 0.3, -36), stone)
		Geo.mesh(self, Geo.sphere_mesh(1.0, 8, 5), _p(x, 1.1, -36), Mats.color("#3c9a3f", 0.9))
	for x in [5.0, 7.0, 9.0]:
		Geo.mesh(self, Geo.cylinder_mesh(0.05, 0.07, 8.0, 8), _p(x, 4.0, -35), Mats.color("#c9ced4", 0.3, 0.8))
		Geo.box(self, Vector3(0.02, 1.0, 1.6), _p(x, 7.3, -34.2), Mats.color(["#fcd116", "#00e5ff", "#ffffff"][int(x) % 3], 0.8), false)
		Geo.add_cylinder_collider(self, 0.1, 8.0, _p(x, 4.0, -35))
	city.add_spot("hq_entrance", _p(3.5, 0, -37.5))
	city.add_spot("reception", _p(-5.5, 0, -42.5))


func _process(delta: float) -> void:
	_time += delta
	for i in _coworkers.size():
		var p: Person = _coworkers[i]
		p.set_typing(_time + i)
	for i in _bars.size():
		var bar: MeshInstance3D = _bars[i]
		var v := 0.35 + 0.3 * sin(_time * 1.7 + i * 0.6) + 0.2 * sin(_time * 4.1 + i * 1.3)
		bar.scale.y = maxf(0.08, v)
		bar.position.y = _y + 0.6 + bar.scale.y / 2.0
	_acc += delta
	if _acc < 0.4:
		return
	_acc = 0.0
	for dot in _dots:
		var mat: StandardMaterial3D = dot.material_override
		mat.emission_energy_multiplier = 4.0 if randf() < 0.5 else 0.3
	for led in _leds:
		led.emission_energy_multiplier = 2.5 if randf() < 0.7 else 0.1
	var lines: Array = hooks.get("alert_lines", func(): return []).call()
	if lines.is_empty():
		_alert_label.text = "Todo en orden.\nMonitoreando la red…"
		_alert_label.modulate = Color(0.3, 1.6, 0.8)
	else:
		_alert_label.text = "\n".join(PackedStringArray(lines.slice(0, 6)))
		_alert_label.modulate = Color(1.6, 0.6, 0.5)
	var monitor_text := "SOC CONSOLE\n%d alerta(s)" % lines.size() if not lines.is_empty() else "SOC CONSOLE\nsin alertas"
	for l in _monitor_labels:
		l.text = monitor_text
