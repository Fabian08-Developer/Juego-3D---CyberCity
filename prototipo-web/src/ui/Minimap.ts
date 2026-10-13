import { CITY } from '../config';
import { World } from '../world/World';

const RANGE = CITY.half + 8;

/** Minimapa con norte arriba: capa estática pre-dibujada + jugador y objetivos. */
export class Minimap {
  private ctx: CanvasRenderingContext2D;
  private base: HTMLCanvasElement;
  private size: number;

  constructor(canvas: HTMLCanvasElement, world: World) {
    this.size = canvas.width = canvas.height = 200;
    this.ctx = canvas.getContext('2d')!;
    this.base = document.createElement('canvas');
    this.base.width = this.base.height = this.size;
    const b = this.base.getContext('2d')!;
    b.fillStyle = '#16301f';
    b.fillRect(0, 0, this.size, this.size);
    b.fillStyle = '#3a3d42';
    for (let k = 0; k <= CITY.n; k++) {
      const c = this.toMap(CITY.roadCenter(k), 0)[0];
      const w = this.scale(CITY.road);
      b.fillRect(c - w / 2, 0, w, this.size);
      b.fillRect(0, c - w / 2, this.size, w);
    }
    for (const s of world.mapShapes) {
      const [x0, z0] = this.toMap(s.box.minX, s.box.minZ);
      const [x1, z1] = this.toMap(s.box.maxX, s.box.maxZ);
      b.fillStyle = s.color;
      b.fillRect(x0, z0, x1 - x0, z1 - z0);
    }
    b.font = 'bold 9px sans-serif';
    b.textAlign = 'center';
    b.fillStyle = '#fff';
    for (const s of world.mapShapes) {
      if (!s.label) continue;
      const [x, z] = this.toMap((s.box.minX + s.box.maxX) / 2, (s.box.minZ + s.box.maxZ) / 2);
      b.fillText(s.label, x, z + 3);
    }
  }

  private scale(v: number) {
    return (v / (RANGE * 2)) * this.size;
  }

  private toMap(x: number, z: number): [number, number] {
    return [this.scale(x + RANGE), this.scale(z + RANGE)];
  }

  draw(px: number, pz: number, yaw: number, target: { x: number; z: number } | null, t: number): void {
    const c = this.ctx;
    c.drawImage(this.base, 0, 0);
    if (target) {
      const [tx, tz] = this.toMap(target.x, target.z);
      c.strokeStyle = '#ff5470';
      c.lineWidth = 2;
      c.beginPath();
      c.arc(tx, tz, 5 + (Math.sin(t * 5) + 1) * 3, 0, Math.PI * 2);
      c.stroke();
    }
    const [x, z] = this.toMap(px, pz);
    c.save();
    c.translate(x, z);
    c.rotate(-yaw);
    c.fillStyle = '#00e5ff';
    c.beginPath();
    c.moveTo(0, -7);
    c.lineTo(5, 5);
    c.lineTo(0, 2);
    c.lineTo(-5, 5);
    c.closePath();
    c.fill();
    c.restore();
    c.fillStyle = '#fff';
    c.font = 'bold 10px sans-serif';
    c.fillText('N', this.size / 2 - 3, 11);
  }
}
