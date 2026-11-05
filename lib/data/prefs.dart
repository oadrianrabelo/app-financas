import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/tithe.dart';
import '../ui/theme/fonts.dart';
import 'database.dart';

/// Preferências deste aparelho, guardadas na tabela `settings`.
class Prefs extends ChangeNotifier {
  Prefs(this._db) {
    _sub = _db.watchSettings().listen((v) {
      _values = v;
      notifyListeners();
    });
  }

  final AppDatabase _db;
  late final StreamSubscription<void> _sub;
  Map<String, String> _values = {};

  int _int(String k, int d) => int.tryParse(_values[k] ?? '') ?? d;
  String _str(String k, String d, [List<String>? allowed]) {
    final v = _values[k];
    return v != null && (allowed == null || allowed.contains(v)) ? v : d;
  }

  int get titheBp => _int('tithe_bp', defaultTitheBp);
  int get offeringBp => _int('offering_bp', defaultOfferingBp);

  /// Se a oferta já foi definida (nos Ajustes ou ao separar).
  bool get hasOfferingBp => _values.containsKey('offering_bp');
  String get handFont => _str('hand_font', defaultHandFont, handFonts);
  String get monoFont => _str('mono_font', defaultMonoFont, monoFonts);
  ThemeMode get themeMode => ThemeMode.values.asNameMap()[_values['theme_mode']] ?? ThemeMode.system;

  /// De quem é este aparelho (pessoa padrão ao lançar).
  String get mePerson => _str('me_person', 'seed-pessoa-1');
  Future<void> setMePerson(String id) => _db.setSetting('me_person', id);

  Future<void> setTitheBp(int v) => _db.setSetting('tithe_bp', '$v');
  Future<void> setOfferingBp(int v) => _db.setSetting('offering_bp', '$v');
  Future<void> setHandFont(String v) => _db.setSetting('hand_font', v);
  Future<void> setMonoFont(String v) => _db.setSetting('mono_font', v);
  Future<void> setThemeMode(ThemeMode v) => _db.setSetting('theme_mode', v.name);

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
