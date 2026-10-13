import * as THREE from 'three';
import { CITY } from '../config';
import { BusinessDef } from '../data/businesses';
import { facadeTexture, signTexture } from './textures';
import { World } from './World';

/** Parcela dentro de una manzana. El frente del edificio mira hacia `facing`. */
export interface Lot {
  x: number;
  z: number;
  w: number;
  d: number;
  facing: 'N' | 'S';
}

const roofMat = new THREE.MeshStandardMaterial({ color: '#4a4f57', roughness: 0.9 });

/** Caja con fachadas proporcionales en cada cara (+X,-X,+Y,-Y,+Z,-Z). */
function facadeBox(w: number, h: number, d: number, wall: string, opts: { curtain?: boolean; skipGround?: boolean; litChance?: number } = {}) {
  const front = facadeTexture({ width: w, height: h, wall, curtainWall: opts.curtain, skipGroundFloor: opts.skipGround, litChance: opts.litChance });
  const back = facadeTexture({ width: w, height: h, wall, curtainWall: opts.curtain, litChance: opts.litChance });
  const side = facadeTexture({ width: d, height: h, wall, curtainWall: opts.curtain, litChance: opts.litChance });
  const m = (map: THREE.Texture) => new THREE.MeshStandardMaterial({ map, roughness: opts.curtain ? 0.3 : 0.85, metalness: opts.curtain ? 0.3 : 0 });
  const sideMat = m(side);
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), [sideMat, sideMat, roofMat, roofMat, m(front), m(back)]);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

function place(world: World, group: THREE.Group, lot: Lot, label: string, color: string) {
  group.position.set(lot.x, CITY.sidewalkHeight, lot.z);
  group.rotation.y = lot.facing === 'N' ? Math.PI : 0;
  world.scene.add(group);
  const box = world.addCollider(lot.x - lot.w / 2, lot.z - lot.d / 2, lot.x + lot.w / 2, lot.z + lot.d / 2);
  world.mapShapes.push({ box, color, label });
}

/** Punto frente a la puerta (en coordenadas de mundo). */
const doorPoint = (lot: Lot, out = 1.4) =>
  new THREE.Vector3(lot.x, CITY.sidewalkHeight, lot.z + (lot.facing === 'N' ? -1 : 1) * (lot.d / 2 + out));

const FILLER_COLORS = ['#b8b2a7', '#8e9aa6', '#c7a98c', '#7d8a7a', '#a39188', '#d4cfc4', '#6f7b8a', '#9b8b7a'];

/** Edificio residencial / de oficinas sin interacción. */
export function addFillerBuilding(world: World, lot: Lot, rnd: () => number): void {
  const h = 9 + Math.floor(rnd() * 6) * 4;
  const wall = FILLER_COLORS[Math.floor(rnd() * FILLER_COLORS.length)];
  const curtain = rnd() < 0.25;
  const g = new THREE.Group();
  const body = facadeBox(lot.w, h, lot.d, wall, { curtain, litChance: 0.12 });
  body.position.y = h / 2;
  g.add(body);
  // Entrada genérica
  const door = new THREE.Mesh(new THREE.PlaneGeometry(1.6, 2.4), new THREE.MeshStandardMaterial({ color: '#3a2c22' }));
  door.position.set(0, 1.2, lot.d / 2 + 0.02);
  g.add(door);
  // Detalle de azotea
  const tank = new THREE.Mesh(new THREE.CylinderGeometry(0.8, 0.8, 1.6, 10), roofMat);
  tank.position.set(lot.w * 0.25, h + 0.8, 0);
  tank.castShadow = true;
  g.add(tank);
  place(world, g, lot, '', curtain ? '#4b6a85' : '#5b5f66');
  world.occluders.push(body);
}

/** Negocio con vitrina, toldo y letrero luminoso. */
export function addBusiness(world: World, lot: Lot, def: BusinessDef, onEnter: (def: BusinessDef) => void): void {
  const h = def.height;
  const g = new THREE.Group();
  const body = facadeBox(lot.w, h, lot.d, def.wall, { skipGround: true, litChance: 0.25 });
  body.position.y = h / 2;
  g.add(body);

  const front = lot.d / 2;
  // Vitrina
  const glass = new THREE.Mesh(
    new THREE.PlaneGeometry(lot.w - 1.6, 2.7),
    new THREE.MeshStandardMaterial({ color: '#9fd3e6', emissive: '#ffe7b0', emissiveIntensity: 0.25, roughness: 0.1, metalness: 0.4 }),
  );
  glass.position.set(0, 1.55, front + 0.03);
  g.add(glass);
  // Marco y puerta
  const frameMat = new THREE.MeshStandardMaterial({ color: '#2b2b2b', roughness: 0.5 });
  const frame = new THREE.Mesh(new THREE.BoxGeometry(lot.w - 1.2, 0.2, 0.15), frameMat);
  frame.position.set(0, 2.95, front + 0.05);
  g.add(frame);
  const door = new THREE.Mesh(new THREE.PlaneGeometry(1.8, 2.5), new THREE.MeshStandardMaterial({ color: '#cfe8f2', roughness: 0.05, metalness: 0.5, emissive: '#ffffff', emissiveIntensity: 0.15 }));
  door.position.set(0, 1.25, front + 0.05);
  g.add(door);
  for (const dx of [-0.95, 0.95]) {
    const jamb = new THREE.Mesh(new THREE.BoxGeometry(0.12, 2.6, 0.12), frameMat);
    jamb.position.set(dx, 1.3, front + 0.06);
    g.add(jamb);
  }
  // Toldo
  const awning = new THREE.Mesh(new THREE.BoxGeometry(lot.w - 1, 0.08, 1.8), new THREE.MeshStandardMaterial({ color: def.accent, roughness: 0.7 }));
  awning.position.set(0, 3.2, front + 0.85);
  awning.rotation.x = 0.28;
  awning.castShadow = true;
  g.add(awning);
  // Letrero
  const signMap = signTexture(def.signText, def.accent, '#ffffff');
  const sign = new THREE.Mesh(
    new THREE.PlaneGeometry(Math.min(lot.w - 1.5, 10), Math.min(lot.w - 1.5, 10) / 4),
    new THREE.MeshStandardMaterial({ map: signMap, emissiveMap: signMap, emissive: '#ffffff', emissiveIntensity: 0.6 }),
  );
  sign.position.set(0, 4.4, front + 0.06);
  g.add(sign);

  place(world, g, lot, def.type, def.accent);
  world.occluders.push(body);
  world.interactables.push({
    position: doorPoint(lot),
    radius: 2.2,
    label: () => `Entrar a ${def.name} (${def.type})`,
    action: () => onEnter(def),
  });
}
