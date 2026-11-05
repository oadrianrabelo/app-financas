// Fontes embutidas no app (declaradas no pubspec.yaml, em assets/fonts/).
// Para adicionar uma: coloque o .ttf, declare no pubspec e inclua aqui.

const handFonts = ['Caveat', 'Kalam', 'Patrick Hand', 'Gochi Hand', 'Indie Flower'];
const monoFonts = ['JetBrains Mono', 'IBM Plex Mono', 'Courier Prime', 'Space Mono'];

const defaultHandFont = 'Caveat';
const defaultMonoFont = 'JetBrains Mono';

/// Cada letra de mão tem um "tamanho visual" diferente; isto equaliza.
double handScale(String family) => switch (family) {
  'Caveat' => 1.18,
  'Indie Flower' => 0.95,
  'Gochi Hand' => 1.02,
  _ => 1.0,
};
