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

/// Fonte da interface (botões, menus, formulários). A letra de mão fica só no caderno.
const uiFont = 'Inter';

/// Linha fina usada em bordas e divisórias (estilo Radix/Raycast).
Color hairline(Paper p) => p.ink.withValues(alpha: 0.12);

ThemeData paperTheme(Brightness brightness, {required String hand, required String mono}) {
  final light = brightness == Brightness.light;
  final p = light ? Paper.light(hand: hand, mono: mono) : Paper.dark(hand: hand, mono: mono);
  final line = hairline(p);
  final accent = light ? const Color(0xFF1F4D3A) : const Color(0xFF8FD1AE);
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1F4D3A), brightness: brightness).copyWith(
    primary: p.ink, // ação principal = tinta (preto-azulado), como no Raycast
    onPrimary: p.paper,
    secondary: accent,
    surface: p.paper,
    onSurface: p.ink,
    onSurfaceVariant: p.pencil,
    outline: line,
    outlineVariant: line,
    surfaceTint: Colors.transparent,
    error: p.redInk,
  );
  final radius = BorderRadius.circular(8);
  final text = Typography.material2021(platform: TargetPlatform.macOS).black
      .apply(fontFamily: uiFont, bodyColor: p.ink, displayColor: p.ink);
  WidgetStateProperty<Color?> hoverPress(Color base) => WidgetStateProperty.resolveWith((s) {
    if (s.contains(WidgetState.pressed)) return base.withValues(alpha: 0.10);
    if (s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)) return base.withValues(alpha: 0.06);
    return null;
  });
  final buttonText = WidgetStatePropertyAll(
    TextStyle(fontFamily: uiFont, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.1),
  );
  const buttonPadding = WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 10));
  final shape = WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radius));

  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: uiFont,
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.4),
      titleMedium: text.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
      bodySmall: text.bodySmall?.copyWith(fontSize: 12.5, color: p.pencil),
    ),
    scaffoldBackgroundColor: p.paperShade,
    extensions: [p],
    // Sem ondas de toque do Android: só um realce discreto.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: p.ink.withValues(alpha: 0.05),
    focusColor: accent.withValues(alpha: 0.18),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: p.paper,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? p.ink.withValues(alpha: 0.2) : p.ink,
        ),
        foregroundColor: WidgetStatePropertyAll(p.paper),
        overlayColor: hoverPress(p.paper),
        textStyle: buttonText,
        padding: buttonPadding,
        shape: shape,
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(p.ink),
        overlayColor: hoverPress(p.ink),
        textStyle: buttonText,
        padding: buttonPadding,
        shape: shape,
        minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(p.ink),
        overlayColor: hoverPress(p.ink),
        side: WidgetStatePropertyAll(BorderSide(color: line)),
        textStyle: buttonText,
        padding: buttonPadding,
        shape: shape,
        minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(p.pencil),
        overlayColor: hoverPress(p.ink),
        shape: shape,
        iconSize: const WidgetStatePropertyAll(18),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.ink.withValues(alpha: 0.08) : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.ink : p.pencil),
        overlayColor: hoverPress(p.ink),
        side: WidgetStatePropertyAll(BorderSide(color: line)),
        textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: uiFont, fontSize: 13.5, fontWeight: FontWeight.w600)),
        shape: shape,
        visualDensity: VisualDensity.compact,
      ),
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      backgroundColor: Colors.transparent,
      selectedColor: p.ink.withValues(alpha: 0.08),
      side: BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: radius),
      labelStyle: TextStyle(fontFamily: uiFont, fontSize: 13.5, fontWeight: FontWeight.w500, color: p.ink),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: p.pencil, width: 1.4),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.ink : null),
      checkColor: WidgetStatePropertyAll(p.paper),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.ink : p.pencil),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: light ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: TextStyle(color: p.pencil, fontSize: 14),
      floatingLabelStyle: TextStyle(color: p.ink, fontSize: 13, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: p.pencil.withValues(alpha: 0.7)),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: p.redInk),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.paper),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: line),
          ),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.paper,
      elevation: 8,
      shadowColor: Colors.black26,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: line),
      ),
      textStyle: TextStyle(fontFamily: uiFont, fontSize: 14, color: p.ink),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: line),
      ),
      titleTextStyle: TextStyle(fontFamily: uiFont, fontSize: 17, fontWeight: FontWeight.w600, color: p.ink),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.ink.withValues(alpha: 0.2),
      dragHandleSize: const Size(36, 4),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(fontFamily: uiFont, fontSize: 14, color: p.paper),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 6,
      width: 420,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(6)),
      textStyle: TextStyle(fontFamily: uiFont, fontSize: 12, color: p.paper),
      waitDuration: const Duration(milliseconds: 400),
    ),
    listTileTheme: ListTileThemeData(
      dense: true,
      titleTextStyle: TextStyle(fontFamily: uiFont, fontSize: 14, fontWeight: FontWeight.w500, color: p.ink),
      subtitleTextStyle: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: p.pencil),
      iconColor: p.pencil,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.ink,
      foregroundColor: p.paper,
      elevation: 2,
      hoverElevation: 4,
      highlightElevation: 2,
      extendedTextStyle: TextStyle(fontFamily: uiFont, fontSize: 14, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final t in TargetPlatform.values) t: const FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

/// Rolagem com "elástico" (como no Mac/iOS), sem o brilho do Android.
class SoftScrollBehavior extends MaterialScrollBehavior {
  const SoftScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
