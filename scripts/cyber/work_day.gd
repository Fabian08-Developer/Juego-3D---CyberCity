class_name WorkDay
extends Node
## Jornada laboral: programa incidentes según el nivel de carrera, controla plazos y paga recompensas.

signal shift_started
signal incident_spawned(inc: Dictionary)
signal incident_expired(inc: Dictionary)
signal shift_ended

var incidents: Array = []
var _schedule: Array = []
var _next_id := 1
var _announced := false
var _ended := false


func plan_day() -> void:
	incidents.clear()
	_announced = GameState.minutes >= Config.SHIFT_START
	_ended = GameState.minutes >= Config.SHIFT_END
	var level := GameState.career_level()
	var cats := ChallengeBank.available_for_level(level)
	var count := clampi(4 + level + int(GameState.day / 2), 4, 12)
	var start := Config.SHIFT_START + 10.0
	var finish := Config.SHIFT_END - 80.0
	var slot := (finish - start) / count
	_schedule.clear()
	var bag := cats.duplicate()
	bag.shuffle()
	for i in count:
		if bag.is_empty():
			bag = cats.duplicate()
			bag.shuffle()
		_schedule.append({"at": start + i * slot + randf() * slot * 0.7, "category": bag.pop_back()})


func pending() -> Array:
	return incidents.filter(func(i): return i["status"] == "pending")


func update() -> void:
	var now := GameState.minutes
	if not _announced and now >= Config.SHIFT_START:
		_announced = true
		shift_started.emit()
	while not _schedule.is_empty() and float(_schedule[0]["at"]) <= now:
		var item: Dictionary = _schedule.pop_front()
		var ch := ChallengeBank.generate(item["category"])
		var window := 60.0 if ch["severity"] == "Crítica" else (80.0 if ch["severity"] == "Alta" else 110.0)
		var inc := {"id": _next_id, "ch": ch, "spawned": now, "deadline": minf(now + window, Config.SHIFT_END), "status": "pending", "result": {}}
		_next_id += 1
		incidents.append(inc)
		incident_spawned.emit(inc)
	for inc in pending():
		if now >= float(inc["deadline"]):
			inc["status"] = "expired"
			GameState.today["expired"] += 1
			GameState.add_reputation(-Config.INCIDENT_EXPIRED_PENALTY)
			incident_expired.emit(inc)
	if not _ended and now >= Config.SHIFT_END:
		_ended = true
		shift_ended.emit()


## Aplica el resultado de un reto. Devuelve {pay, rep, xp}.
func resolve(inc: Dictionary, result: Dictionary) -> Dictionary:
	inc["status"] = "resolved"
	inc["result"] = result
	var mult: float = ChallengeBank.SEVERITY_MULT.get(inc["ch"]["severity"], 1.0)
	var s: int = result["score"]
	var pay := int(round(s * 0.5 * mult))
	var rep := int(round((s - 60) / 8.0 * mult))
	var xp := int(round(s * 0.6 * mult))
	GameState.earn(pay)
	GameState.add_reputation(rep)
	GameState.add_energy(-Config.ENERGY_COST_PER_INCIDENT)
	GameState.add_xp(xp)
	GameState.today["resolved"] += 1
	GameState.today["scores"].append(s)
	return {"pay": pay, "rep": rep, "xp": xp}
