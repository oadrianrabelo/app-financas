// Temas do caderno. Cada um é um "papel": cores do fundo, da pauta, da tinta.
// Para criar um novo, copie um da lista e mude as cores.
import 'dart:ui' show Brightness, Color;

class PaperSpec {
  const PaperSpec({
    required this.id,
    required this.name,
    required this.brightness,
    required this.paper,
    required this.paperShade,
    required this.rule,
    required this.margin,
    required this.ink,
    required this.redInk,
    required this.pencil,
    required this.greenInk,
    required this.sticky,
    required this.accent,
  });
  final String id, name;
  final Brightness brightness;
  final Color paper, paperShade, rule, margin, ink, redInk, pencil, greenInk, sticky, accent;
  bool get dark => brightness == Brightness.dark;
}

const paperSpecs = [
  // ---- claros ----
  PaperSpec(
    id: 'papel',
    name: 'Papel',
    brightness: Brightness.light,
    paper: Color(0xFFF7F1E3),
    paperShade: Color(0xFFE9DFC8),
    rule: Color(0xFFC9D6DE),
    margin: Color(0xFFE0948A),
    ink: Color(0xFF22304A),
    redInk: Color(0xFFB83A2E),
    pencil: Color(0xFF6E6A60),
    greenInk: Color(0xFF2F6B4F),
    sticky: Color(0xFFFCE9A6),
    accent: Color(0xFF2F6B4F),
  ),
  PaperSpec(
    id: 'sepia',
    name: 'Sépia',
    brightness: Brightness.light,
    paper: Color(0xFFF2E6CC),
    paperShade: Color(0xFFE2D1AE),
    rule: Color(0xFFD3C29E),
    margin: Color(0xFFC98A6B),
    ink: Color(0xFF3B2A1A),
    redInk: Color(0xFF9E3B23),
    pencil: Color(0xFF7A6A52),
    greenInk: Color(0xFF4E6B3A),
    sticky: Color(0xFFF4D98B),
    accent: Color(0xFF8A5A2B),
  ),
  PaperSpec(
    id: 'kraft',
    name: 'Kraft',
    brightness: Brightness.light,
    paper: Color(0xFFDCC49B),
    paperShade: Color(0xFFC8AC7E),
    rule: Color(0xFFBFA275),
    margin: Color(0xFF9E5B3C),
    ink: Color(0xFF2E2216),
    redInk: Color(0xFF8E2E1E),
    pencil: Color(0xFF5E4A33),
    greenInk: Color(0xFF3C5A2E),
    sticky: Color(0xFFF2E2A0),
    accent: Color(0xFF6B3E1F),
  ),
  PaperSpec(
    id: 'menta',
    name: 'Contábil',
    brightness: Brightness.light,
    paper: Color(0xFFEEF4E8),
    paperShade: Color(0xFFDCE6D3),
    rule: Color(0xFFB7CCB0),
    margin: Color(0xFFD98E85),
    ink: Color(0xFF1F3A2E),
    redInk: Color(0xFFB23A2E),
    pencil: Color(0xFF5E7064),
    greenInk: Color(0xFF2F6B4F),
    sticky: Color(0xFFFBEBA8),
    accent: Color(0xFF2F6B4F),
  ),
  PaperSpec(
    id: 'branco',
    name: 'Branco',
    brightness: Brightness.light,
    paper: Color(0xFFFFFFFF),
    paperShade: Color(0xFFF3F3F4),
    rule: Color(0xFFE6E6EA),
    margin: Color(0xFFF2B8B5),
    ink: Color(0xFF18181B),
    redInk: Color(0xFFDC2626),
    pencil: Color(0xFF71717A),
    greenInk: Color(0xFF15803D),
    sticky: Color(0xFFFEF3C7),
    accent: Color(0xFF4F46E5),
  ),
  // ---- escuros ----
  PaperSpec(
    id: 'noite',
    name: 'Noite',
    brightness: Brightness.dark,
    paper: Color(0xFF1F1D19),
    paperShade: Color(0xFF2A2722),
    rule: Color(0xFF333D45),
    margin: Color(0xFF7E433B),
    ink: Color(0xFFE9E2D0),
    redInk: Color(0xFFF08A7A),
    pencil: Color(0xFFA39E91),
    greenInk: Color(0xFF85C9A2),
    sticky: Color(0xFF4A4126),
    accent: Color(0xFF85C9A2),
  ),
  PaperSpec(
    id: 'grafite',
    name: 'Grafite',
    brightness: Brightness.dark,
    paper: Color(0xFF1A1A1D),
    paperShade: Color(0xFF111113),
    rule: Color(0xFF2A2A2F),
    margin: Color(0xFF5B2B2B),
    ink: Color(0xFFEDEDEF),
    redInk: Color(0xFFFF7A7A),
    pencil: Color(0xFF8B8B94),
    greenInk: Color(0xFF5EE39A),
    sticky: Color(0xFF3A351C),
    accent: Color(0xFFFF6363),
  ),
  PaperSpec(
    id: 'lousa',
    name: 'Lousa',
    brightness: Brightness.dark,
    paper: Color(0xFF1F2B26),
    paperShade: Color(0xFF17211D),
    rule: Color(0xFF2E3D36),
    margin: Color(0xFF6B3A34),
    ink: Color(0xFFE8EFE9),
    redInk: Color(0xFFF2A08F),
    pencil: Color(0xFF9BB0A5),
    greenInk: Color(0xFF9AD9B0),
    sticky: Color(0xFF4A4528),
    accent: Color(0xFF9AD9B0),
  ),
  PaperSpec(
    id: 'meianoite',
    name: 'Meia-noite',
    brightness: Brightness.dark,
    paper: Color(0xFF151C2E),
    paperShade: Color(0xFF0E1423),
    rule: Color(0xFF23304B),
    margin: Color(0xFF5A3046),
    ink: Color(0xFFE3E8F5),
    redInk: Color(0xFFFF8A80),
    pencil: Color(0xFF8E9BB8),
    greenInk: Color(0xFF7FD3A8),
    sticky: Color(0xFF3B3A2A),
    accent: Color(0xFF8AB4FF),
  ),
];

PaperSpec specById(String id) => paperSpecs.firstWhere((s) => s.id == id, orElse: () => paperSpecs.first);

/// Cor da caneta (a tinta dos textos). "folha" = a cor que vem com o papel.
class InkOption {
  const InkOption(this.id, this.name, this.light, this.dark);
  final String id, name;
  final Color? light, dark;
}

const inkOptions = [
  InkOption('folha', 'Da folha', null, null),
  InkOption('azul', 'Azul', Color(0xFF1E3A8A), Color(0xFFBFD3FF)),
  InkOption('preta', 'Preta', Color(0xFF141414), Color(0xFFF2F2F2)),
  InkOption('verde', 'Verde', Color(0xFF14532D), Color(0xFFB7EBCB)),
  InkOption('vinho', 'Vinho', Color(0xFF6B1D2A), Color(0xFFF3C2CB)),
  InkOption('roxo', 'Roxo', Color(0xFF4C1D95), Color(0xFFD9C8FF)),
];

enum Ruling { pautada, quadriculada, pontilhada, lisa }

const rulingNames = {
  Ruling.pautada: 'Pautada',
  Ruling.quadriculada: 'Quadriculada',
  Ruling.pontilhada: 'Pontilhada',
  Ruling.lisa: 'Lisa',
};
