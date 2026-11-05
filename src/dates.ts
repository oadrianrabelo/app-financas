// Datas guardadas como texto "AAAA-MM-DD" (sem fuso horário = sem dor de cabeça).

export function today(): string {
  const d = new Date();
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** "2026-11" a partir de "2026-11-05" */
export function monthOf(date: string): string {
  return date.slice(0, 7);
}

/** Soma (ou subtrai) meses de um "AAAA-MM" */
export function addMonths(month: string, delta: number): string {
  const [y, m] = month.split('-').map(Number);
  const d = new Date(y, m - 1 + delta, 1);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}`;
}

export function monthLabel(month: string): string {
  const [y, m] = month.split('-').map(Number);
  const label = new Date(y, m - 1, 1).toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' });
  return label.charAt(0).toUpperCase() + label.slice(1);
}

export function formatDate(date: string): string {
  const [y, m, d] = date.split('-');
  return `${d}/${m}/${y}`;
}

function pad(n: number): string {
  return String(n).padStart(2, '0');
}
