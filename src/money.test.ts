import { describe, expect, it } from 'vitest';
import { centsToInput, parseBRL } from './money';

describe('parseBRL', () => {
  it.each([
    ['12', 1200],
    ['12,5', 1250],
    ['12,50', 1250],
    ['1.234,56', 123456],
    ['1234.56', 123456],
    ['1,234.56', 123456],
    ['1.234', 123400],
    ['R$ 99,90', 9990],
    ['-10,00', -1000],
    ['0,01', 1],
  ])('%s -> %i', (input, expected) => {
    expect(parseBRL(input)).toBe(expected);
  });

  it.each(['', 'abc', '1,2,3', '12,345'])('rejeita "%s"', (input) => {
    expect(parseBRL(input)).toBeNull();
  });
});

describe('centsToInput', () => {
  it('formata com vírgula', () => {
    expect(centsToInput(123456)).toBe('1234,56');
  });
});
