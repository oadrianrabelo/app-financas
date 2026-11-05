import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/app_data.dart';
import 'data/database.dart';
import 'updates/updater.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  final db = AppDatabase();
  final data = AppData(db);
  final updater = Updater();
  // Procura atualização ao abrir, sem atrapalhar (erros ficam só na tela de Ajustes).
  updater.check();

  runApp(AppScope(db: db, data: data, updater: updater, child: const TostaoApp()));
}
