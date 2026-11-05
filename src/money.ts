// Dinheiro é SEMPRE guardado em centavos (número inteiro).
// Nunca use float para dinheiro: 0.1 + 0.2 !== 0.3 em JavaScript.

const formatter = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

/** 123456 -> "R$ 1.234,56" */
export function formatBRL(cents: number): string {
  return formatter.format(cents / 100);
}

/**
 * Converte o que o usuário digitou em centavos.
 * Aceita "1.234,56", "1234,56", "1234.56", "R$ 12", "12".
 * Retorna null se não for um valor válido.
 */
export function parseBRL(input: string): number | null {
  let s = input.replace(/[R$\s]/g, '');
  if (!s) return null;

  const lastComma = s.lastIndexOf(',');
  const lastDot = s.lastIndexOf('.');
  if (lastComma > lastDot) {
    // vírgula é o separador decimal (padrão BR): remove pontos de milhar
    s = s.replace(/\./g, '').replace(',', '.');
  } else if (lastDot > -1 && lastComma > -1) {
    // ponto é decimal e vírgula é milhar (padrão US)
    s = s.replace(/,/g, '');
  } else if (lastDot > -1 && /^\d{1,3}(\.\d{3})+$/.test(s)) {
    // "1.234" sem decimais -> milhar
    s = s.replace(/\./g, '');
  }

  if (!/^-?\d+(\.\d{1,2})?$/.test(s)) return null;
  const [int, dec = ''] = s.replace('-', '').split('.');
  const cents = Number(int) * 100 + Number(dec.padEnd(2, '0'));
  return s.startsWith('-') ? -cents : cents;
}

/** Centavos -> texto editável num input ("1234,56") */
export function centsToInput(cents: number): string {
  return (cents / 100).toFixed(2).replace('.', ',');
}
