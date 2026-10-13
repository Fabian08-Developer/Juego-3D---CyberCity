import * as THREE from 'three';
import { CITY } from '../config';
import { Instancer } from './Instancer';

/** Caja de colisión alineada a ejes en el plano XZ. */
export interface Box2D {
  minX: number;
  maxX: number;
  minZ: number;
  maxZ: number;
}

export interface Interactable {
  position: THREE.Vector3;
  radius: number;
  label: () => string;
  action: () => void;
}

/** Forma para el minimapa. */
export interface MapShape {
  box: Box2D;
  color: string;
  label?: string;
}

export type Updater = (dt: number, time: number) => void;

/**
 * Contenedor de todo lo que vive en el mundo: escena, colisiones, objetos que
 * bloquean la cámara, puntos de interacción y actualizadores por frame.
 */
export class World {
  readonly scene = new THREE.Scene();
  /** Props estáticos repetidos; se vuelcan a la escena con `instancer.flush`. */
  readonly instancer = new Instancer();
  readonly colliders: Box2D[] = [];
  /** Colisionadores que se reconstruyen cada frame (vehículos, etc.). */
  dynamicColliders: Box2D[] = [];
  readonly occluders: THREE.Object3D[] = [];
  readonly interactables: Interactable[] = [];
  readonly updaters: Updater[] = [];
  readonly mapShapes: MapShape[] = [];
  readonly raisedAreas: Box2D[] = [];
  markers: Record<string, THREE.Vector3> = {};

  addCollider(minX: number, minZ: number, maxX: number, maxZ: number): Box2D {
    const box = { minX, minZ, maxX, maxZ };
    this.colliders.push(box);
    return box;
  }

  /** Colisionador a partir de la caja envolvente mundial del objeto. */
  addColliderFromObject(obj: THREE.Object3D, padding = 0): Box2D {
    obj.updateWorldMatrix(true, true);
    const b = new THREE.Box3().setFromObject(obj);
    return this.addCollider(b.min.x - padding, b.min.z - padding, b.max.x + padding, b.max.z + padding);
  }

  groundHeight(x: number, z: number): number {
    for (const a of this.raisedAreas) {
      if (x >= a.minX && x <= a.maxX && z >= a.minZ && z <= a.maxZ) return CITY.sidewalkHeight;
    }
    return 0;
  }

  /** Empuja un círculo (jugador) fuera de todas las cajas con las que se solapa. */
  resolveCircle(pos: THREE.Vector3, radius: number): void {
    const resolve = (b: Box2D) => {
      const cx = Math.max(b.minX, Math.min(pos.x, b.maxX));
      const cz = Math.max(b.minZ, Math.min(pos.z, b.maxZ));
      const dx = pos.x - cx;
      const dz = pos.z - cz;
      const d2 = dx * dx + dz * dz;
      if (d2 >= radius * radius) return;
      if (d2 > 1e-8) {
        const d = Math.sqrt(d2);
        pos.x += (dx / d) * (radius - d);
        pos.z += (dz / d) * (radius - d);
      } else {
        // El centro está dentro: salir por el lado de menor penetración.
        const pen = [pos.x - b.minX + radius, b.maxX - pos.x + radius, pos.z - b.minZ + radius, b.maxZ - pos.z + radius];
        const m = Math.min(...pen);
        if (m === pen[0]) pos.x -= pen[0];
        else if (m === pen[1]) pos.x += pen[1];
        else if (m === pen[2]) pos.z -= pen[2];
        else pos.z += pen[3];
      }
    };
    for (const b of this.colliders) resolve(b);
    for (const b of this.dynamicColliders) resolve(b);
    const limit = CITY.half + 6;
    pos.x = Math.max(-limit, Math.min(limit, pos.x));
    pos.z = Math.max(-limit, Math.min(limit, pos.z));
  }

  nearestInteractable(pos: THREE.Vector3): Interactable | null {
    let best: Interactable | null = null;
    let bestD = Infinity;
    for (const it of this.interactables) {
      const d = Math.hypot(it.position.x - pos.x, it.position.z - pos.z);
      if (d < it.radius && d < bestD) {
        best = it;
        bestD = d;
      }
    }
    return best;
  }

  update(dt: number, time: number): void {
    for (const u of this.updaters) u(dt, time);
  }
}
