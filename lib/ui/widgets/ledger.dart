// Peças da "folha de caderno": pauta, margem, linhas de item, títulos.
// Tudo tem altura múltipla de [kLine], para o texto cair em cima da pauta.
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../theme/paper.dart';

const double kLine = 34; // distância entre as linhas da pauta
const double kMarginX = 40; // posição da margem vermelha

/// Folha pautada com margem. A pauta rola junto com o conteúdo.
class LedgerSheet extends StatelessWidget {
  const LedgerSheet({super.key, required this.children, this.minHeight = 0, this.padding = 20});
  final List<Widget> children;
  final double minHeight;
  final double padding; // margem direita

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.paper,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: CustomPaint(
        painter: _RulePainter(p),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(kMarginX + 10, kLine, padding, kLine),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ),
    );
  }
}

class _RulePainter extends CustomPainter {
  _RulePainter(this.p);
  final Paper p;

  @override
  void paint(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = p.rule
      ..strokeWidth = 1;
    for (var y = kLine * 2; y < size.height; y += kLine) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    final margin = Paint()
      ..color = p.margin
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(kMarginX, 0), Offset(kMarginX, size.height), margin);
    canvas.drawLine(const Offset(kMarginX + 3, 0), Offset(kMarginX + 3, size.height), margin);
  }

  @override
  bool shouldRepaint(_RulePainter old) => old.p != p;
}

/// Título de seção sublinhado ("Cartão", "Casa"...). Ocupa 2 linhas.
class LedgerHeading extends StatelessWidget {
  const LedgerHeading(this.text, {super.key, this.trailing, this.big = false});
  final String text;
  final Widget? trailing;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return SizedBox(
      height: kLine * 2,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                text,
                style: p
                    .hand(big ? 40 : 28, color: big ? p.redInk : p.ink, weight: FontWeight.w600)
                    .copyWith(decoration: big ? null : TextDecoration.underline, decorationColor: p.ink),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Uma linha do caderno: [✓] descrição ........ valor
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.label,
    this.value,
    this.sign = '',
    this.checked,
    this.onCheck,
    this.onTap,
    this.color,
    this.bold = false,
    this.note,
  });

  final String label;
  final int? value; // centavos
  final String sign; // '−', '+' ou ''
  final bool? checked; // null = sem caixinha
  final VoidCallback? onCheck;
  final VoidCallback? onTap;
  final Color? color;
  final bool bold;
  final String? note; // texto pequeno a lápis depois do rótulo

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final c = color ?? p.ink;
    // Os pontinhos ficam atrás, na largura toda; o texto e o valor têm fundo
    // de papel e "apagam" os pontinhos embaixo deles. Assim o valor fica
    // sempre encostado à direita, como numa coluna de caderno.
    final valueText = value == null
        ? null
        : Text(
            '$sign${formatBRL(value!)}',
            style: p.mono(15, color: c, weight: bold ? FontWeight.w700 : FontWeight.w500),
          );
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: kLine,
        child: Stack(
          children: [
            if (value != null) Positioned(left: 0, right: 0, bottom: 7, height: 3, child: _Dots(color: p.rule)),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: ColoredBox(
                      color: p.paper,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (checked != null)
                              SizedBox(
                                width: 30,
                                child: InkResponse(
                                  onTap: onCheck,
                                  radius: 18,
                                  child: Text(
                                    checked! ? '✓' : '○',
                                    style: p.hand(
                                      checked! ? 26 : 18,
                                      color: checked! ? p.redInk : p.pencil,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            // Rótulo + anotação a lápis num texto só: se faltar espaço,
                            // corta a anotação primeiro, e o rótulo fica inteiro.
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: label,
                                      style: p.hand(23, color: c, weight: bold ? FontWeight.w700 : null),
                                    ),
                                    if (note != null && note!.isNotEmpty)
                                      TextSpan(
                                        text: '  $note',
                                        style: p.hand(17, color: p.pencil),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (valueText != null)
                    ColoredBox(
                      color: p.paper,
                      child: Padding(padding: const EdgeInsets.only(left: 6), child: valueText),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pontinhos ligando a descrição ao valor.
class _Dots extends StatelessWidget {
  const _Dots({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(height: 8, child: CustomPaint(painter: _DotsPainter(color)));
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawCircle(Offset(x, size.height / 2), 1, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

/// Linha vazia da pauta (espaçador).
class LedgerGap extends StatelessWidget {
  const LedgerGap({super.key, this.lines = 1});
  final int lines;

  @override
  Widget build(BuildContext context) => SizedBox(height: kLine * lines);
}

/// Bilhete tipo post-it, para lembretes. Ocupa 3 linhas.
class StickyNote extends StatelessWidget {
  const StickyNote({super.key, required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return SizedBox(
      height: kLine * 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Transform.rotate(
          angle: -0.008,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: p.sticky,
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(1, 2))],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(text, style: p.hand(21), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  ?action,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
