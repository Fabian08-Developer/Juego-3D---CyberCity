/** Parámetros globales de juego. Ajustar aquí el balance sin tocar la lógica. */
export const CONFIG = {
  // Jugador
  walkSpeed: 4.2,
  runSpeed: 7.5,
  jumpSpeed: 5.5,
  gravity: 18,
  playerRadius: 0.35,
  eyeHeight: 1.65,
  mouseSensitivity: 0.0022,
  thirdPersonDistance: 4.2,

  // Tiempo (minutos de juego)
  timeScale: 1.5, // minutos de juego por segundo real
  dayStart: 7 * 60 + 30,
  shiftStart: 8 * 60,
  shiftEnd: 17 * 60,

  // Economía y estado
  startMoney: 40,
  startReputation: 50,
  dailySalary: 80,
  energyDrainPerMinute: 0.07,
  energyCostPerIncident: 5,
  lowEnergy: 20,
};

/** Trazado de la ciudad: cuadrícula de manzanas separadas por calles. */
export const CITY = (() => {
  const block = 36;
  const road = 12;
  const n = 3;
  const size = n * block + (n + 1) * road;
  const half = size / 2;
  const sidewalkHeight = 0.15;
  const blockCenter = (i: number) => -half + road + block / 2 + i * (block + road);
  const roadCenter = (k: number) => -half + road / 2 + k * (block + road);
  return { block, road, n, size, half, sidewalkHeight, blockCenter, roadCenter };
})();
