import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/domain/tithe.dart';

void main() {
  test('percentuais batem com o caderno (arredonda para baixo)', () {
    expect(percentOf(405301, 1000), 40530); // dízimo 405,30
    expect(percentOf(405301, 100), 4053); // oferta 1% = 40,53
    expect(percentOf(405301, 250), 10132); // oferta 2,5% = 101,32
    expect(405301 - 40530 - 10132, 354639); // valor final 3.546,39
  });

  test('formatBp / parseBp / bpOf', () {
    expect(formatBp(1000), '10%');
    expect(formatBp(250), '2,5%');
    expect(formatBp(125), '1,25%');
    expect(parseBp('2,5'), 250);
    expect(parseBp('10%'), 1000);
    expect(parseBp('abc'), isNull);
    expect(bpOf(10132, 405301), 250);
  });
}
