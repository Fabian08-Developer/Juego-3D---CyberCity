class_name DayNight
extends Node
## Ciclo de día y noche: sol, luna, cielo, niebla, farolas y ventanas que se encienden.

const SUNRISE := 6.0 * 60.0
const SUNSET := 18.5 * 60.0

var env := Environment.new()
var sky_mat := ProceduralSkyMaterial.new()
var sun := DirectionalLight3D.new()
var moon := DirectionalLight3D.new()
var night := 0.0
var _city: CityData
var _lights_on := false
var _last_night := -1.0
var _last_minute := -1


func setup(parent: Node, city: CityData) -> void:
	_city = city
	var sky := Sky.new()
	sky.sky_material = sky_mat
	# Incremental: la iluminación ambiental se recalcula en unos pocos cuadros tras cada cambio.
	# Por eso el cielo se actualiza una vez por minuto de juego y no en cada cuadro.
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.25
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	sun.light_angular_distance = 0.5
	parent.add_child(sun)
	moon.light_color = Color("#9fb8ff")
	moon.light_energy = 0.0
	moon.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-140), 0)
	parent.add_child(moon)
	apply_quality(GameState.quality)


## 0 = baja, 1 = media, 2 = alta.
func apply_quality(q: int) -> void:
	env.ssao_enabled = q >= 2
	env.glow_enabled = q >= 1
	sun.directional_shadow_max_distance = [70.0, 120.0, 180.0][clampi(q, 0, 2)]
	var vp := sun.get_viewport()
	if vp != null:
		vp.msaa_3d = Viewport.MSAA_2X if q >= 1 else Viewport.MSAA_DISABLED
	for l in _city.night_lights if _city != null else []:
		l.shadow_enabled = false


## Actualiza sol, cielo y luces. Solo recalcula cuando cambia el minuto de juego (o con `force`).
func update(minutes: float, force := false) -> void:
	var minute := int(minutes)
	if minute == _last_minute and not force:
		return
	_last_minute = minute
	var t := (minutes - SUNRISE) / (SUNSET - SUNRISE)
	var day := sin(clampf(t, 0.0, 1.0) * PI)
	night = 1.0 - smoothstep(0.0, 0.2, day)
	var elev := deg_to_rad(70.0) * day if t > 0.0 and t < 1.0 else deg_to_rad(-8.0)
	var az := PI / 2.0 - PI * clampf(t, 0.0, 1.0)
	sun.rotation = Vector3(-maxf(elev, deg_to_rad(2.0)), az, 0)
	sun.light_energy = 1.35 * smoothstep(0.0, 0.15, day)
	sun.visible = day > 0.005
	sun.light_color = Color("#ffad66").lerp(Color("#fff4e0"), smoothstep(0.0, 0.45, day))
	moon.light_energy = 0.06 * night

	var dusk := smoothstep(0.4, 0.05, day) * (1.0 - night)
	var top := Color("#03060f").lerp(Color("#2f6fc0"), 1.0 - night).lerp(Color("#3d4f8f"), dusk * 0.6)
	var hor := Color("#16264a").lerp(Color("#a8d2f0"), 1.0 - night).lerp(Color("#f2a273"), dusk)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor.darkened(0.2)
	sky_mat.ground_bottom_color = Color("#1d2a1a").lerp(Color("#3c5a32"), 1.0 - night)
	sky_mat.sky_energy_multiplier = lerpf(0.3, 1.0, 1.0 - night)
	env.ambient_light_energy = lerpf(0.45, 1.0, 1.0 - night)
	env.fog_light_color = hor

	var on := night > 0.35
	if on != _lights_on:
		_lights_on = on
		for l in _city.night_lights:
			l.visible = on
	if absf(night - _last_night) > 0.02:
		_last_night = night
		for m in Mats.night_materials:
			var a: float = m.get_meta("day_energy", 0.0)
			var b: float = m.get_meta("night_energy", 2.0)
			m.emission_energy_multiplier = lerpf(a, b, night)
