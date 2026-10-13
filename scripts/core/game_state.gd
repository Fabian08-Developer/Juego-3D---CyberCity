extends Node
## Estado persistente del jugador (autoload "GameState").
## Se guarda en user:// al terminar cada día.

signal leveled_up(title: String)

const SAVE_PATH := "user://cybercity_save.json"

var day := 1
var minutes: float = Config.DAY_START
var money: int = Config.START_MONEY
var reputation: float = Config.START_REPUTATION
var energy := 100.0
var xp := 0
var quality := 2  # 0 baja, 1 media, 2 alta
var today := {}


func _ready() -> void:
	reset_today()


func reset_today() -> void:
	today = {"resolved": 0, "expired": 0, "earned": 0, "rep_delta": 0.0, "scores": [], "events_good": 0, "events_bad": 0}


func new_game() -> void:
	day = 1
	minutes = Config.DAY_START
	money = Config.START_MONEY
	reputation = Config.START_REPUTATION
	energy = 100.0
	xp = 0
	reset_today()


func clock_text() -> String:
	var m := int(minutes)
	return "%02d:%02d" % [m / 60, m % 60]


func add_reputation(delta: float) -> void:
	var before := reputation
	reputation = clampf(reputation + delta, 0.0, 100.0)
	today["rep_delta"] += reputation - before


func add_energy(delta: float) -> void:
	energy = clampf(energy + delta, 0.0, 100.0)


func earn(amount: int) -> void:
	money += amount
	today["earned"] += amount


func spend(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	return true


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	var before := career_level()
	xp += amount
	var after := career_level()
	if after > before:
		leveled_up.emit(career_title())


func career_level() -> int:
	var level := 0
	for i in Config.CAREER.size():
		if xp >= int(Config.CAREER[i]["xp"]):
			level = i
	return level


func career_title() -> String:
	return Config.CAREER[career_level()]["title"]


## Progreso 0..1 hacia el siguiente nivel.
func career_progress() -> float:
	var level := career_level()
	if level >= Config.CAREER.size() - 1:
		return 1.0
	var a := int(Config.CAREER[level]["xp"])
	var b := int(Config.CAREER[level + 1]["xp"])
	return float(xp - a) / float(b - a)


func salary() -> int:
	return int(Config.BASE_SALARY * float(Config.CAREER[career_level()]["salary"]))


func start_next_day() -> void:
	day += 1
	minutes = Config.DAY_START
	energy = 100.0
	reset_today()
	save_game()


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("No se pudo guardar la partida")
		return
	f.store_string(JSON.stringify({"day": day, "money": money, "reputation": reputation, "xp": xp, "quality": quality}))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		return false
	new_game()
	day = int(data.get("day", 1))
	money = int(data.get("money", Config.START_MONEY))
	reputation = float(data.get("reputation", Config.START_REPUTATION))
	xp = int(data.get("xp", 0))
	quality = int(data.get("quality", 2))
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
