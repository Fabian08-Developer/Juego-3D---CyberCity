import * as THREE from 'three';
import { CONFIG } from '../config';
import { Input } from '../core/Input';
import { Person } from '../world/Characters';
import { World } from '../world/World';

export type CameraMode = 'first' | 'third';

/** Jugador con controlador de primera y tercera persona. */
export class Player {
  readonly person = new Person({ skin: '#e0ac69', shirt: '#0f172a', pants: '#334155', hair: '#1b1b1b' }, { badge: true });
  readonly position = new THREE.Vector3();
  private velocityY = 0;
  private onGround = true;
  yaw = 0;
  pitch = -0.15;
  mode: CameraMode = 'third';
  private distance = CONFIG.thirdPersonDistance;
  private currentDistance = CONFIG.thirdPersonDistance;
  private facing = 0;
  speedMultiplier = 1;
  horizontalSpeed = 0;

  private readonly raycaster = new THREE.Raycaster();
  private readonly tmpTarget = new THREE.Vector3();
  private readonly tmpDir = new THREE.Vector3();

  constructor(private world: World) {
    world.scene.add(this.person.root);
  }

  spawn(x: number, z: number, yaw: number): void {
    this.position.set(x, this.world.groundHeight(x, z), z);
    this.yaw = yaw;
    this.facing = yaw + Math.PI;
    this.velocityY = 0;
  }

  toggleCamera(): void {
    this.mode = this.mode === 'first' ? 'third' : 'first';
  }

  update(dt: number, input: Input): void {
    // Mirar
    this.yaw -= input.mouseDX * CONFIG.mouseSensitivity;
    this.pitch -= input.mouseDY * CONFIG.mouseSensitivity;
    this.pitch = THREE.MathUtils.clamp(this.pitch, -1.35, this.mode === 'first' ? 1.35 : 0.6);
    if (input.wheel) this.distance = THREE.MathUtils.clamp(this.distance + input.wheel * 0.5, 2, 8);

    // Moverse relativo a la cámara
    const fx = -Math.sin(this.yaw);
    const fz = -Math.cos(this.yaw);
    let mx = 0;
    let mz = 0;
    if (input.isDown('KeyW') || input.isDown('ArrowUp')) { mx += fx; mz += fz; }
    if (input.isDown('KeyS') || input.isDown('ArrowDown')) { mx -= fx; mz -= fz; }
    if (input.isDown('KeyA') || input.isDown('ArrowLeft')) { mx += fz; mz -= fx; }
    if (input.isDown('KeyD') || input.isDown('ArrowRight')) { mx -= fz; mz += fx; }
    const len = Math.hypot(mx, mz);
    const running = input.isDown('ShiftLeft') || input.isDown('ShiftRight');
    const speed = (running ? CONFIG.runSpeed : CONFIG.walkSpeed) * this.speedMultiplier;
    if (len > 0) {
      mx /= len;
      mz /= len;
      this.position.x += mx * speed * dt;
      this.position.z += mz * speed * dt;
      const targetFacing = Math.atan2(mx, mz);
      let diff = targetFacing - this.facing;
      diff = Math.atan2(Math.sin(diff), Math.cos(diff));
      this.facing += diff * Math.min(1, dt * 12);
    }
    this.horizontalSpeed = len > 0 ? speed : 0;
    this.world.resolveCircle(this.position, CONFIG.playerRadius);

    // Salto y gravedad (con escalón automático para bordillos)
    const ground = this.world.groundHeight(this.position.x, this.position.z);
    if (this.onGround && input.wasPressed('Space')) {
      this.velocityY = CONFIG.jumpSpeed;
      this.onGround = false;
    }
    this.velocityY -= CONFIG.gravity * dt;
    this.position.y += this.velocityY * dt;
    if (this.position.y <= ground || (this.onGround && this.position.y - ground < 0.3)) {
      this.position.y = ground;
      this.velocityY = 0;
      this.onGround = true;
    } else if (this.position.y > ground + 0.3) {
      this.onGround = false;
    }

    this.person.root.position.copy(this.position);
    this.person.root.rotation.y = this.facing;
    this.person.animate(dt, this.onGround ? this.horizontalSpeed : 0);
    this.person.root.visible = this.mode === 'third';
  }

  updateCamera(camera: THREE.PerspectiveCamera, dt: number): void {
    camera.rotation.order = 'YXZ';
    if (this.mode === 'first') {
      camera.position.set(this.position.x, this.position.y + CONFIG.eyeHeight, this.position.z);
      camera.rotation.set(this.pitch, this.yaw, 0);
      this.currentDistance = 0.5;
      return;
    }
    // Tercera persona: órbita detrás del hombro con detección de oclusión.
    const target = this.tmpTarget.set(this.position.x, this.position.y + 1.6, this.position.z);
    const right = new THREE.Vector3(Math.cos(this.yaw), 0, -Math.sin(this.yaw));
    target.addScaledVector(right, 0.45);
    const dir = this.tmpDir.set(
      Math.sin(this.yaw) * Math.cos(this.pitch),
      -Math.sin(this.pitch),
      Math.cos(this.yaw) * Math.cos(this.pitch),
    );
    this.raycaster.set(target, dir);
    this.raycaster.far = this.distance;
    const hit = this.raycaster.intersectObjects(this.world.occluders, false)[0];
    const wanted = hit ? Math.max(0.6, hit.distance - 0.3) : this.distance;
    // Acercarse rápido (evitar atravesar muros), alejarse suave.
    this.currentDistance = wanted < this.currentDistance ? wanted : this.currentDistance + (wanted - this.currentDistance) * Math.min(1, dt * 4);
    camera.position.copy(target).addScaledVector(dir, this.currentDistance);
    const floor = this.world.groundHeight(camera.position.x, camera.position.z) + 0.25;
    if (camera.position.y < floor) camera.position.y = floor;
    camera.rotation.set(this.pitch, this.yaw, 0);
  }
}
