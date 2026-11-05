import { addMonths, monthLabel } from '../dates';

export default function MonthPicker({ month, onChange }: { month: string; onChange: (m: string) => void }) {
  return (
    <div className="month-picker">
      <button className="ghost" onClick={() => onChange(addMonths(month, -1))} aria-label="Mês anterior">‹</button>
      <strong>{monthLabel(month)}</strong>
      <button className="ghost" onClick={() => onChange(addMonths(month, 1))} aria-label="Próximo mês">›</button>
    </div>
  );
}
