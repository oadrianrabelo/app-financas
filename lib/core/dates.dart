// Datas guardadas como texto "AAAA-MM-DD" (sem fuso horário = sem dor de cabeça).
import 'package:intl/intl.dart';

String _pad(int n) => n.toString().padLeft(2, '0');

String toIsoDate(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

String today() => toIsoDate(DateTime.now());

/// "2026-11" a partir de "2026-11-05"
String monthOf(String date) => date.substring(0, 7);

/// Soma (ou subtrai) meses de um "AAAA-MM"
String addMonths(String month, int delta) {
  final [y, m] = month.split('-').map(int.parse).toList();
  final d = DateTime(y, m + delta);
  return '${d.year}-${_pad(d.month)}';
}

String monthLabel(String month) {
  final [y, m] = month.split('-').map(int.parse).toList();
  final label = DateFormat.yMMMM('pt_BR').format(DateTime(y, m));
  return label[0].toUpperCase() + label.substring(1);
}

/// "2026-11-05" -> "05/11/2026"
String formatDate(String date) {
  final [y, m, d] = date.split('-');
  return '$d/$m/$y';
}
