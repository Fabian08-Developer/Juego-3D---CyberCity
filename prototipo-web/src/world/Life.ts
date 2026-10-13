import * as THREE from 'three';
import { CITY } from '../config';
import { seededRandom } from '../core/random';
import { Person, randomPersonColors } from './Characters';
import { Box2D, World } from './World';

const CAR_COLORS = ['#c0392b', '#2980b9', '#f1c40f', '#ecf0f1', '#2c3e50', '#16a085', '#8e44ad', '#7f8c8d', '#d35400'];

function carMesh(color: string): THREE.Group {
  const g = new THREE.Group();
  const paint = new THREE.MeshStandardMaterial({ color, roughness: 0.35, metalness: 0.5 });
  const glass = new THREE.MeshStandardMaterial({ color: '#1b2a38', roughness: 0.1, metalness: 0.8 });
  const body = new THREE.Mesh(new THREE.BoxGeometry(1.9, 0.7, 4.2), paint);
  body.position.y = 0.6;
  const cabin = new THREE.Mesh(new THREE.BoxGeometry(1.7, 0.6, 2.2), glass);
  cabin.position.set(0, 1.25, -0.2);
  g.add(body, cabin);
  const wheelGeo = new THREE.CylinderGeometry(0.35, 0.35, 0.25, 12);
  const wheelMat = new THREE.MeshStandardMaterial({ color: '#111', roughness: 0.9 });
  for (const [x, z] of [[-0.95, 1.3], [0.95, 1.3], [-0.95, -1.3], [0.95, -1.3]]) {
    const w = new THREE.Mesh(wheelGeo, wheelMat);
    w.rotation.z = Math.PI / 2;
    w.position.set(x, 0.35, z);
    g.add(w);
  }
  const head = new THREE.MeshStandardMaterial({ color: '#fff', emissive: '#fff8d0', emissiveIntensity: 1.5 });
  const tail = new THREE.MeshStandardMaterial({ color: '#600', emissive: '#ff2020', emissiveIntensity: 1 });
  for (const x of [-0.65, 0.65]) {
    const h = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.15, 0.05), head);
    h.position.set(x, 0.7, 2.11);
    const t = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.15, 0.05), tail);
    t.position.set(x, 0.7, -2.11);
    g.add(h, t);
  }
  g.traverse((o) => (o.castShadow = true));
  return g;
}

interface Car {
  mesh: THREE.Group;
  axis: 'x' | 'z';
  dir: 1 | -1;
  lane: number;
  s: number;
  speed: number;
  maxSpeed: number;
}

/** Tráfico simple: carriles rectos que dan la vuelta al salir del mapa; frenan ante el jugador. */
export function addTraffic(world: World, playerPos: () => THREE.Vector3): void {
  const rnd = seededRandom(5);
  const cars: Car[] = [];
  const span = CITY.half + 25;
  for (let k = 0; k <= CITY.n; k++) {
    const c = CITY.roadCenter(k);
    // Tráfico por la derecha.
    const lanes: [Car['axis'], Car['dir'], number][] = [
      ['x', 1, c + 3],
      ['x', -1, c - 3],
      ['z', 1, c - 3],
      ['z', -1, c + 3],
    ];
    for (const [axis, dir, lane] of lanes) {
      const mesh = carMesh(CAR_COLORS[Math.floor(rnd() * CAR_COLORS.length)]);
      world.scene.add(mesh);
      const maxSpeed = 7 + rnd() * 5;
      cars.push({ mesh, axis, dir, lane, s: (rnd() * 2 - 1) * span, speed: maxSpeed, maxSpeed });
    }
  }

  world.updaters.push((dt) => {
    const p = playerPos();
    const boxes: Box2D[] = [];
    for (const car of cars) {
      const pos = car.axis === 'x' ? { x: car.s, z: car.lane } : { x: car.lane, z: car.s };
      // ¿El jugador está delante del vehículo?
      const along = ((car.axis === 'x' ? p.x - pos.x : p.z - pos.z) * car.dir);
      const lateral = Math.abs(car.axis === 'x' ? p.z - pos.z : p.x - pos.x);
      const blocked = along > 0 && along < 8 && lateral < 1.8 && p.y < 1;
      const target = blocked ? 0 : car.maxSpeed;
      car.speed += (target - car.speed) * Math.min(1, dt * (blocked ? 6 : 1.2));
      car.s += car.dir * car.speed * dt;
      if (car.s > span) car.s = -span;
      if (car.s < -span) car.s = span;

      const x = car.axis === 'x' ? car.s : car.lane;
      const z = car.axis === 'x' ? car.lane : car.s;
      car.mesh.position.set(x, 0, z);
      car.mesh.rotation.y = car.axis === 'x' ? (car.dir > 0 ? Math.PI / 2 : -Math.PI / 2) : car.dir > 0 ? 0 : Math.PI;
      const hw = car.axis === 'x' ? 2.1 : 0.95;
      const hd = car.axis === 'x' ? 0.95 : 2.1;
      boxes.push({ minX: x - hw, maxX: x + hw, minZ: z - hd, maxZ: z + hd });
    }
    world.dynamicColliders = boxes;
  });
}

/** Peatones que caminan por las aceras alrededor de las manzanas. */
export function addPedestrians(world: World, count = 14): void {
  const rnd = seededRandom(11);
  const walkers: { person: Person; path: THREE.Vector3[]; t: number; speed: number }[] = [];
  for (let n = 0; n < count; n++) {
    const i = Math.floor(rnd() * CITY.n);
    const j = Math.floor(rnd() * CITY.n);
    const cx = CITY.blockCenter(i);
    const cz = CITY.blockCenter(j);
    const e = CITY.block / 2 - 2.1;
    const corners = [
      new THREE.Vector3(cx - e, CITY.sidewalkHeight, cz - e),
      new THREE.Vector3(cx + e, CITY.sidewalkHeight, cz - e),
      new THREE.Vector3(cx + e, CITY.sidewalkHeight, cz + e),
      new THREE.Vector3(cx - e, CITY.sidewalkHeight, cz + e),
    ];
    if (rnd() < 0.5) corners.reverse();
    const person = new Person(randomPersonColors(rnd));
    world.scene.add(person.root);
    walkers.push({ person, path: corners, t: rnd() * 4, speed: 1.1 + rnd() * 0.6 });
  }
  const edge = CITY.block - 4.2;
  const tmp = new THREE.Vector3();
  world.updaters.push((dt) => {
    for (const w of walkers) {
      w.t = (w.t + (w.speed * dt) / edge) % 4;
      const seg = Math.floor(w.t);
      const a = w.path[seg];
      const b = w.path[(seg + 1) % 4];
      tmp.copy(a).lerp(b, w.t - seg);
      w.person.root.position.copy(tmp);
      w.person.root.rotation.y = Math.atan2(b.x - a.x, b.z - a.z);
      w.person.animate(dt, w.speed);
    }
  });
}
