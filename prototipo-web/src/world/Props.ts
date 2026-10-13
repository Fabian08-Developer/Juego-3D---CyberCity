import * as THREE from 'three';
import { World } from './World';

const mat = (color: string, extra: THREE.MeshStandardMaterialParameters = {}) =>
  new THREE.MeshStandardMaterial({ color, roughness: 0.85, ...extra });

const M = {
  trunk: mat('#6b4a2b'),
  leaves: [mat('#2f7d32', { flatShading: true }), mat('#3c9a3f', { flatShading: true }), mat('#4f8f2a', { flatShading: true })],
  metal: mat('#3d434b', { metalness: 0.6, roughness: 0.4 }),
  lamp: new THREE.MeshStandardMaterial({ color: '#fff6d5', emissive: '#ffe9a8', emissiveIntensity: 1.2 }),
  wood: mat('#9c6b3d'),
  stone: mat('#b9b5ab'),
  water: new THREE.MeshStandardMaterial({ color: '#3fa7d6', roughness: 0.1, metalness: 0.2, transparent: true, opacity: 0.85 }),
};

const G = {
  trunk: new THREE.CylinderGeometry(0.15, 0.22, 2.2, 6),
  foliage: new THREE.IcosahedronGeometry(1.4, 0),
  pole: new THREE.CylinderGeometry(0.08, 0.1, 5.5, 6),
  arm: new THREE.BoxGeometry(0.08, 0.08, 1.4),
  lampHead: new THREE.BoxGeometry(0.5, 0.15, 0.3),
  seat: new THREE.BoxGeometry(1.8, 0.08, 0.5),
  back: new THREE.BoxGeometry(1.8, 0.45, 0.06),
  benchLeg: new THREE.BoxGeometry(0.06, 0.45, 0.45),
};

export function addTree(world: World, x: number, z: number, y = 0, scale = 1): void {
  const g = new THREE.Group();
  const trunk = new THREE.Mesh(G.trunk, M.trunk);
  trunk.position.y = 1.1;
  trunk.castShadow = true;
  g.add(trunk);
  const variant = Math.floor(Math.random() * M.leaves.length);
  for (let i = 0; i < 2; i++) {
    const f = new THREE.Mesh(G.foliage, M.leaves[variant]);
    f.position.set((Math.random() - 0.5) * 0.6, 2.6 + i * 0.9, (Math.random() - 0.5) * 0.6);
    f.scale.setScalar(1 - i * 0.3);
    f.rotation.set(Math.random(), Math.random(), Math.random());
    f.castShadow = true;
    g.add(f);
  }
  g.position.set(x, y, z);
  g.scale.setScalar(scale);
  world.instancer.add(g);
  world.addCollider(x - 0.3, z - 0.3, x + 0.3, z + 0.3);
}

/** Farola; `facing` es el ángulo hacia donde apunta el brazo (hacia la calle). */
export function addStreetLight(world: World, x: number, z: number, y: number, facing: number): void {
  const g = new THREE.Group();
  const pole = new THREE.Mesh(G.pole, M.metal);
  pole.position.y = 2.75;
  pole.castShadow = true;
  const arm = new THREE.Mesh(G.arm, M.metal);
  arm.position.set(0, 5.4, 0.6);
  const head = new THREE.Mesh(G.lampHead, M.lamp);
  head.position.set(0, 5.3, 1.2);
  g.add(pole, arm, head);
  g.position.set(x, y, z);
  g.rotation.y = facing;
  g.traverse((o) => (o.castShadow = true));
  world.instancer.add(g);
  world.addCollider(x - 0.15, z - 0.15, x + 0.15, z + 0.15);
}

export function addBench(world: World, x: number, z: number, y: number, rotY: number): void {
  const g = new THREE.Group();
  const seat = new THREE.Mesh(G.seat, M.wood);
  seat.position.y = 0.45;
  const back = new THREE.Mesh(G.back, M.wood);
  back.position.set(0, 0.75, -0.22);
  for (const sx of [-0.75, 0.75]) {
    const leg = new THREE.Mesh(G.benchLeg, M.metal);
    leg.position.set(sx, 0.22, 0);
    g.add(leg);
  }
  g.add(seat, back);
  g.traverse((o) => (o.castShadow = true));
  g.position.set(x, y, z);
  g.rotation.y = rotY;
  world.addColliderFromObject(g);
  world.instancer.add(g);
}

export function addFountain(world: World, x: number, z: number, y: number): void {
  const g = new THREE.Group();
  const basin = new THREE.Mesh(new THREE.CylinderGeometry(3.2, 3.4, 0.6, 24), M.stone);
  basin.position.y = 0.3;
  const water = new THREE.Mesh(new THREE.CylinderGeometry(2.9, 2.9, 0.1, 24), M.water);
  water.position.y = 0.5;
  const column = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.45, 2, 12), M.stone);
  column.position.y = 1.2;
  const top = new THREE.Mesh(new THREE.CylinderGeometry(1.1, 0.6, 0.3, 16), M.stone);
  top.position.y = 2.2;
  g.add(basin, water, column, top);
  g.traverse((o) => {
    o.castShadow = true;
    o.receiveShadow = true;
  });
  g.position.set(x, y, z);
  world.scene.add(g);
  world.addCollider(x - 3, z - 3, x + 3, z + 3);
  world.updaters.push((_dt, t) => {
    water.position.y = 0.5 + Math.sin(t * 2) * 0.02;
  });
}
