import * as THREE from 'three';

type Draw = (ctx: CanvasRenderingContext2D, w: number, h: number) => void;

export function canvasTexture(w: number, h: number, draw: Draw): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  draw(canvas.getContext('2d')!, w, h);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;
  return tex;
}

/** Textura de ruido suave, útil para asfalto, césped y aceras. */
export function noiseTexture(base: string, amount: number, repeat: number, size = 128): THREE.CanvasTexture {
  const tex = canvasTexture(size, size, (ctx, w, h) => {
    ctx.fillStyle = base;
    ctx.fillRect(0, 0, w, h);
    for (let i = 0; i < w * h * 0.35; i++) {
      const v = Math.random();
      ctx.fillStyle = v > 0.5 ? `rgba(255,255,255,${amount * Math.random()})` : `rgba(0,0,0,${amount * Math.random()})`;
      ctx.fillRect(Math.random() * w, Math.random() * h, 1.5, 1.5);
    }
  });
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(repeat, repeat);
  return tex;
}

/** Calle con línea central discontinua; la línea va a lo largo del eje V. */
export function roadTexture(): THREE.CanvasTexture {
  const tex = canvasTexture(128, 256, (ctx, w, h) => {
    ctx.fillStyle = '#2b2d31';
    ctx.fillRect(0, 0, w, h);
    for (let i = 0; i < 3000; i++) {
      ctx.fillStyle = `rgba(255,255,255,${0.05 * Math.random()})`;
      ctx.fillRect(Math.random() * w, Math.random() * h, 1.5, 1.5);
    }
    ctx.fillStyle = '#e8c547';
    ctx.fillRect(w / 2 - 2, 0, 4, h * 0.55);
    ctx.fillStyle = 'rgba(240,240,240,0.85)';
    ctx.fillRect(4, 0, 3, h);
    ctx.fillRect(w - 7, 0, 3, h);
  });
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  return tex;
}

export interface FacadeOptions {
  width: number;
  height: number;
  wall: string;
  glass?: string;
  lit?: string;
  litChance?: number;
  skipGroundFloor?: boolean;
  curtainWall?: boolean;
}

/** Genera una fachada con ventanas proporcional al tamaño real de la cara del edificio. */
export function facadeTexture(o: FacadeOptions): THREE.CanvasTexture {
  const cols = Math.max(1, Math.round(o.width / 3.2));
  const rows = Math.max(1, Math.round(o.height / 3.4));
  const cw = 32;
  const ch = 36;
  return canvasTexture(cols * cw, rows * ch, (ctx, w, h) => {
    ctx.fillStyle = o.wall;
    ctx.fillRect(0, 0, w, h);
    for (let r = 0; r < rows; r++) {
      if (o.skipGroundFloor && r === rows - 1) continue;
      for (let c = 0; c < cols; c++) {
        const lit = Math.random() < (o.litChance ?? 0.15);
        const x = c * cw;
        const y = r * ch;
        if (o.curtainWall) {
          ctx.fillStyle = lit ? o.lit ?? '#9fd8ff' : o.glass ?? '#1f4f73';
          ctx.fillRect(x + 1, y + 1, cw - 2, ch - 2);
          ctx.fillStyle = 'rgba(255,255,255,0.08)';
          ctx.fillRect(x + 1, y + 1, cw - 2, 6);
        } else {
          ctx.fillStyle = 'rgba(0,0,0,0.25)';
          ctx.fillRect(x + 5, y + 7, cw - 10, ch - 12);
          ctx.fillStyle = lit ? o.lit ?? '#ffe6a3' : o.glass ?? '#2c3e50';
          ctx.fillRect(x + 6, y + 8, cw - 12, ch - 15);
          ctx.fillStyle = 'rgba(255,255,255,0.15)';
          ctx.fillRect(x + 6, y + 8, cw - 12, 3);
        }
      }
    }
  });
}

/** Letrero luminoso de negocio. */
export function signTexture(text: string, bg: string, fg: string): THREE.CanvasTexture {
  return canvasTexture(512, 128, (ctx, w, h) => {
    ctx.fillStyle = bg;
    ctx.beginPath();
    ctx.roundRect(4, 4, w - 8, h - 8, 18);
    ctx.fill();
    ctx.strokeStyle = 'rgba(255,255,255,0.35)';
    ctx.lineWidth = 4;
    ctx.stroke();
    ctx.fillStyle = fg;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    let size = 64;
    do {
      ctx.font = `bold ${size}px "Segoe UI", Roboto, Arial, sans-serif`;
      size -= 2;
    } while (ctx.measureText(text).width > w - 40 && size > 20);
    ctx.fillText(text, w / 2, h / 2 + 2);
  });
}
