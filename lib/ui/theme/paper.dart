import 'package:flutter/material.dart';

import 'fonts.dart';

/// Cores e fontes do "caderno". Pegue com `Paper.of(context)`.
@immutable
class Paper extends ThemeExtension<Paper> {
  const Paper({
    required this.paper,
    required this.paperShade,
    required this.rule,
    required this.margin,
    required this.ink,
    required this.redInk,
    required this.pencil,
    required this.greenInk,
    required this.sticky,
    required this.handFont,
    required this.monoFont,
  });

  final Color paper; // fundo da folha
  final Color paperShade; // folha de trás, bordas, abas
  final Color rule; // linhas da pauta
  final Color margin; // linha vermelha da margem
  final Color ink; // caneta azul-escura
  final Color redInk; // caneta vermelha: títulos, totais, ✓
  final Color pencil; // lápis: textos secundários
  final Color greenInk; // valores positivos
  final Color sticky; // post-it (lembretes)
  final String handFont;
  final String monoFont;

  static Paper of(BuildContext context) => Theme.of(context).extension<Paper>()!;

  /// Letra de mão (títulos, itens do caderno).
  TextStyle hand(double size, {Color? color, FontWeight? weight}) => TextStyle(
    fontFamily: handFont,
    fontSize: size * handScale(handFont),
    color: color ?? ink,
    fontWeight: weight,
    height: 1.1,
  );

  /// Números (valores alinhados).
  TextStyle mono(double size, {Color? color, FontWeight? weight}) => TextStyle(
    fontFamily: monoFont,
    fontSize: size,
    color: color ?? ink,
    fontWeight: weight,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static Paper light({required String hand, required String mono}) => Paper(
    paper: const Color(0xFFF7F1E3),
    paperShade: const Color(0xFFE9DFC8),
    rule: const Color(0xFFC9D6DE),
    margin: const Color(0xFFE0948A),
    ink: const Color(0xFF22304A),
    redInk: const Color(0xFFB83A2E),
    pencil: const Color(0xFF6E6A60),
    greenInk: const Color(0xFF2F6B4F),
    sticky: const Color(0xFFFCE9A6),
    handFont: hand,
    monoFont: mono,
  );

  static Paper dark({required String hand, required String mono}) => Paper(
    paper: const Color(0xFF1F1D19),
    paperShade: const Color(0xFF2A2722),
    rule: const Color(0xFF333D45),
    margin: const Color(0xFF7E433B),
    ink: const Color(0xFFE9E2D0),
    redInk: const Color(0xFFF08A7A),
    pencil: const Color(0xFFA39E91),
    greenInk: const Color(0xFF85C9A2),
    sticky: const Color(0xFF4A4126),
    handFont: hand,
    monoFont: mono,
  );

  @override
  Paper copyWith({String? handFont, String? monoFont}) => Paper(
    paper: paper,
    paperShade: paperShade,
    rule: rule,
    margin: margin,
    ink: ink,
    redInk: redInk,
    pencil: pencil,
    greenInk: greenInk,
    sticky: sticky,
    handFont: handFont ?? this.handFont,
    monoFont: monoFont ?? this.monoFont,
  );

  @override
  Paper lerp(Paper? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return Paper(
      paper: c(paper, other.paper),
      paperShade: c(paperShade, other.paperShade),
      rule: c(rule, other.rule),
      margin: c(margin, other.margin),
      ink: c(ink, other.ink),
      redInk: c(redInk, other.redInk),
      pencil: c(pencil, other.pencil),
      greenInk: c(greenInk, other.greenInk),
      sticky: c(sticky, other.sticky),
      handFont: t < 0.5 ? handFont : other.handFont,
      monoFont: t < 0.5 ? monoFont : other.monoFont,
    );
  }
}

ThemeData paperTheme(Brightness brightness, {required String hand, required String mono}) {
  final p = brightness == Brightness.light ? Paper.light(hand: hand, mono: mono) : Paper.dark(hand: hand, mono: mono);
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1F4D3A), brightness: brightness).copyWith(
    surface: p.paper,
    onSurface: p.ink,
    primary: brightness == Brightness.light ? const Color(0xFF1F4D3A) : null,
  );
  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: p.paperShade,
    extensions: [p],
    cardTheme: CardThemeData(
      color: p.paper,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: p.rule),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.paperShade,
      indicatorColor: p.paper,
      labelTextStyle: WidgetStatePropertyAll(p.hand(15)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: p.paperShade,
      indicatorColor: p.paper,
      selectedLabelTextStyle: p.hand(20, weight: FontWeight.w700),
      unselectedLabelTextStyle: p.hand(20, color: p.pencil),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.paper),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.paper),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: p.paperShade.withValues(alpha: 0.4)),
  );
}
