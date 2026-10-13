import { $ } from './dom';

/** Ventana modal única. Mientras está abierta el juego se pausa. */
export class Modal {
  private root = $('modal');
  readonly body = $('modal-body');
  private onClose: (() => void) | null = null;

  constructor() {
    window.addEventListener('keydown', (e) => {
      if (e.code === 'Escape' && this.isOpen) this.close();
    });
  }

  get isOpen(): boolean {
    return !this.root.classList.contains('hidden');
  }

  open(onClose?: () => void): HTMLElement {
    this.onClose = onClose ?? null;
    this.body.innerHTML = '';
    this.root.classList.remove('hidden');
    return this.body;
  }

  close(): void {
    if (!this.isOpen) return;
    this.root.classList.add('hidden');
    const cb = this.onClose;
    this.onClose = null;
    cb?.();
  }
}
