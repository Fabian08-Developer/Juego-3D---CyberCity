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


## Fachada con ventanas (4x4 por repetición) y emisión nocturna de ventanas encendidas.
static func facade(wall_hex: String, curtain := false, variant := 0) -> StandardMaterial3D:
	var key := "facade|%s|%s|%d" % [wall_hex, curtain, variant]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var cw := 64
	var ch := 68
	var wall := Color(wall_hex)
	var img := _new_image(cw * 4, ch * 4, wall)
	var emit := _new_image(cw * 4, ch * 4, Color.BLACK)
	_noise(img, 0.02, rng)
	for r in 4:
		for c in 4:
			var x := c * cw
			var y := r * ch
			var lit := rng.randf() < (0.2 if curtain else 0.3)
			var warm := Color("#ffd98a") if rng.randf() < 0.7 else Color("#bfe6ff")
			if curtain:
				img.fill_rect(Rect2i(x + 2, y + 2, cw - 4, ch - 4), Color("#1f4f73").lerp(Color("#3b7fae"), rng.randf() * 0.5))
				img.fill_rect(Rect2i(x + 2, y + 2, cw - 4, 8), Color(1, 1, 1, 0.15).blend(Color("#2d6a96")))
				if lit:
					emit.fill_rect(Rect2i(x + 10, y + 10, cw - 20, ch - 20), warm * 0.7)
			else:
				img.fill_rect(Rect2i(x + 9, y + 10, cw - 18, ch - 22), wall.darkened(0.35))
				img.fill_rect(Rect2i(x + 11, y + 12, cw - 22, ch - 26), Color("#2c3e50").lerp(Color("#4a6b85"), rng.randf() * 0.4))
				img.fill_rect(Rect2i(x + 8, y + ch - 12, cw - 16, 4), wall.lightened(0.25))
				if lit:
					emit.fill_rect(Rect2i(x + 11, y + 12, cw - 22, ch - 26), warm)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _texture(img)
	m.roughness = 0.35 if curtain else 0.85
	m.metallic = 0.4 if curtain else 0.0
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
