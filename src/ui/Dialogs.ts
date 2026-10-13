import { GameState } from '../core/GameState';
import { BusinessDef } from '../data/businesses';
import { esc, html } from './dom';

export function renderShop(root: HTMLElement, def: BusinessDef, state: GameState, close: () => void, notify: (msg: string, good: boolean) => void): void {
  const draw = () => {
    root.innerHTML = '';
    root.appendChild(
      html(`<div class="row-actions" style="margin-top:0">
        <div><h2>${esc(def.name)}</h2><div class="muted">${esc(def.type)} · ${esc(def.greeting)}</div></div>
        <div>💰 $${state.money.toFixed(0)} · ⚡ ${Math.round(state.energy)}</div>
      </div>`),
    );
    const list = html('<div class="shop-items"></div>');
    if (!def.items.length) list.appendChild(html('<div class="muted">No hay productos a la venta aquí.</div>'));
    for (const item of def.items) {
      const effects = [item.energy ? `⚡ +${item.energy}` : '', item.reputation ? `⭐ ${item.reputation > 0 ? '+' : ''}${item.reputation}` : ''].filter(Boolean).join(' · ');
      const row = html(`<div class="shop-item">
        <div><b>${esc(item.name)}</b> <span class="muted">${esc(effects)}</span><div class="muted">${esc(item.description)}</div></div>
        <button ${state.money < item.price ? 'disabled' : ''}>${item.price ? `$${item.price}` : 'Gratis'}</button>
      </div>`);
      row.querySelector('button')!.addEventListener('click', () => {
        if (state.money < item.price) return;
        state.money -= item.price;
        if (item.energy) state.addEnergy(item.energy);
        if (item.reputation) state.addReputation(item.reputation);
        notify(`Compraste ${item.name}${item.reputation && item.reputation < 0 ? ' — ¡mala idea!' : ''}`, (item.reputation ?? 0) >= 0);
        draw();
      });
      list.appendChild(row);
    }
    root.appendChild(list);
    if (def.tip) root.appendChild(html(`<div class="tip">🔐 <b>Tip de seguridad:</b> ${esc(def.tip)}</div>`));
    const actions = html('<div class="row-actions"><span></span><button class="primary">Salir</button></div>');
    actions.querySelector('button')!.addEventListener('click', close);
    root.appendChild(actions);
  };
  draw();
}

export function renderDaySummary(root: HTMLElement, state: GameState, fired: boolean, onContinue: () => void): void {
  const t = state.today;
  const avg = t.scores.length ? Math.round(t.scores.reduce((a, b) => a + b, 0) / t.scores.length) : 0;
  root.innerHTML = '';
  root.appendChild(
    html(`<div>
      <h2>${fired ? '📉 Has sido despedido' : `🌆 Fin de la jornada · Día ${state.day}`}</h2>
      <p class="muted">${
        fired
          ? 'Tu reputación llegó a 0. Demasiados incidentes sin atender o mal resueltos.'
          : 'Buen trabajo. Este es el resumen de tu turno en el SOC.'
      }</p>
      <div class="stats-grid">
        <div><b>${t.resolved}</b>Resueltos</div>
        <div><b>${t.expired}</b>Expirados</div>
        <div><b>${avg}</b>Puntaje medio</div>
        <div><b>$${t.earned}</b>Ganado hoy</div>
      </div>
      <p>⭐ Reputación: ${Math.round(state.reputation)}/100 (${t.reputationDelta >= 0 ? '+' : ''}${Math.round(t.reputationDelta)} hoy)</p>
    </div>`),
  );
  const actions = html(`<div class="row-actions"><span></span><button class="primary">${fired ? 'Empezar de nuevo' : 'Siguiente día →'}</button></div>`);
  actions.querySelector('button')!.addEventListener('click', onContinue);
  root.appendChild(actions);
}
