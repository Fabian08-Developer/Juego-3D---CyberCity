import * as THREE from 'three';

export interface PersonColors {
  skin: string;
  shirt: string;
  pants: string;
  hair: string;
}

const SKINS = ['#f1c27d', '#e0ac69', '#c68642', '#8d5524', '#ffdbac'];
const SHIRTS = ['#3b82f6', '#ef4444', '#10b981', '#f59e0b', '#8b5cf6', '#ec4899', '#64748b', '#f8fafc'];
const PANTS = ['#1f2937', '#374151', '#1e3a8a', '#78350f', '#111827'];
const HAIRS = ['#1b1b1b', '#3b2412', '#6b4423', '#c9a36b', '#7a7a7a'];

export const randomPersonColors = (rnd = Math.random): PersonColors => ({
  skin: SKINS[Math.floor(rnd() * SKINS.length)],
  shirt: SHIRTS[Math.floor(rnd() * SHIRTS.length)],
  pants: PANTS[Math.floor(rnd() * PANTS.length)],
  hair: HAIRS[Math.floor(rnd() * HAIRS.length)],
});

const box = (w: number, h: number, d: number, color: string) => {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), new THREE.MeshStandardMaterial({ color, roughness: 0.8 }));
  m.castShadow = true;
  return m;
};

/** Personaje low-poly articulado (miembros con pivote en hombros/cadera). Mira hacia +Z. */
export class Person {
  readonly root = new THREE.Group();
  private legL = new THREE.Group();
  private legR = new THREE.Group();
  private armL = new THREE.Group();
  private armR = new THREE.Group();
  private phase = Math.random() * Math.PI * 2;

  constructor(colors: PersonColors, extras?: { badge?: boolean }) {
    const torso = box(0.5, 0.65, 0.28, colors.shirt);
    torso.position.y = 1.2;
    const head = box(0.3, 0.32, 0.3, colors.skin);
    head.position.y = 1.72;
    const hair = box(0.32, 0.1, 0.32, colors.hair);
    hair.position.y = 1.9;
    const eyes = box(0.2, 0.05, 0.02, '#111');
    eyes.position.set(0, 1.75, 0.16);
    eyes.castShadow = false;
    this.root.add(torso, head, hair, eyes);

    if (extras?.badge) {
      const badge = box(0.1, 0.13, 0.02, '#00e5ff');
      badge.position.set(0.14, 1.32, 0.15);
      badge.castShadow = false;
      this.root.add(badge);
    }

    const limb = (g: THREE.Group, x: number, y: number, len: number, w: number, color: string, foot?: string) => {
      g.position.set(x, y, 0);
      const m = box(w, len, w, color);
      m.position.y = -len / 2;
      g.add(m);
      if (foot) {
        const f = box(w + 0.02, 0.08, w + 0.12, foot);
        f.position.set(0, -len + 0.04, 0.05);
        g.add(f);
      }
      this.root.add(g);
    };
    limb(this.legL, -0.13, 0.88, 0.88, 0.2, colors.pants, '#222');
    limb(this.legR, 0.13, 0.88, 0.88, 0.2, colors.pants, '#222');
    limb(this.armL, -0.33, 1.5, 0.62, 0.15, colors.shirt);
    limb(this.armR, 0.33, 1.5, 0.62, 0.15, colors.shirt);
    const handL = box(0.13, 0.12, 0.13, colors.skin);
    handL.position.y = -0.68;
    this.armL.add(handL);
    const handR = handL.clone();
    this.armR.add(handR);
  }

  /** speed: velocidad horizontal en m/s; 0 = reposo. */
  animate(dt: number, speed: number): void {
    if (speed > 0.1) {
      this.phase += dt * (4 + speed * 1.3);
      const amp = Math.min(0.9, 0.35 + speed * 0.08);
      const s = Math.sin(this.phase) * amp;
      this.legL.rotation.x = s;
      this.legR.rotation.x = -s;
      this.armL.rotation.x = -s * 0.8;
      this.armR.rotation.x = s * 0.8;
    } else {
      const k = Math.min(1, dt * 10);
      for (const g of [this.legL, this.legR, this.armL, this.armR]) g.rotation.x += (0 - g.rotation.x) * k;
    }
  }

  /** Pose de trabajo frente al escritorio. */
  setTyping(t: number): void {
    this.armL.rotation.x = -1.2 + Math.sin(t * 14) * 0.08;
    this.armR.rotation.x = -1.2 + Math.cos(t * 13) * 0.08;
  }
}
