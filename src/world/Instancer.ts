import * as THREE from 'three';

interface Batch {
  geometry: THREE.BufferGeometry;
  material: THREE.Material;
  matrices: THREE.Matrix4[];
  castShadow: boolean;
  receiveShadow: boolean;
}

/**
 * Agrupa mallas estáticas repetidas (árboles, farolas, pasos de cebra…) en
 * InstancedMesh: una sola llamada de dibujo por pareja geometría/material.
 */
export class Instancer {
  private batches = new Map<string, Batch>();

  /** Registra todas las mallas del objeto (con su transformación actual). No lo añade a la escena. */
  add(obj: THREE.Object3D): void {
    obj.updateMatrixWorld(true);
    obj.traverse((o) => {
      const mesh = o as THREE.Mesh;
      if (!mesh.isMesh || Array.isArray(mesh.material)) return;
      const key = `${mesh.geometry.uuid}|${mesh.material.uuid}`;
      let b = this.batches.get(key);
      if (!b) {
        b = { geometry: mesh.geometry, material: mesh.material, matrices: [], castShadow: mesh.castShadow, receiveShadow: mesh.receiveShadow };
        this.batches.set(key, b);
      }
      b.matrices.push(mesh.matrixWorld.clone());
    });
  }

  flush(scene: THREE.Scene): void {
    for (const b of this.batches.values()) {
      const inst = new THREE.InstancedMesh(b.geometry, b.material, b.matrices.length);
      b.matrices.forEach((m, i) => inst.setMatrixAt(i, m));
      inst.castShadow = b.castShadow;
      inst.receiveShadow = b.receiveShadow;
      inst.computeBoundingSphere();
      scene.add(inst);
    }
    this.batches.clear();
  }
}
