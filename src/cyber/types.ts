export type Category = 'vuln' | 'malware' | 'intrusion' | 'phishing';
export type Severity = 'Baja' | 'Media' | 'Alta' | 'Crítica';

export const CATEGORY_INFO: Record<Category, { name: string; icon: string }> = {
  vuln: { name: 'Escaneo de vulnerabilidades', icon: '🛡️' },
  malware: { name: 'Análisis de malware', icon: '🦠' },
  intrusion: { name: 'Intrusión en el sistema', icon: '🚨' },
  phishing: { name: 'Campaña de phishing', icon: '🎣' },
};

export const SEVERITY_MULT: Record<Severity, number> = { Baja: 0.8, Media: 1, Alta: 1.25, Crítica: 1.5 };

export interface ChallengeRow {
  cells: string[];
  /** true si el elemento es malicioso / vulnerable y debe marcarse. */
  bad: boolean;
  explanation: string;
}

export interface ActionOption {
  text: string;
  correct: boolean;
  feedback: string;
}

/**
 * Un reto es data-driven: una tabla donde el analista marca los elementos
 * sospechosos y luego elige la acción de respuesta correcta.
 */
export interface Challenge {
  category: Category;
  title: string;
  severity: Severity;
  briefing: string;
  instruction: string;
  columns: string[];
  rows: ChallengeRow[];
  action: { question: string; options: ActionOption[] };
}

export interface ChallengeResult {
  score: number;
  rowsCorrect: number;
  rowsTotal: number;
  actionCorrect: boolean;
}

export type IncidentStatus = 'pending' | 'resolved' | 'expired';

export interface Incident {
  id: number;
  challenge: Challenge;
  spawnedAt: number;
  deadline: number;
  status: IncidentStatus;
  result?: ChallengeResult;
}

export function scoreChallenge(ch: Challenge, selected: Set<number>, actionIndex: number): ChallengeResult {
  let rowsCorrect = 0;
  ch.rows.forEach((r, i) => {
    if (r.bad === selected.has(i)) rowsCorrect++;
  });
  const actionCorrect = ch.action.options[actionIndex]?.correct ?? false;
  const score = Math.round((rowsCorrect / ch.rows.length) * 70 + (actionCorrect ? 30 : 0));
  return { score, rowsCorrect, rowsTotal: ch.rows.length, actionCorrect };
}
