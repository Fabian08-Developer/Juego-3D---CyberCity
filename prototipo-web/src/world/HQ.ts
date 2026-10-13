import * as THREE from 'three';
import { CITY } from '../config';
import { Person, randomPersonColors } from './Characters';
import { canvasTexture, facadeTexture, noiseTexture, signTexture } from './textures';
import { World } from './World';

export interface HQHooks {
  onWorkstation: () => void;
  onReception: () => void;
  /** Líneas para la pantalla de alertas del SOC. */
  alertLines: () => { text: string; color: string }[];
}

const Y = CITY.sidewalkHeight;
const FLOOR_H = 5;
const X0 = -14;
const X1 = 14;
const Z0 = -60; // fondo
const Z1 = -38; // fachada (mira al sur, hacia el parque)
const DOOR = 1.6;

/** Pantalla animada dibujada en un canvas. */
function animatedScreen(w: number, h: number, draw: (ctx: CanvasRenderingContext2D, t: number) => void) {
  const tex = canvasTexture(w, h, () => undefined);
  const canvas = tex.image as HTMLCanvasElement;
  const ctx = canvas.getContext('2d')!;
  let acc = 1;
  const update = (dt: number, t: number) => {
    acc += dt;
    if (acc < 0.2) return;
    acc = 0;
    draw(ctx, t);
    tex.needsUpdate = true;
  };
  return { tex, update };
}

function screenHeader(ctx: CanvasRenderingContext2D, title: string) {
  const { width: w, height: h } = ctx.canvas;
  ctx.fillStyle = '#04121c';
  ctx.fillRect(0, 0, w, h);
  ctx.strokeStyle = '#0ff3';
  ctx.lineWidth = 1;
  for (let x = 0; x < w; x += 32) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, h);
    ctx.stroke();
  }
  for (let y = 0; y < h; y += 32) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(w, y);
    ctx.stroke();
  }
  ctx.fillStyle = '#00e5ff';
  ctx.font = 'bold 22px monospace';
  ctx.fillText(title, 14, 30);
}

export function buildHQ(world: World, hooks: HQHooks): void {
  const scene = world.scene;
  const cx = (X0 + X1) / 2;
  const cz = (Z0 + Z1) / 2;
  const W = X1 - X0;
  const D = Z1 - Z0;

  const wallMat = new THREE.MeshStandardMaterial({ color: '#d9dee5', roughness: 0.9 });
  const darkMat = new THREE.MeshStandardMaterial({ color: '#1d2430', roughness: 0.6 });
  const glassMat = new THREE.MeshStandardMaterial({ color: '#7fc8ff', transparent: true, opacity: 0.28, roughness: 0.05, metalness: 0.6 });

  const addWall = (x0: number, z0: number, x1: number, z1: number, mat: THREE.Material, y0 = 0, y1 = FLOOR_H, collide = true) => {
    const m = new THREE.Mesh(new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), mat);
    m.position.set((x0 + x1) / 2, Y + (y0 + y1) / 2, (z0 + z1) / 2);
    m.receiveShadow = true;
    m.castShadow = mat !== glassMat;
    scene.add(m);
    world.occluders.push(m);
    if (collide) world.addCollider(x0, z0, x1, z1);
    return m;
  };

  // --- Planta baja ---
  addWall(X0, Z0, X1, Z0 + 0.4, wallMat); // fondo
  addWall(X0, Z0, X0 + 0.4, Z1, wallMat); // izquierda
  addWall(X1 - 0.4, Z0, X1, Z1, wallMat); // derecha
  addWall(X0, Z1 - 0.3, -DOOR, Z1, glassMat); // vidrio izq.
  addWall(DOOR, Z1 - 0.3, X1, Z1, glassMat); // vidrio der.
  addWall(-DOOR, Z1 - 0.3, DOOR, Z1, darkMat, 3.1, FLOOR_H, false); // dintel
  for (const x of [X0 + 0.2, -DOOR, DOOR, X1 - 0.2, -7.5, 7.5]) {
    addWall(x - 0.15, Z1 - 0.35, x + 0.15, Z1 + 0.05, darkMat, 0, FLOOR_H, false); // columnas de la fachada
  }

  // Piso interior y techo
  const tile = noiseTexture('#cfd5dc', 0.06, 8);
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(W - 0.8, D - 0.6), new THREE.MeshStandardMaterial({ map: tile, roughness: 0.35 }));
  floor.rotation.x = -Math.PI / 2;
  floor.position.set(cx, Y + 0.01, cz);
  floor.receiveShadow = true;
  scene.add(floor);
  const ceiling = new THREE.Mesh(new THREE.PlaneGeometry(W, D), new THREE.MeshStandardMaterial({ color: '#eef1f4' }));
  ceiling.rotation.x = Math.PI / 2;
  ceiling.position.set(cx, Y + FLOOR_H - 0.02, cz);
  scene.add(ceiling);
  world.occluders.push(ceiling);

  // Paneles de luz en el techo + luces puntuales
  const panelMat = new THREE.MeshStandardMaterial({ color: '#ffffff', emissive: '#ffffff', emissiveIntensity: 1 });
  for (const x of [-8, 0, 8]) {
    for (const z of [-55, -48, -42]) {
      const p = new THREE.Mesh(new THREE.BoxGeometry(2.4, 0.05, 0.8), panelMat);
      p.position.set(x, Y + FLOOR_H - 0.05, z);
      scene.add(p);
    }
  }
  for (const [x, z] of [[-7, -52], [7, -52], [0, -43]]) {
    const light = new THREE.PointLight('#fff6ea', 28, 26, 1.6);
    light.position.set(x, Y + FLOOR_H - 0.6, z);
    scene.add(light);
  }

  // --- Torre ---
  const towerH = 40;
  const towerMat = (w: number) =>
    new THREE.MeshStandardMaterial({
      map: facadeTexture({ width: w, height: towerH, wall: '#0e2233', curtainWall: true, glass: '#1c5d8a', lit: '#8fe3ff', litChance: 0.3 }),
      roughness: 0.25,
      metalness: 0.5,
    });
  const sideM = towerMat(D);
  const frontM = towerMat(W);
  const tower = new THREE.Mesh(new THREE.BoxGeometry(W, towerH, D), [sideM, sideM, darkMat, darkMat, frontM, frontM]);
  tower.position.set(cx, Y + FLOOR_H + towerH / 2, cz);
  tower.castShadow = true;
  tower.receiveShadow = true;
  scene.add(tower);
  world.occluders.push(tower);
  const crown = new THREE.Mesh(new THREE.BoxGeometry(W - 6, 3, D - 6), darkMat);
  crown.position.set(cx, Y + FLOOR_H + towerH + 1.5, cz);
  scene.add(crown);

  const logo = signTexture('CYBERSHIELD', '#06131f', '#00e5ff');
  const logoMat = new THREE.MeshStandardMaterial({ map: logo, emissiveMap: logo, emissive: '#ffffff', emissiveIntensity: 1.2 });
  const bigSign = new THREE.Mesh(new THREE.PlaneGeometry(20, 5), logoMat);
  bigSign.position.set(cx, Y + FLOOR_H + towerH - 4, Z1 + 0.05);
  scene.add(bigSign);
  const entranceSign = new THREE.Mesh(new THREE.PlaneGeometry(6, 1.5), logoMat);
  entranceSign.position.set(0, Y + 4.05, Z1 + 0.08);
  scene.add(entranceSign);

  // --- Interior ---
  const deskMat = new THREE.MeshStandardMaterial({ color: '#f4f4f2', roughness: 0.6 });
  const legMat = new THREE.MeshStandardMaterial({ color: '#555b63', metalness: 0.5, roughness: 0.4 });
  const monitorOff = new THREE.MeshStandardMaterial({ color: '#0b1520', emissive: '#103a5c', emissiveIntensity: 0.8 });

  const addDesk = (x: number, z: number, monitorMat: THREE.Material = monitorOff) => {
    const g = new THREE.Group();
    const top = new THREE.Mesh(new THREE.BoxGeometry(2.4, 0.06, 1), deskMat);
    top.position.y = 0.75;
    g.add(top);
    for (const sx of [-1.1, 1.1]) {
      const leg = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.75, 0.9), legMat);
      leg.position.set(sx, 0.375, 0);
      g.add(leg);
    }
    for (const mx of [-0.45, 0.45]) {
      const mon = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.5, 0.05), monitorMat);
      mon.position.set(mx, 1.13, -0.25);
      mon.rotation.y = mx < 0 ? 0.15 : -0.15;
      const stand = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.3, 0.06), legMat);
      stand.position.set(mx, 0.9, -0.28);
      g.add(mon, stand);
    }
    const kb = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.03, 0.2), darkMat);
    kb.position.set(0, 0.79, 0.15);
    g.add(kb);
    g.traverse((o) => (o.castShadow = true));
    g.position.set(x, Y, z);
    scene.add(g);
    world.addCollider(x - 1.2, z - 0.5, x + 1.2, z + 0.5);
    return g;
  };

  const coworkers: Person[] = [];
  const addCoworker = (x: number, z: number) => {
    addDesk(x, z);
    const p = new Person(randomPersonColors(), { badge: true });
    p.root.position.set(x, Y, z + 0.85);
    p.root.rotation.y = Math.PI;
    scene.add(p.root);
    coworkers.push(p);
  };
  addCoworker(-8, -54);
  addCoworker(8, -54);
  addCoworker(-8, -47);
  addCoworker(8, -47);

  // Estación de trabajo del jugador (centro, frente al muro del SOC)
  const myScreen = animatedScreen(256, 160, (ctx, t) => {
    ctx.fillStyle = '#03101a';
    ctx.fillRect(0, 0, 256, 160);
    ctx.fillStyle = '#00e5ff';
    ctx.font = 'bold 16px monospace';
    ctx.fillText('SOC CONSOLE', 12, 24);
    ctx.font = '12px monospace';
    const lines = hooks.alertLines();
    ctx.fillStyle = lines.length ? '#ff5470' : '#3ddc84';
    ctx.fillText(lines.length ? `${lines.length} ALERTA(S) PENDIENTE(S)` : 'SIN ALERTAS', 12, 50);
    if (Math.floor(t * 2) % 2 === 0) ctx.fillText('▌', 12, 140);
  });
  world.updaters.push(myScreen.update);
  addDesk(0, -54.5, new THREE.MeshStandardMaterial({ map: myScreen.tex, emissiveMap: myScreen.tex, emissive: '#ffffff', emissiveIntensity: 0.9 }));
  const chair = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.9, 0.6), darkMat);
  chair.position.set(0, Y + 0.45, -53.3);
  chair.castShadow = true;
  scene.add(chair);
  world.markers.workstation = new THREE.Vector3(0, Y, -52.6);
  world.interactables.push({
    position: world.markers.workstation,
    radius: 1.8,
    label: () => 'Usar estación de trabajo (Consola SOC)',
    action: hooks.onWorkstation,
  });

  // Recepción
  const reception = new THREE.Mesh(new THREE.BoxGeometry(4, 1.1, 1), new THREE.MeshStandardMaterial({ color: '#1d2430', roughness: 0.4 }));
  reception.position.set(-7, Y + 0.55, -42.5);
  reception.castShadow = true;
  scene.add(reception);
  world.addCollider(-9, -43, -5, -42);
  const receptionist = new Person(randomPersonColors(), { badge: true });
  receptionist.root.position.set(-7, Y, -43.8);
  scene.add(receptionist.root);
  world.interactables.push({
    position: new THREE.Vector3(-7, Y, -41.2),
    radius: 1.8,
    label: () => 'Hablar con recepción',
    action: hooks.onReception,
  });

  // Racks de servidores con LEDs
  const rackMat = new THREE.MeshStandardMaterial({ color: '#15191f', roughness: 0.5, metalness: 0.4 });
  const leds: THREE.MeshStandardMaterial[] = [];
  for (let i = 0; i < 4; i++) {
    const z = -58 + i * 1.3;
    const rack = new THREE.Mesh(new THREE.BoxGeometry(1, 2.4, 1.1), rackMat);
    rack.position.set(12.6, Y + 1.2, z);
    rack.castShadow = true;
    scene.add(rack);
    for (let j = 0; j < 5; j++) {
      const ledMat = new THREE.MeshStandardMaterial({ color: '#000', emissive: j % 3 ? '#00ff88' : '#00bfff', emissiveIntensity: 1 });
      leds.push(ledMat);
      const led = new THREE.Mesh(new THREE.BoxGeometry(0.02, 0.05, 0.6), ledMat);
      led.position.set(12.09, Y + 0.5 + j * 0.4, z);
      scene.add(led);
    }
  }
  world.addCollider(12, -58.6, 13.6, -53.5);
  world.updaters.push((_dt, t) => {
    leds.forEach((m, i) => (m.emissiveIntensity = Math.sin(t * (3 + (i % 5)) + i) > 0.2 ? 1.4 : 0.15));
  });

  // Pizarra
  const board = canvasTexture(512, 256, (ctx, w, h) => {
    ctx.fillStyle = '#fbfbf8';
    ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = '#1d4ed8';
    ctx.font = 'bold 26px sans-serif';
    ctx.fillText('Respuesta a incidentes (NIST)', 20, 40);
    ctx.font = '22px sans-serif';
    ctx.fillStyle = '#222';
    ['1. Preparación', '2. Detección y análisis', '3. Contención, erradicación', '    y recuperación', '4. Lecciones aprendidas'].forEach((l, i) =>
      ctx.fillText(l, 30, 90 + i * 34),
    );
  });
  const whiteboard = new THREE.Mesh(new THREE.PlaneGeometry(5, 2.5), new THREE.MeshStandardMaterial({ map: board }));
  whiteboard.position.set(X0 + 0.42, Y + 2.2, -50);
  whiteboard.rotation.y = Math.PI / 2;
  scene.add(whiteboard);

  // Muro de pantallas del SOC
  const mapScreen = animatedScreen(512, 256, (ctx, t) => {
    screenHeader(ctx, 'MAPA DE AMENAZAS');
    const pts: [number, number][] = [[80, 120], [150, 90], [250, 140], [330, 100], [420, 160], [460, 90], [200, 200]];
    ctx.fillStyle = '#00e5ff';
    pts.forEach(([x, y]) => ctx.fillRect(x - 3, y - 3, 6, 6));
    for (let i = 0; i < 4; i++) {
      const a = pts[(Math.floor(t) + i) % pts.length];
      const b = pts[(Math.floor(t * 1.7) + i * 3 + 1) % pts.length];
      const k = (t * 0.8 + i * 0.25) % 1;
      ctx.strokeStyle = i % 2 ? '#ff5470' : '#ffb020';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(a[0], a[1]);
      ctx.quadraticCurveTo((a[0] + b[0]) / 2, Math.min(a[1], b[1]) - 60, a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k - Math.sin(k * Math.PI) * 40);
      ctx.stroke();
    }
  });
  const trafficHistory: number[] = Array(64).fill(0.4);
  const trafficScreen = animatedScreen(512, 256, (ctx) => {
    screenHeader(ctx, 'TRÁFICO DE RED (Gbps)');
    trafficHistory.shift();
    trafficHistory.push(0.3 + Math.random() * 0.35 + (hooks.alertLines().length ? 0.25 : 0));
    ctx.strokeStyle = '#3ddc84';
    ctx.lineWidth = 3;
    ctx.beginPath();
    trafficHistory.forEach((v, i) => {
      const x = 10 + i * 7.8;
      const y = 240 - v * 190;
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();
  });
  const alertScreen = animatedScreen(512, 256, (ctx) => {
    screenHeader(ctx, 'ALERTAS ACTIVAS');
    const lines = hooks.alertLines();
    ctx.font = '18px monospace';
    if (!lines.length) {
      ctx.fillStyle = '#3ddc84';
      ctx.fillText('Todo en orden. Monitoreando…', 20, 80);
    }
    lines.slice(0, 7).forEach((l, i) => {
      ctx.fillStyle = l.color;
      ctx.fillText(l.text.slice(0, 44), 20, 70 + i * 26);
    });
  });
  const screens = [mapScreen, trafficScreen, alertScreen];
  screens.forEach((s, i) => {
    world.updaters.push(s.update);
    const mesh = new THREE.Mesh(
      new THREE.PlaneGeometry(6, 3),
      new THREE.MeshStandardMaterial({ map: s.tex, emissiveMap: s.tex, emissive: '#ffffff', emissiveIntensity: 1 }),
    );
    mesh.position.set(-7 + i * 7, Y + 2.7, Z0 + 0.45);
    scene.add(mesh);
    const bezel = new THREE.Mesh(new THREE.BoxGeometry(6.3, 3.3, 0.08), darkMat);
    bezel.position.set(-7 + i * 7, Y + 2.7, Z0 + 0.41);
    scene.add(bezel);
  });

  // Plantas decorativas en la entrada
  const potMat = new THREE.MeshStandardMaterial({ color: '#3a3a3a' });
  const plantMat = new THREE.MeshStandardMaterial({ color: '#2f8f3a', flatShading: true });
  for (const x of [-3, 3]) {
    const pot = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.3, 0.6, 10), potMat);
    pot.position.set(x, Y + 0.3, Z1 - 1);
    const plant = new THREE.Mesh(new THREE.IcosahedronGeometry(0.55, 0), plantMat);
    plant.position.set(x, Y + 1.05, Z1 - 1);
    scene.add(pot, plant);
    world.addCollider(x - 0.35, Z1 - 1.35, x + 0.35, Z1 - 0.65);
  }

  world.updaters.push((dt, t) => coworkers.forEach((p, i) => {
    p.animate(dt, 0);
    p.setTyping(t + i);
  }));

  world.mapShapes.push({ box: { minX: X0, minZ: Z0, maxX: X1, maxZ: Z1 }, color: '#00b8d9', label: 'CyberShield' });
  world.markers.hq = new THREE.Vector3(0, Y, Z1 + 2);
}
