import { CONFIG } from '../config';
import { GameState } from '../core/GameState';
import { Incident } from '../cyber/types';
import { WorkDay } from '../cyber/WorkDay';
import { $, esc } from './dom';

export class HUD {
  private els = {
    hud: $('hud'),
    day: $('day'),
    clock: $('clock'),
    energy: $('energy-bar'),
    rep: $('rep-bar'),
    money: $('money'),
    alerts: $('alerts'),
    prompt: $('prompt'),
    crosshair: $('crosshair'),
    objective: $('objective'),
    help: $('help'),
    toasts: $('toasts'),
  };
  private lastAlertsKey = '';

  show(): void {
    this.els.hud.classList.remove('hidden');
  }

  toggleHelp(): void {
    this.els.help.classList.toggle('hidden');
  }

  toast(text: string, kind: 'info' | 'alert' | 'good' = 'info', ms = 4500): void {
    const el = document.createElement('div');
    el.className = `toast ${kind}`;
    el.textContent = text;
    this.els.toasts.appendChild(el);
    while (this.els.toasts.children.length > 4) this.els.toasts.firstChild?.remove();
    setTimeout(() => el.remove(), ms);
  }

  setPrompt(label: string | null): void {
    if (!label) {
      this.els.prompt.classList.add('hidden');
      return;
    }
    this.els.prompt.innerHTML = `<kbd>E</kbd> ${esc(label)}`;
    this.els.prompt.classList.remove('hidden');
  }

  setCrosshair(visible: boolean): void {
    this.els.crosshair.classList.toggle('hidden', !visible);
  }

  setObjective(text: string): void {
    if (this.els.objective.textContent !== text) this.els.objective.textContent = text;
  }

  update(state: GameState, pending: Incident[]): void {
    this.els.day.textContent = `Día ${state.day}`;
    this.els.clock.textContent = state.clock;
    this.els.energy.style.width = `${state.energy}%`;
    this.els.energy.style.background = state.energy < CONFIG.lowEnergy ? 'var(--red)' : 'var(--amber)';
    this.els.rep.style.width = `${state.reputation}%`;
    this.els.money.textContent = state.money.toFixed(0);

    const key = pending.map((p) => `${p.id}:${Math.ceil((p.deadline - state.minutes) / 5)}`).join('|');
    if (key === this.lastAlertsKey) return;
    this.lastAlertsKey = key;
    if (!pending.length) {
      this.els.alerts.innerHTML = '<h4>ALERTAS SOC</h4><div class="muted">Sin alertas pendientes</div>';
      return;
    }
    this.els.alerts.innerHTML =
      '<h4>ALERTAS SOC</h4>' +
      pending
        .map((p) => {
          const left = Math.max(0, Math.round(p.deadline - state.minutes));
          const color = left < 20 ? 'var(--red)' : left < 45 ? 'var(--amber)' : 'var(--green)';
          return `<div class="alert-item"><span>${esc(WorkDay.label(p))}</span><span class="t" style="color:${color}">${left}m</span></div>`;
        })
        .join('');
  }
}
