import 'dart:async';

import 'package:flutter/widgets.dart';

import '../updates/updater.dart';
import 'database.dart';

/// Mantém em memória as listas do banco e avisa as telas quando mudam.
/// Para um app pessoal (milhares de lançamentos) isso é mais que suficiente
/// e deixa as telas bem simples.
class AppData extends ChangeNotifier {
  AppData(this.db) {
    _subs = [
      db.watchAccounts().listen((v) => _set(() => accounts = v)),
      db.watchCategories().listen((v) => _set(() => categories = v)),
      db.watchAllEntries().listen((v) => _set(() => entries = v)),
    ];
  }

  final AppDatabase db;
  late final List<StreamSubscription<void>> _subs;

  List<Account> accounts = [];
  List<Category> categories = [];
  List<Entry> entries = [];

  Account? account(String? id) => accounts.where((a) => a.id == id).firstOrNull;
  Category? category(String? id) => categories.where((c) => c.id == id).firstOrNull;

  /// Lançamentos do mês ("AAAA-MM"), mais recentes primeiro.
  List<Entry> monthEntries(String month) =>
      entries.where((e) => e.date.startsWith(month)).toList()
        ..sort((a, b) => b.date.compareTo(a.date) != 0 ? b.date.compareTo(a.date) : b.createdAt.compareTo(a.createdAt));

  void _set(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Dá acesso ao banco, aos dados e ao atualizador em qualquer tela:
/// `AppScope.of(context).data`.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.db, required this.data, required this.updater, required super.child});

  final AppDatabase db;
  final AppData data;
  final Updater updater;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => false;
}
