/** RNG determinista (mulberry32) para que la ciudad sea siempre igual. */
export function seededRandom(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export const randInt = (min: number, max: number, rnd = Math.random) =>
  Math.floor(rnd() * (max - min + 1)) + min;

export const pick = <T>(arr: readonly T[], rnd = Math.random): T => arr[Math.floor(rnd() * arr.length)];

export function shuffle<T>(arr: T[], rnd = Math.random): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

export const sample = <T>(arr: readonly T[], n: number, rnd = Math.random): T[] =>
  shuffle([...arr], rnd).slice(0, n);
