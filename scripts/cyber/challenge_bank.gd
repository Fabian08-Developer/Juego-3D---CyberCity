class_name ChallengeBank
extends RefCounted
## Genera retos a partir de los archivos JSON de data/challenges/.
##
## Para crear una categoría nueva: copia un JSON existente, cambia su contenido y
## añade su nombre a FILES. Marcadores disponibles en los textos:
##   {domain} {victim} {traveler} {workstation} {hour} {attacker_ip}  -> fijos por reto
##   {user} {host} {internal_ip} {rand_ip}                              -> nuevos en cada aparición

const FILES := ["phishing", "malware", "vulnerabilidades", "passwords", "intrusion", "firewall", "ransomware"]
const DOMAIN := "cybershield.lat"
const EMPLOYEES := ["ana.gomez", "carlos.ruiz", "laura.mendez", "diego.torres", "sofia.rios", "andres.vega", "valentina.paz", "julian.mora"]
const HOSTS := ["web-01", "web-02", "db-prod", "ftp-legacy", "app-erp", "dc-01", "mail-01", "cache-01", "logs-01", "vpn-gw", "files-01", "intranet"]
const SEVERITY_MULT := {"Baja": 0.8, "Media": 1.0, "Alta": 1.25, "Crítica": 1.5}

static var _defs := {}


static func definitions() -> Dictionary:
	if _defs.is_empty():
		for id in FILES:
			var data = CityBuilder.load_json("res://data/challenges/%s.json" % id)
			if data is Dictionary:
				_defs[id] = data
			else:
				push_error("Reto inválido: %s" % id)
	return _defs


static func category_name(id: String) -> String:
	return str(definitions().get(id, {}).get("name", id))


static func available_for_level(level: int) -> Array:
	var out := []
	for id in definitions():
		if int(definitions()[id].get("min_level", 0)) <= level:
			out.append(id)
	return out


static func _attacker_ip() -> String:
	return "%s.%d" % [["203.0.113", "198.51.100", "192.0.2"].pick_random(), randi_range(2, 254)]


static func _internal_ip() -> String:
	return "10.20.%d.%d" % [randi_range(1, 30), randi_range(2, 250)]


static func _fill(text: String, ctx: Dictionary) -> String:
	for key in ctx:
		text = text.replace("{%s}" % key, str(ctx[key]))
	var dynamic := {
		"{user}": func(): return EMPLOYEES.pick_random(),
		"{host}": func(): return HOSTS.pick_random(),
		"{internal_ip}": func(): return _internal_ip(),
		"{rand_ip}": func(): return _attacker_ip(),
	}
	for token in dynamic:
		var i := text.find(token)
		while i >= 0:
			text = text.substr(0, i) + str(dynamic[token].call()) + text.substr(i + token.length())
			i = text.find(token)
	return text


static func _pick(pool: Array, range_: Array) -> Array:
	var required := pool.filter(func(r): return r.get("required", false))
	var optional := pool.filter(func(r): return not r.get("required", false))
	optional.shuffle()
	var n := randi_range(int(range_[0]), int(range_[1]))
	var out := required.duplicate()
	for r in optional:
		if out.size() >= maxi(n, required.size()):
			break
		out.append(r)
	return out


## Devuelve un reto listo para jugar:
## {category, name, title, severity, briefing, instruction, columns, rows:[{cells, bad, why}], action:{question, options:[{text, correct, feedback}]}}
static func generate(id: String) -> Dictionary:
	var def: Dictionary = definitions()[id]
	var victim: String = EMPLOYEES.pick_random()
	var ctx := {
		"domain": DOMAIN,
		"victim": victim,
		"traveler": EMPLOYEES.filter(func(e): return e != victim).pick_random(),
		"workstation": "WS-%d" % randi_range(100, 499),
		"hour": str(randi_range(1, 4)),
		"attacker_ip": _attacker_ip(),
	}
	var pick: Dictionary = def.get("pick", {"bad": [2, 3], "good": [3, 3]})
	var rows := []
	for r in _pick(def.get("bad", []), pick["bad"]):
		rows.append(_row(r, true, ctx))
	for r in _pick(def.get("good", []), pick["good"]):
		rows.append(_row(r, false, ctx))
	rows.shuffle()
	if def.has("sort_column"):
		var col := int(def["sort_column"])
		rows.sort_custom(func(a, b): return str(a["cells"][col]) < str(b["cells"][col]))

	var act: Dictionary = def["action"]
	var options := [{"text": act["correct"]["text"], "feedback": act["correct"]["feedback"], "correct": true}]
	var wrong: Array = act["wrong"].duplicate()
	wrong.shuffle()
	for w in wrong.slice(0, 3):
		options.append({"text": w["text"], "feedback": w["feedback"], "correct": false})
	options.shuffle()

	return {
		"category": id,
		"name": def.get("name", id),
		"title": _fill(str(def.get("titles", ["Incidente"]).pick_random()), ctx),
		"severity": def.get("severities", ["Media"]).pick_random(),
		"briefing": _fill(str(def.get("briefing", "")), ctx),
		"instruction": def.get("instruction", "Marca los elementos sospechosos."),
		"columns": def.get("columns", []),
		"rows": rows,
		"action": {"question": act["question"], "options": options},
	}


static func _row(r: Dictionary, bad: bool, ctx: Dictionary) -> Dictionary:
	var cells := []
	for c in r["cells"]:
		cells.append(_fill(str(c), ctx))
	return {"cells": cells, "bad": bad, "why": _fill(str(r.get("why", "")), ctx)}


## Puntaje 0-100: 70 % por clasificar bien cada fila + 30 % por la respuesta correcta.
static func score(ch: Dictionary, selected: Dictionary, option_index: int) -> Dictionary:
	var rows: Array = ch["rows"]
	var ok := 0
	for i in rows.size():
		if bool(rows[i]["bad"]) == selected.has(i):
			ok += 1
	var options: Array = ch["action"]["options"]
	var action_ok := option_index >= 0 and option_index < options.size() and bool(options[option_index]["correct"])
	var total := int(round(float(ok) / float(rows.size()) * 70.0 + (30.0 if action_ok else 0.0)))
	return {"score": total, "rows_ok": ok, "rows_total": rows.size(), "action_ok": action_ok}
