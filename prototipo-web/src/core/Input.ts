/** Teclado + ratón con Pointer Lock. `wasPressed` solo es cierto durante el frame en que se pulsó. */
export class Input {
  private keys = new Set<string>();
  private pressed = new Set<string>();
  mouseDX = 0;
  mouseDY = 0;
  wheel = 0;

  constructor(private element: HTMLElement) {
    window.addEventListener('keydown', (e) => {
      if (!this.keys.has(e.code)) this.pressed.add(e.code);
      this.keys.add(e.code);
      if (e.code === 'Space' && this.isLocked) e.preventDefault();
    });
    window.addEventListener('keyup', (e) => this.keys.delete(e.code));
    window.addEventListener('blur', () => this.keys.clear());
    document.addEventListener('mousemove', (e) => {
      if (!this.isLocked) return;
      this.mouseDX += e.movementX;
      this.mouseDY += e.movementY;
    });
    window.addEventListener('wheel', (e) => (this.wheel += Math.sign(e.deltaY)), { passive: true });
  }

  get isLocked(): boolean {
    return document.pointerLockElement === this.element;
  }

  lock(): void {
    try {
      const result = this.element.requestPointerLock() as unknown;
      if (result instanceof Promise) result.catch(() => undefined);
    } catch {
      /* algunos navegadores lanzan si no hay gesto del usuario */
    }
  }

  unlock(): void {
    if (this.isLocked) document.exitPointerLock();
  }

  isDown(code: string): boolean {
    return this.keys.has(code);
  }

  wasPressed(code: string): boolean {
    return this.pressed.has(code);
  }

  endFrame(): void {
    this.pressed.clear();
    this.mouseDX = 0;
    this.mouseDY = 0;
    this.wheel = 0;
  }
}
