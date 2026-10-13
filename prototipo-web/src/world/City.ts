import * as THREE from 'three';
import { CITY } from '../config';
import { BUSINESSES, BusinessDef } from '../data/businesses';
import { seededRandom } from '../core/random';
import { addBusiness, addFillerBuilding, Lot } from './Buildings';
import { buildHQ, HQHooks } from './HQ';
import { addBench, addFountain, addStreetLight, addTree } from './Props';
import { noiseTexture, roadTexture } from './textures';
import { World } from './World';

export interface CityHooks extends HQHooks {
  onBusiness: (def: BusinessDef) => void;
}

const Y = CITY.sidewalkHeight;

function buildGroundAndRoads(world: World) {
  const grass = noiseTexture('#4c7a3a', 0.12, 60);
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(500, 500), new THREE.MeshStandardMaterial({ map: grass, roughness: 1 }));
  ground.rotation.x = -Math.PI / 2;
  ground.position.y = -0.02;
  ground.receiveShadow = true;
  world.scene.add(ground);

  const len = CITY.size + 60;
  const base = roadTexture();
  for (let k = 0; k <= CITY.n; k++) {
    const c = CITY.roadCenter(k);
    for (const horizontal of [true, false]) {
      const tex = base.clone();
      tex.needsUpdate = true;
      tex.repeat.set(1, len / 14);
      const road = new THREE.Mesh(new THREE.PlaneGeometry(CITY.road, len), new THREE.MeshStandardMaterial({ map: tex, roughness: 0.95 }));
      road.rotation.x = -Math.PI / 2;
      if (horizontal) {
        road.rotation.z = Math.PI / 2;
        road.position.set(0, 0.01, c);
      } else {
        road.position.set(c, 0.005, 0);
      }
      road.receiveShadow = true;
      world.scene.add(road);
    }
  }
  // Intersecciones lisas (sin líneas) con pasos de cebra
  const asphalt = new THREE.MeshStandardMaterial({ color: '#2b2d31', roughness: 0.95 });
  const zebra = new THREE.MeshStandardMaterial({ color: '#e9e9e9', roughness: 0.8 });
  const stripeGeo = new THREE.PlaneGeometry(0.8, 2.2);
  for (let a = 0; a <= CITY.n; a++) {
    for (let b = 0; b <= CITY.n; b++) {
      const x = CITY.roadCenter(a);
      const z = CITY.roadCenter(b);
      const sq = new THREE.Mesh(new THREE.PlaneGeometry(CITY.road, CITY.road), asphalt);
      sq.rotation.x = -Math.PI / 2;
      sq.position.set(x, 0.015, z);
      sq.receiveShadow = true;
      world.scene.add(sq);
      for (let s = -2; s <= 2; s++) {
        for (const [dx, dz, rot] of [[0, 1, 0], [0, -1, 0], [1, 0, 1], [-1, 0, 1]] as const) {
          const stripe = new THREE.Mesh(stripeGeo, zebra);
          stripe.rotation.x = -Math.PI / 2;
          stripe.rotation.z = rot ? Math.PI / 2 : 0;
          const off = CITY.road / 2 + 1.3;
          stripe.position.set(x + dx * off + (rot ? 0 : s * 1.6), 0.016, z + dz * off + (rot ? s * 1.6 : 0));
          world.instancer.add(stripe);
        }
      }
    }
  }
}

function buildBlockSlab(world: World, cx: number, cz: number, mat: THREE.Material) {
  const slab = new THREE.Mesh(new THREE.BoxGeometry(CITY.block, Y, CITY.block), mat);
  slab.position.set(cx, Y / 2, cz);
  slab.receiveShadow = true;
  world.scene.add(slab);
  const h = CITY.block / 2;
  world.raisedAreas.push({ minX: cx - h, maxX: cx + h, minZ: cz - h, maxZ: cz + h });
}

function buildPark(world: World, cx: number, cz: number) {
  const grass = new THREE.Mesh(
    new THREE.PlaneGeometry(CITY.block - 6, CITY.block - 6),
    new THREE.MeshStandardMaterial({ map: noiseTexture('#5a9a3f', 0.12, 6), roughness: 1 }),
  );
  grass.rotation.x = -Math.PI / 2;
  grass.position.set(cx, Y + 0.005, cz);
  grass.receiveShadow = true;
  world.scene.add(grass);
  const pathMat = new THREE.MeshStandardMaterial({ color: '#c9c2b2', roughness: 0.95 });
  for (const rot of [0, Math.PI / 2]) {
    const path = new THREE.Mesh(new THREE.PlaneGeometry(3, CITY.block - 6), pathMat);
    path.rotation.x = -Math.PI / 2;
    path.rotation.z = rot;
    path.position.set(cx, Y + 0.01, cz);
    path.receiveShadow = true;
    world.scene.add(path);
  }
  const plaza = new THREE.Mesh(new THREE.CircleGeometry(6, 32), pathMat);
  plaza.rotation.x = -Math.PI / 2;
  plaza.position.set(cx, Y + 0.012, cz);
  world.scene.add(plaza);
  addFountain(world, cx, cz, Y);
  for (const [x, z, r] of [[-4.5, 6.5, Math.PI], [4.5, 6.5, Math.PI], [-4.5, -6.5, 0], [4.5, -6.5, 0]] as const) {
    addBench(world, cx + x, cz + z, Y, r);
  }
  const rnd = seededRandom(7);
  for (const [qx, qz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
    for (let i = 0; i < 4; i++) {
      const x = cx + qx * (5 + rnd() * 9);
      const z = cz + qz * (5 + rnd() * 9);
      if (Math.hypot(x - cx, z - cz) < 7.5) continue;
      addTree(world, x, z, Y, 0.9 + rnd() * 0.4);
    }
  }
  world.mapShapes.push({ box: { minX: cx - 15, minZ: cz - 15, maxX: cx + 15, maxZ: cz + 15 }, color: '#3f7f34', label: 'Parque' });
}

/** Cuatro parcelas por manzana: dos al norte y dos al sur. */
function blockLots(cx: number, cz: number): Lot[] {
  const lots: Lot[] = [];
  for (const facing of ['N', 'S'] as const) {
    const z = cz + (facing === 'N' ? -8.5 : 8.5);
    for (const dx of [-8, 8]) lots.push({ x: cx + dx, z, w: 14, d: 13, facing });
  }
  return lots;
}

function addBlockStreetLights(world: World, cx: number, cz: number) {
  const e = CITY.block / 2 - 0.6;
  for (const o of [-12, 0, 12]) {
    addStreetLight(world, cx + o, cz - e, Y, Math.PI);
    addStreetLight(world, cx + o, cz + e, Y, 0);
    addStreetLight(world, cx - e, cz + o, Y, -Math.PI / 2);
    addStreetLight(world, cx + e, cz + o, Y, Math.PI / 2);
  }
}

export function buildCity(world: World, hooks: CityHooks): void {
  buildGroundAndRoads(world);
  const sidewalk = new THREE.MeshStandardMaterial({ map: noiseTexture('#a9a9a4', 0.1, 10), roughness: 0.95 });
  const rnd = seededRandom(42);
  const businessQueue = [...BUSINESSES];

  for (let i = 0; i < CITY.n; i++) {
    for (let j = 0; j < CITY.n; j++) {
      const cx = CITY.blockCenter(i);
      const cz = CITY.blockCenter(j);
      buildBlockSlab(world, cx, cz, sidewalk);
      addBlockStreetLights(world, cx, cz);

      if (i === 1 && j === 1) {
        buildPark(world, cx, cz);
        continue;
      }
      if (i === 1 && j === 0) {
        buildHQ(world, hooks);
        continue;
      }
      // Calle comercial alrededor del parque + un local frente a CyberShield
      let quota = j === 1 ? 4 : i === 0 && j === 0 ? 1 : 0;
      const lots = blockLots(cx, cz);
      if (cz < 0) lots.reverse(); // primero las parcelas que miran hacia el centro
      for (const lot of lots) {
        const def = quota-- > 0 ? businessQueue.shift() : undefined;
        if (def) addBusiness(world, lot, def, hooks.onBusiness);
        else addFillerBuilding(world, lot, rnd);
      }
      // Árboles en las aceras laterales
      for (const dz of [-6, 6]) {
        addTree(world, cx - CITY.block / 2 + 0.7, cz + dz, Y, 0.8);
        addTree(world, cx + CITY.block / 2 - 0.7, cz + dz, Y, 0.8);
      }
    }
  }

  // Anillo de árboles fuera de la ciudad
  const outer = seededRandom(99);
  for (let a = 0; a < 140; a++) {
    const ang = outer() * Math.PI * 2;
    const r = CITY.half + 10 + outer() * 30;
    const x = Math.cos(ang) * r;
    const z = Math.sin(ang) * r;
    if (Math.abs(x) < CITY.half + 8 && Math.abs(z) < CITY.half + 8) continue;
    // No bloquear la salida de las calles
    if (Array.from({ length: CITY.n + 1 }, (_, k) => CITY.roadCenter(k)).some((c) => Math.abs(x - c) < 8 || Math.abs(z - c) < 8)) continue;
    addTree(world, x, z, 0, 1 + outer() * 0.8);
  }
  world.instancer.flush(world.scene);
}
