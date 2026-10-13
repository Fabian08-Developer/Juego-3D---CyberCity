import * as THREE from 'three';
import { CONFIG } from '../config';
import { WorkDay } from '../cyber/WorkDay';
import { BusinessDef } from '../data/businesses';
import { Player } from '../player/Player';
import { HUD } from '../ui/HUD';
import { Minimap } from '../ui/Minimap';
import { Modal } from '../ui/Modal';
import { SocConsole } from '../ui/SocConsole';
import { renderDaySummary, renderShop } from '../ui/Dialogs';
import { $ } from '../ui/dom';
import { buildCity } from '../world/City';
import { addPedestrians, addTraffic } from '../world/Life';
import { World } from '../world/World';
import { GameState } from './GameState';
import { Input } from './Input';
import { pick } from './random';

const SPAWN = { x: 0, z: 10, yaw: 0 };

const RECEPTION_TIPS = [
  'Recepción: "Recuerda no dejar pasar a nadie detrás de ti sin tarjeta (tailgating)."',
  'Recepción: "Hoy llegó un USB sin remitente. Lo enviamos a TI para análisis, no lo conectes."',
  'Recepción: "Bloquea tu pantalla (Win+L) cada vez que te levantes del puesto."',
  'Recepción: "Alguien llamó diciendo ser de soporte y pidió tu contraseña. No se la dimos 😉."',
];

/** Orquesta render, mundo, jugador, jornada laboral e interfaz. */
export class Game {
  private renderer: THREE.WebGLRenderer;
  private camera = new THREE.PerspectiveCamera(70, 1, 0.1, 600);
  private world = new World();
  private input: Input;
  private player: Player;
  private state = new GameState();
  private workday: WorkDay;
  private hud = new HUD();
  private modal = new Modal();
  private minimap: Minimap;
  private sun = new THREE.DirectionalLight('#fff4e0', 2.6);
  private hemi = new THREE.HemisphereLight('#cfe8ff', '#4a5a3a', 1.1);
  private timer = new THREE.Timer();
  private time = 0;
  private started = false;
  private lowEnergyWarned = false;
  private readonly params = new URLSearchParams(location.search);
  private readonly noLock = this.params.has('nolock');

  constructor(private canvas: HTMLCanvasElement) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.input = new Input(canvas);

    this.setupLights();
    buildCity(this.world, {
      onBusiness: (def) => this.openShop(def),
      onWorkstation: () => this.openConsole(),
      onReception: () => this.hud.toast(pick(RECEPTION_TIPS)),
      alertLines: () =>
        this.workday.pending.map((p) => ({
          text: `[${p.challenge.severity.toUpperCase()}] ${p.challenge.title}`,
          color: p.challenge.severity === 'Crítica' ? '#ff5470' : '#ffb020',
        })),
    });
    this.player = new Player(this.world);
    addTraffic(this.world, () => this.player.position);
    addPedestrians(this.world);
    this.minimap = new Minimap($<HTMLCanvasElement>('minimap'), this.world);

    this.workday = new WorkDay(this.state, {
      onShiftStart: () => this.hud.toast('🕗 Tu turno comenzó. Revisa la consola del SOC en CyberShield.', 'info', 6000),
      onIncident: (inc) => this.hud.toast(`🚨 Nueva alerta (${inc.challenge.severity}): ${inc.challenge.title}`, 'alert', 6000),
      onExpired: (inc) => this.hud.toast(`⌛ El incidente #${inc.id} escaló por falta de respuesta (−6 ⭐)`, 'alert', 6000),
      onDayEnd: () => this.endDay(),
    });

    this.player.spawn(SPAWN.x, SPAWN.z, SPAWN.yaw);
    window.addEventListener('resize', () => this.resize());
    this.resize();
    this.bindUI();

    if (import.meta.env.DEV) Object.assign(window, { __game: this });
    this.renderer.setAnimationLoop(() => this.frame());
  }

  private setupLights(): void {
    const scene = this.world.scene;
    scene.add(this.hemi);
    this.sun.castShadow = true;
    this.sun.shadow.mapSize.set(2048, 2048);
    const s = this.sun.shadow.camera;
    s.left = s.bottom = -110;
    s.right = s.top = 110;
    s.near = 1;
    s.far = 400;
    this.sun.shadow.bias = -0.0004;
    this.sun.shadow.normalBias = 0.04;
    scene.add(this.sun, this.sun.target);
    scene.fog = new THREE.Fog('#a9d4f2', 140, 380);
    scene.background = new THREE.Color('#a9d4f2');
  }

  /** Sol que recorre el cielo de este a oeste durante la jornada. */
  private updateSun(): void {
    const k = THREE.MathUtils.clamp((this.state.minutes - 6 * 60) / (12 * 60), 0, 1); // 06:00 → 18:00
    const az = Math.PI * k;
    const elev = Math.sin(Math.PI * k) * 1.05 + 0.12;
    this.sun.position.set(Math.cos(az) * 150, Math.sin(elev) * 180, 60 + Math.cos(elev) * 40);
    const evening = THREE.MathUtils.smoothstep(this.state.minutes, 15 * 60, 17.5 * 60);
    this.sun.color.set('#fff4e0').lerp(new THREE.Color('#ffb36b'), evening);
    const sky = new THREE.Color('#a9d4f2').lerp(new THREE.Color('#f2b38a'), evening * 0.7);
    (this.world.scene.background as THREE.Color).copy(sky);
    this.world.scene.fog!.color.copy(sky);
  }

  private bindUI(): void {
    const hasSave = this.state.load();
    const btnStart = $('btn-start');
    const btnNew = $('btn-new');
    if (hasSave) {
      btnStart.textContent = `Continuar (Día ${this.state.day})`;
      btnNew.classList.remove('hidden');
      this.workday.planDay();
    }
    btnStart.addEventListener('click', () => this.begin());
    btnNew.addEventListener('click', () => {
      GameState.clearSave();
      location.reload();
    });
    $('pause').addEventListener('click', () => this.lock());
    document.addEventListener('pointerlockchange', () => this.refreshPause());
    this.canvas.addEventListener('click', () => {
      if (this.started && !this.modal.isOpen) this.lock();
    });
    const t = Number(this.params.get('time'));
    if (t) this.state.minutes = t;
  }

  private begin(): void {
    this.started = true;
    $('start').classList.add('hidden');
    this.hud.show();
    this.hud.toast('Bienvenido a CyberCity. Tu turno en CyberShield empieza a las 08:00.', 'info', 6000);
    this.lock();
  }

  /** `?nolock` desactiva el Pointer Lock (útil para pruebas automatizadas). */
  private lock(): void {
    if (!this.noLock) this.input.lock();
  }

  private get active(): boolean {
    return this.started && !this.modal.isOpen && (this.input.isLocked || this.noLock);
  }

  private refreshPause(): void {
    const paused = this.started && !this.modal.isOpen && !this.input.isLocked && !this.noLock;
    $('pause').classList.toggle('hidden', !paused);
  }

  private openModal(): HTMLElement {
    this.input.unlock();
    const body = this.modal.open(() => {
      this.lock();
      this.refreshPause();
    });
    this.refreshPause();
    return body;
  }

  private openShop(def: BusinessDef): void {
    const body = this.openModal();
    renderShop(body, def, this.state, () => this.modal.close(), (msg, good) => this.hud.toast(msg, good ? 'good' : 'alert'));
  }

  private openConsole(): void {
    const body = this.openModal();
    new SocConsole(body, this.state, this.workday, () => this.modal.close(), (msg, good) => this.hud.toast(msg, good ? 'good' : 'alert')).render();
  }

  private endDay(): void {
    const fired = this.state.reputation <= 0;
    const body = this.openModal();
    renderDaySummary(body, this.state, fired, () => {
      if (fired) {
        GameState.clearSave();
        location.reload();
        return;
      }
      this.state.earn(CONFIG.dailySalary);
      this.state.startNextDay();
      this.workday.planDay();
      this.player.spawn(SPAWN.x, SPAWN.z, SPAWN.yaw);
      this.lowEnergyWarned = false;
      this.modal.close();
      this.hud.toast(`☀️ Día ${this.state.day}. Salario recibido: +$${CONFIG.dailySalary}. ¡A trabajar!`, 'good', 6000);
    });
  }

  private objective(): string {
    const pending = this.workday.pending.length;
    const m = this.state.minutes;
    if (pending) return `🚨 ${pending} incidente(s) pendiente(s): ve a tu estación de trabajo en el SOC de CyberShield.`;
    if (m < CONFIG.shiftStart) return 'Dirígete a CyberShield (torre azul al norte del parque). Tu turno empieza a las 08:00.';
    if (this.state.energy < CONFIG.lowEnergy) return '⚡ Energía baja: pasa por Café Byte o el MegaMarket.';
    return 'Sin alertas. Puedes recorrer la ciudad; te avisaremos cuando llegue una nueva alerta.';
  }

  private resize(): void {
    const w = window.innerWidth;
    const h = window.innerHeight;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  }

  private frame(): void {
    this.timer.update();
    const dt = Math.min(this.timer.getDelta(), 0.05);

    if (this.active) {
      this.time += dt;
      this.player.speedMultiplier = this.state.energy < CONFIG.lowEnergy ? 0.7 : 1;
      this.player.update(dt, this.input);
      if (this.input.wasPressed('KeyV')) this.player.toggleCamera();
      if (this.input.wasPressed('KeyH')) this.hud.toggleHelp();

      const near = this.world.nearestInteractable(this.player.position);
      this.hud.setPrompt(near ? near.label() : null);
      if (near && this.input.wasPressed('KeyE')) near.action();

      const minutes = dt * CONFIG.timeScale;
      this.state.minutes += minutes;
      this.state.addEnergy(-CONFIG.energyDrainPerMinute * minutes);
      if (this.state.energy < CONFIG.lowEnergy && !this.lowEnergyWarned) {
        this.lowEnergyWarned = true;
        this.hud.toast('⚡ Tu energía está baja: caminarás más lento. Toma un café.', 'alert');
      }
      if (this.state.energy >= CONFIG.lowEnergy + 10) this.lowEnergyWarned = false;
      this.workday.update();
      this.world.update(dt, this.time);
    } else {
      this.hud.setPrompt(null);
    }

    this.player.updateCamera(this.camera, dt);
    this.hud.setCrosshair(this.player.mode === 'first');
    this.updateSun();
    if (this.started) {
      this.hud.update(this.state, this.workday.pending);
      this.hud.setObjective(this.objective());
      const target = this.workday.pending.length || this.state.minutes < CONFIG.shiftStart ? this.world.markers.hq : null;
      this.minimap.draw(this.player.position.x, this.player.position.z, this.player.yaw, target, this.time);
    }
    this.renderer.render(this.world.scene, this.camera);
    this.input.endFrame();
  }
}
