class_name Mats
extends RefCounted
## Fábrica de materiales y texturas procedurales (con caché).
## Todo el arte del prototipo se genera por código; ver docs/GDD.md para pasar a modelos glTF.

static var _cache := {}
## Materiales cuya emisión se enciende de noche (ventanas, farolas, faros).
static var night_materials: Array = []


static func color(hex: String, roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var key := "c|%s|%.2f|%.2f" % [hex, roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = roughness
	m.metallic = metallic
	_cache[key] = m
	return m


static func emissive(hex: String, energy := 2.0) -> StandardMaterial3D:
	var key := "e|%s|%.2f" % [hex, energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.emission_enabled = true
	m.emission = Color(hex)
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


## Material emisivo que solo brilla de noche (se registra en night_materials).
static func night_emissive(hex: String, day_energy := 0.0, night_energy := 4.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.emission_enabled = true
	m.emission = Color(hex)
	m.emission_energy_multiplier = day_energy
	m.set_meta("day_energy", day_energy)
	m.set_meta("night_energy", night_energy)
	night_materials.append(m)
	return m


static func glass(hex := "#8fd3ff", alpha := 0.3) -> StandardMaterial3D:
	var key := "g|%s|%.2f" % [hex, alpha]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	var c := Color(hex)
	c.a = alpha
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.6
	_cache[key] = m
	return m


static func _new_image(w: int, h: int, base: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(base)
	return img


static func _noise(img: Image, amount: float, rng: RandomNumberGenerator) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var v := rng.randf_range(-amount, amount)
			img.set_pixel(x, y, Color(clampf(c.r + v, 0, 1), clampf(c.g + v, 0, 1), clampf(c.b + v, 0, 1), c.a))


static func _texture(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Material con textura proyectada en coordenadas de mundo: `tile` = metros por repetición.
static func triplanar(tex: Texture2D, tile: float, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = roughness
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile
	return m


static func ground(kind: String) -> StandardMaterial3D:
	var key := "ground|" + kind
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var m: StandardMaterial3D
	match kind:
		"grass":
			var img := _new_image(128, 128, Color("#4f8a3a"))
			_noise(img, 0.06, rng)
			m = triplanar(_texture(img), 4.0, 1.0)
		"park_grass":
			var img := _new_image(128, 128, Color("#5c9e40"))
			_noise(img, 0.06, rng)
			m = triplanar(_texture(img), 3.0, 1.0)
		"asphalt":
			var img := _new_image(128, 128, Color("#2c2e33"))
			_noise(img, 0.035, rng)
			m = triplanar(_texture(img), 4.0, 0.95)
		"sidewalk":
			var img := _new_image(128, 128, Color("#b4b1aa"))
			_noise(img, 0.04, rng)
			img.fill_rect(Rect2i(0, 0, 128, 3), Color("#8e8b85"))
			img.fill_rect(Rect2i(0, 0, 3, 128), Color("#8e8b85"))
			m = triplanar(_texture(img), 2.0, 0.95)
		"tiles":
			var img := _new_image(128, 128, Color("#d9dde2"))
			_noise(img, 0.02, rng)
			img.fill_rect(Rect2i(0, 0, 128, 2), Color("#b5bac0"))
			img.fill_rect(Rect2i(0, 0, 2, 128), Color("#b5bac0"))
			m = triplanar(_texture(img), 1.0, 0.35)
		"wood":
			var img := _new_image(128, 128, Color("#9c6b3d"))
			for y in 128:
				if y % 16 == 0:
					img.fill_rect(Rect2i(0, y, 128, 2), Color("#6f4a28"))
			_noise(img, 0.04, rng)
			m = triplanar(_texture(img), 2.0, 0.7)
		"path":
			var img := _new_image(128, 128, Color("#cbc3b0"))
			_noise(img, 0.05, rng)
			m = triplanar(_texture(img), 2.0, 0.95)
		_:
			m = color("#ff00ff")
	_cache[key] = m
	return m


## Calle: asfalto con línea central amarilla y bordes blancos. La línea corre a lo largo de V (eje Z del plano).
static func road() -> StandardMaterial3D:
	if _cache.has("road"):
		return _cache["road"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var img := _new_image(128, 256, Color("#2c2e33"))
	_noise(img, 0.035, rng)
	img.fill_rect(Rect2i(60, 0, 3, 256), Color("#e8c547"))
	img.fill_rect(Rect2i(65, 0, 3, 256), Color("#e8c547"))
	img.fill_rect(Rect2i(3, 0, 3, 256), Color("#e6e6e6"))
	img.fill_rect(Rect2i(122, 0, 3, 256), Color("#e6e6e6"))
	var m := StandardMaterial3D.new()
	m.albedo_texture = _texture(img)
	m.roughness = 0.95
	_cache["road"] = m
	return m


## Fachada con ventanas (4x4 por repetición, 3.2 m x 3.4 m por ventana) y emisión nocturna.
## Incluye marcos, parteluces, alféizares, losas de piso y reflejo del cielo en el vidrio.
static func facade(wall_hex: String, curtain := false, variant := 0) -> StandardMaterial3D:
	var key := "facade|%s|%s|%d" % [wall_hex, curtain, variant]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var cw := 128
	var ch := 136
	var wall := Color(wall_hex)
	var img := _new_image(cw * 4, ch * 4, wall)
	var emit := _new_image(cw * 4, ch * 4, Color.BLACK)
	_noise(img, 0.025, rng)
	var glass_dark := Color("#1d3447")
	var glass_sky := Color("#6f93b3")
	for r in 4:
		var y0 := r * ch
		if not curtain:
			# Losa de piso y junta de paneles
			img.fill_rect(Rect2i(0, y0 + ch - 8, cw * 4, 8), wall.darkened(0.22))
			img.fill_rect(Rect2i(0, y0 + ch - 9, cw * 4, 1), wall.lightened(0.15))
		for c in 4:
			var x := c * cw
			var lit := rng.randf() < (0.2 if curtain else 0.3)
			var warm := Color("#ffd98a") if rng.randf() < 0.7 else Color("#bfe6ff")
			var blind := rng.randf() < 0.3
			if curtain:
				var gx := x + 3
				var gy := y0 + 3
				var gw := cw - 6
				var gh := ch - 26
				_gradient(img, Rect2i(gx, gy, gw, gh), glass_sky.lerp(Color("#9fc3df"), rng.randf() * 0.3), glass_dark)
				img.fill_rect(Rect2i(x, y0 + ch - 23, cw, 23), Color("#22303c"))  # antepecho
				img.fill_rect(Rect2i(x, y0, 3, ch), Color("#8c99a6"))  # montante
				img.fill_rect(Rect2i(x, y0 + ch - 24, cw, 2), Color("#8c99a6"))
				if lit:
					emit.fill_rect(Rect2i(gx + 6, gy + 6, gw - 12, gh - 12), warm * 0.75)
			else:
				var wx := x + 22
				var wy := y0 + 20
				var ww := cw - 44
				var wh := ch - 52
				img.fill_rect(Rect2i(wx - 5, wy - 5, ww + 10, wh + 10), wall.darkened(0.45))  # vano
				img.fill_rect(Rect2i(wx - 3, wy - 3, ww + 6, wh + 6), Color("#e8e6e1"))  # marco
				_gradient(img, Rect2i(wx, wy, ww, wh), glass_sky, glass_dark)
				if blind:
					img.fill_rect(Rect2i(wx, wy, ww, int(wh * 0.35)), Color("#d9cdb4"))
				img.fill_rect(Rect2i(wx + ww / 2 - 2, wy, 4, wh), Color("#e8e6e1"))  # parteluz
				img.fill_rect(Rect2i(wx, wy + int(wh * 0.38), ww, 3), Color("#e8e6e1"))
				img.fill_rect(Rect2i(wx - 8, wy + wh + 3, ww + 16, 6), wall.lightened(0.3))  # alféizar
				img.fill_rect(Rect2i(wx - 8, wy + wh + 9, ww + 16, 3), wall.darkened(0.3))
				if lit:
					emit.fill_rect(Rect2i(wx, wy, ww, wh), warm)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _texture(img)
	m.roughness = 0.3 if curtain else 0.85
	m.metallic = 0.35 if curtain else 0.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / 12.8, 1.0 / 13.6, 1.0 / 12.8)
	m.emission_enabled = true
	m.emission_texture = _texture(emit)
	# Con el operador por defecto (ADD) la emisión es color + textura: el color base debe ser negro
	# para que solo brillen las ventanas encendidas.
	m.emission = Color.BLACK
	m.emission_energy_multiplier = 0.0
	m.set_meta("day_energy", 0.0)
	m.set_meta("night_energy", 1.4)
	night_materials.append(m)
	_cache[key] = m
	return m


## Degradado vertical dentro de un rectángulo (reflejo del cielo en el vidrio).
static func _gradient(img: Image, rect: Rect2i, top: Color, bottom: Color) -> void:
	for i in rect.size.y:
		var t := float(i) / maxf(1.0, rect.size.y - 1.0)
		img.fill_rect(Rect2i(rect.position.x, rect.position.y + i, rect.size.x, 1), top.lerp(bottom, t))
