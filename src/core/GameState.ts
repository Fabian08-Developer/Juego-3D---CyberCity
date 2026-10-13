import { CONFIG } from '../config';

export interface DayStats {
  resolved: number;
  expired: number;
  earned: number;
  reputationDelta: number;
  scores: number[];
}

/** Estado persistente del jugador (se guarda en localStorage al terminar cada día). */
export class GameState {
  day = 1;
  minutes = CONFIG.dayStart;
  money = CONFIG.startMoney;
  reputation = CONFIG.startReputation;
  energy = 100;
  today: DayStats = GameState.emptyDay();

  static emptyDay(): DayStats {
    return { resolved: 0, expired: 0, earned: 0, reputationDelta: 0, scores: [] };
  }

  get clock(): string {
    const h = Math.floor(this.minutes / 60);
    const m = Math.floor(this.minutes % 60);
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
  }

  addReputation(delta: number): void {
    const before = this.reputation;
    this.reputation = Math.max(0, Math.min(100, this.reputation + delta));
    this.today.reputationDelta += this.reputation - before;
  }

  addEnergy(delta: number): void {
    this.energy = Math.max(0, Math.min(100, this.energy + delta));
  }

  earn(amount: number): void {
    this.money += amount;
    this.today.earned += amount;
  }

  startNextDay(): void {
    this.day++;
    this.minutes = CONFIG.dayStart;
    this.energy = 100;
    this.today = GameState.emptyDay();
    this.save();
  }

  save(): void {
    try {
      localStorage.setItem('cybercity-save', JSON.stringify({ day: this.day, money: this.money, reputation: this.reputation }));
    } catch {
      /* almacenamiento no disponible */
    }
  }

  load(): boolean {
    try {
      const raw = localStorage.getItem('cybercity-save');
      if (!raw) return false;
      const d = JSON.parse(raw) as Partial<GameState>;
      this.day = d.day ?? 1;
      this.money = d.money ?? CONFIG.startMoney;
      this.reputation = d.reputation ?? CONFIG.startReputation;
      return true;
    } catch {
      return false;
    }
  }

  static clearSave(): void {
    try {
      localStorage.removeItem('cybercity-save');
    } catch {
      /* ignorar */
    }
  }
}
