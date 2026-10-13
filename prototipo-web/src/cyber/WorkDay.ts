import { CONFIG } from '../config';
import { GameState } from '../core/GameState';
import { pick, randInt } from '../core/random';
import { ALL_CATEGORIES, generateChallenge } from './generators';
import { CATEGORY_INFO, Category, ChallengeResult, Incident, SEVERITY_MULT } from './types';

export interface WorkDayEvents {
  onShiftStart: () => void;
  onIncident: (inc: Incident) => void;
  onExpired: (inc: Incident) => void;
  onDayEnd: () => void;
}

/** Jornada laboral: programa incidentes, controla plazos y calcula recompensas. */
export class WorkDay {
  incidents: Incident[] = [];
  private schedule: { at: number; category: Category }[] = [];
  private nextId = 1;
  private shiftAnnounced = false;
  private ended = false;

  constructor(private state: GameState, private events: WorkDayEvents) {
    this.planDay();
  }

  /** Más incidentes cada día, repartidos en la jornada. */
  planDay(): void {
    this.incidents = [];
    this.shiftAnnounced = false;
    this.ended = false;
    const count = Math.min(10, 4 + this.state.day);
    const start = CONFIG.shiftStart + 10;
    const end = CONFIG.shiftEnd - 75;
    const slot = (end - start) / count;
    this.schedule = Array.from({ length: count }, (_, i) => ({
      at: start + i * slot + randInt(0, Math.floor(slot * 0.7)),
      category: i < ALL_CATEGORIES.length ? ALL_CATEGORIES[i] : pick(ALL_CATEGORIES),
    }));
    // Aleatorizar el orden de categorías manteniendo los horarios
    const cats = this.schedule.map((s) => s.category).sort(() => Math.random() - 0.5);
    this.schedule.forEach((s, i) => (s.category = cats[i]));
  }

  get pending(): Incident[] {
    return this.incidents.filter((i) => i.status === 'pending');
  }

  update(): void {
    const now = this.state.minutes;
    if (!this.shiftAnnounced && now >= CONFIG.shiftStart) {
      this.shiftAnnounced = true;
      this.events.onShiftStart();
    }
    while (this.schedule.length && this.schedule[0].at <= now) {
      const { category } = this.schedule.shift()!;
      const challenge = generateChallenge(category);
      const window = challenge.severity === 'Crítica' ? 60 : challenge.severity === 'Alta' ? 80 : 110;
      const deadline = Math.min(now + window, CONFIG.shiftEnd);
      const inc: Incident = { id: this.nextId++, challenge, spawnedAt: now, deadline, status: 'pending' };
      this.incidents.push(inc);
      this.events.onIncident(inc);
    }
    for (const inc of this.pending) {
      if (now >= inc.deadline) {
        inc.status = 'expired';
        this.state.today.expired++;
        this.state.addReputation(-6);
        this.events.onExpired(inc);
      }
    }
    if (!this.ended && now >= CONFIG.shiftEnd) {
      this.ended = true;
      this.events.onDayEnd();
    }
  }

  /** Aplica el resultado de un reto y devuelve pago y cambio de reputación. */
  resolve(inc: Incident, result: ChallengeResult): { pay: number; rep: number } {
    inc.status = 'resolved';
    inc.result = result;
    const mult = SEVERITY_MULT[inc.challenge.severity];
    const pay = Math.round(result.score * 0.5 * mult);
    const rep = Math.round(((result.score - 60) / 8) * mult);
    this.state.earn(pay);
    this.state.addReputation(rep);
    this.state.addEnergy(-CONFIG.energyCostPerIncident);
    this.state.today.resolved++;
    this.state.today.scores.push(result.score);
    return { pay, rep };
  }

  static label(inc: Incident): string {
    return `${CATEGORY_INFO[inc.challenge.category].icon} ${CATEGORY_INFO[inc.challenge.category].name}`;
  }
}
