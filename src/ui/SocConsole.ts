import { CONFIG } from '../config';
import { GameState } from '../core/GameState';
import { CATEGORY_INFO, Incident, scoreChallenge } from '../cyber/types';
import { WorkDay } from '../cyber/WorkDay';
import { esc, html } from './dom';

/**
 * Consola del SOC: lista de incidentes del día y flujo de resolución en 3 pasos:
 * 1) marcar elementos sospechosos, 2) elegir la respuesta, 3) revisar resultados.
 */
export class SocConsole {
  constructor(
    private root: HTMLElement,
    private state: GameState,
    private workday: WorkDay,
    private close: () => void,
    private onResolved: (msg: string, good: boolean) => void,
  ) {}

  render(selected?: Incident): void {
    const pending = this.workday.pending;
    const first = selected ?? pending[0];
    this.root.innerHTML = '';
    const header = html(`
      <div class="row-actions" style="margin-top:0">
        <div><h2>Consola SOC · CyberShield</h2><div class="muted">Día ${this.state.day} · ${this.state.clock} · Analista de turno: tú</div></div>
        <button class="ghost" data-close>Salir (Esc)</button>
      </div>`);
    header.querySelector('[data-close]')!.addEventListener('click', this.close);
    this.root.appendChild(header);

    const layout = html('<div class="soc" style="margin-top:16px"><div class="soc-list"></div><div class="soc-main"></div></div>');
    const list = layout.querySelector('.soc-list') as HTMLElement;
    const main = layout.querySelector('.soc-main') as HTMLElement;
    this.root.appendChild(layout);

    this.renderList(list, first);
    if (first && first.status === 'pending') this.renderSelect(main, first);
    else this.renderIdle(main);
  }

  private renderList(list: HTMLElement, active?: Incident): void {
    list.innerHTML = '';
    const all = [...this.workday.pending, ...this.workday.incidents.filter((i) => i.status !== 'pending').reverse()];
    if (!all.length) list.innerHTML = '<div class="muted">Aún no hay incidentes hoy.</div>';
    for (const inc of all) {
      const left = Math.max(0, Math.round(inc.deadline - this.state.minutes));
      const status =
        inc.status === 'pending' ? `⏱ ${left} min` : inc.status === 'resolved' ? `✔ ${inc.result!.score}/100` : '✘ Expirado';
      const item = html(`
        <div class="soc-item ${inc === active ? 'active' : ''} ${inc.status !== 'pending' ? 'done' : ''}">
          <div><span class="sev sev-${inc.challenge.severity}">${inc.challenge.severity}</span> <b>${esc(CATEGORY_INFO[inc.challenge.category].name)}</b></div>
          <div class="muted" style="margin-top:4px">${esc(inc.challenge.title)}</div>
          <div style="margin-top:4px">${status}</div>
        </div>`);
      if (inc.status === 'pending') item.addEventListener('click', () => this.render(inc));
      list.appendChild(item);
    }
  }

  private renderIdle(main: HTMLElement): void {
    const before = this.state.minutes < CONFIG.shiftStart;
    main.innerHTML = `
      <div class="term" style="min-height:300px">
        <div style="color:var(--cyan)">cybershield-soc ~$ status</div>
        <div>${before ? 'Turno aún no iniciado. Comienza a las 08:00.' : 'Sin alertas pendientes. Monitoreando la red…'}</div>
        <div style="margin-top:10px">Incidentes resueltos hoy: ${this.state.today.resolved}</div>
        <div>Incidentes expirados hoy: ${this.state.today.expired}</div>
        <div>Reputación: ${Math.round(this.state.reputation)}/100</div>
        <div style="margin-top:14px;color:var(--muted)">Consejo: puedes salir a la ciudad mientras no haya alertas. Te avisaremos cuando llegue una nueva.</div>
      </div>`;
  }

  private renderHeader(main: HTMLElement, inc: Incident): void {
    const ch = inc.challenge;
    main.appendChild(
      html(`<div>
        <div><span class="sev sev-${ch.severity}">${ch.severity}</span> <span class="muted">${esc(CATEGORY_INFO[ch.category].icon)} ${esc(CATEGORY_INFO[ch.category].name)} · Incidente #${inc.id}</span></div>
        <h3 style="margin:6px 0">${esc(ch.title)}</h3>
        <p class="muted" style="margin:0 0 10px">${esc(ch.briefing)}</p>
      </div>`),
    );
  }

  private table(inc: Incident, selected: Set<number>, review: boolean): HTMLElement {
    const ch = inc.challenge;
    const wrap = html(`<div class="term"><table class="data"><thead><tr>${ch.columns.map((c) => `<th>${esc(c)}</th>`).join('')}</tr></thead><tbody></tbody></table></div>`);
    const tbody = wrap.querySelector('tbody')!;
    ch.rows.forEach((row, i) => {
      const isSel = selected.has(i);
      const cls = review ? (row.bad === isSel ? 'ok' : 'bad') : 'row';
      const tr = html<HTMLTableRowElement>(
        `<table><tr class="${cls} ${isSel ? 'sel' : ''}">${row.cells.map((c) => `<td>${esc(c)}</td>`).join('')}</tr></table>`,
      ).querySelector('tr')!;
      if (!review) {
        tr.addEventListener('click', () => {
          if (selected.has(i)) selected.delete(i);
          else selected.add(i);
          tr.classList.toggle('sel');
        });
      }
      tbody.appendChild(tr);
      if (review) {
        const verdict = row.bad ? '⚠ Malicioso/vulnerable' : '✓ Legítimo';
        tbody.appendChild(
          html<HTMLTableRowElement>(`<table><tr class="explain"><td colspan="${ch.columns.length}">${verdict} — ${esc(row.explanation)}</td></tr></table>`).querySelector('tr')!,
        );
      }
    });
    return wrap;
  }

  private renderSelect(main: HTMLElement, inc: Incident): void {
    const selected = new Set<number>();
    main.innerHTML = '';
    this.renderHeader(main, inc);
    main.appendChild(html(`<p><b>Paso 1/2:</b> ${esc(inc.challenge.instruction)} <span class="muted">(clic en las filas)</span></p>`));
    main.appendChild(this.table(inc, selected, false));
    const actions = html('<div class="row-actions"><span class="muted">Analiza ruta, firma, versión, dominio u origen de cada elemento.</span><button class="primary">Continuar →</button></div>');
    actions.querySelector('button')!.addEventListener('click', () => this.renderAction(main, inc, selected));
    main.appendChild(actions);
  }

  private renderAction(main: HTMLElement, inc: Incident, selected: Set<number>): void {
    const ch = inc.challenge;
    let choice = -1;
    main.innerHTML = '';
    this.renderHeader(main, inc);
    main.appendChild(html(`<p><b>Paso 2/2:</b> ${esc(ch.action.question)}</p>`));
    const opts = html('<div class="options"></div>');
    const submit = html<HTMLButtonElement>('<button class="primary" disabled>Enviar respuesta</button>');
    ch.action.options.forEach((o, i) => {
      const b = html<HTMLButtonElement>(`<button class="option">${esc(o.text)}</button>`);
      b.addEventListener('click', () => {
        choice = i;
        opts.querySelectorAll('.option').forEach((el) => el.classList.remove('chosen'));
        b.classList.add('chosen');
        submit.disabled = false;
      });
      opts.appendChild(b);
    });
    main.appendChild(opts);
    const row = html('<div class="row-actions"></div>');
    const back = html<HTMLButtonElement>('<button class="ghost">← Volver</button>');
    back.addEventListener('click', () => {
      main.innerHTML = '';
      this.renderSelect(main, inc);
    });
    submit.addEventListener('click', () => this.renderResult(main, inc, selected, choice));
    row.append(back, submit);
    main.appendChild(row);
  }

  private renderResult(main: HTMLElement, inc: Incident, selected: Set<number>, choice: number): void {
    const ch = inc.challenge;
    const result = scoreChallenge(ch, selected, choice);
    const { pay, rep } = this.workday.resolve(inc, result);
    this.renderList(this.root.querySelector('.soc-list') as HTMLElement, inc);
    const color = result.score >= 80 ? 'var(--green)' : result.score >= 50 ? 'var(--amber)' : 'var(--red)';
    main.innerHTML = '';
    this.renderHeader(main, inc);
    main.appendChild(
      html(`<div class="row-actions" style="margin-top:0">
        <div><div class="result-score" style="color:${color}">${result.score}/100</div>
        <div class="muted">${result.rowsCorrect}/${result.rowsTotal} elementos bien clasificados · respuesta ${result.actionCorrect ? 'correcta' : 'incorrecta'}</div></div>
        <div style="text-align:right">💰 +$${pay}<br/>⭐ ${rep >= 0 ? '+' : ''}${rep} reputación</div>
      </div>`),
    );
    main.appendChild(this.table(inc, selected, true));
    const opts = html('<div class="options"></div>');
    ch.action.options.forEach((o, i) => {
      const cls = o.correct ? 'correct' : i === choice ? 'wrong' : '';
      opts.appendChild(html(`<div class="option button ${cls}" style="padding:10px;border:1px solid rgba(255,255,255,.12);border-radius:8px">${esc(o.text)}${cls ? `<div class="muted" style="margin-top:4px">${esc(o.feedback)}</div>` : ''}</div>`));
    });
    main.appendChild(opts);
    const row = html('<div class="row-actions"><span></span><button class="primary">Cerrar incidente</button></div>');
    row.querySelector('button')!.addEventListener('click', () => this.render());
    main.appendChild(row);
    this.onResolved(`Incidente #${inc.id} cerrado: ${result.score}/100 (+$${pay})`, result.score >= 60);
  }
}
