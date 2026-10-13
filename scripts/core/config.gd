class_name Config
extends RefCounted
## Parámetros globales de balance y trazado de la ciudad.
## Ajusta aquí la dificultad sin tocar la lógica del juego.

# --- Jugador ---
const WALK_SPEED := 4.2
const RUN_SPEED := 7.8
const JUMP_VELOCITY := 5.2
const MOUSE_SENSITIVITY := 0.0025
const THIRD_PERSON_DISTANCE := 4.0
const STEP_HEIGHT := 0.35

# --- Tiempo (minutos de juego) ---
const TIME_SCALE := 1.0  # minutos de juego por segundo real
const DAY_START := 7 * 60 + 30
const SHIFT_START := 8 * 60
const SHIFT_END := 17 * 60
const NIGHT_END := 23 * 60

# --- Economía y estado ---
const START_MONEY := 40
const START_REPUTATION := 50.0
const BASE_SALARY := 80
const ENERGY_DRAIN_PER_MINUTE := 0.06
const ENERGY_COST_PER_INCIDENT := 5.0
const LOW_ENERGY := 20.0
const INCIDENT_EXPIRED_PENALTY := 6.0

# --- Carrera profesional (XP acumulada) ---
const CAREER := [
	{"xp": 0, "title": "Analista SOC Junior (N1)", "salary": 1.0},
	{"xp": 300, "title": "Analista SOC (N2)", "salary": 1.3},
	{"xp": 800, "title": "Threat Hunter", "salary": 1.7},
	{"xp": 1600, "title": "Líder del SOC", "salary": 2.2},
	{"xp": 3000, "title": "CISO", "salary": 3.0},
]

# --- Ciudad: cuadrícula de manzanas separadas por calles ---
const BLOCK := 40.0
const ROAD := 12.0
const BLOCKS := 3
const SIDEWALK_H := 0.15
const SIZE := BLOCKS * BLOCK + (BLOCKS + 1) * ROAD
const HALF := SIZE / 2.0
const LANE_OFFSET := 3.0


static func block_center(i: int) -> float:
	return -HALF + ROAD + BLOCK / 2.0 + i * (BLOCK + ROAD)


static func road_center(k: int) -> float:
	return -HALF + ROAD / 2.0 + k * (BLOCK + ROAD)
