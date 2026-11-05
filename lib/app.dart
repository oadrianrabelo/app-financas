import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_data.dart';
import 'ui/pages/accounts_page.dart';
import 'ui/pages/entries_page.dart';
import 'ui/pages/month_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/theme/paper.dart';
import 'ui/widgets/update_banner.dart';

const appName = 'Livro-Caixa';

class LivroCaixaApp extends StatelessWidget {
  const LivroCaixaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: paperTheme(Brightness.light, hand: prefs.handFont, mono: prefs.monoFont),
        darkTheme: paperTheme(Brightness.dark, hand: prefs.handFont, mono: prefs.monoFont),
        themeMode: prefs.themeMode,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Shell(),
      ),
    );
  }
}

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon, this.page);
  final String label;
  final IconData icon, selectedIcon;
  final Widget page;
}

const _destinations = [
  _Dest('Mês', Icons.menu_book_outlined, Icons.menu_book, MonthPage()),
  _Dest('Lançamentos', Icons.receipt_long_outlined, Icons.receipt_long, EntriesPage()),
  _Dest('Contas', Icons.account_balance_outlined, Icons.account_balance, AccountsPage()),
  _Dest('Ajustes', Icons.settings_outlined, Icons.settings, SettingsPage()),
];

/// Abas embaixo no celular; no computador, abas de fichário na lateral.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final p = Paper.of(context);
    final body = Column(
      children: [
        const UpdateBanner(),
        Expanded(
          child: IndexedStack(index: _index, children: [for (final d in _destinations) d.page]),
        ),
      ],
    );

    if (!wide) {
      return Scaffold(
        body: SafeArea(child: body),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 200,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
              child: Text(
                '📒 $appName',
                style: p.hand(30, color: p.redInk, weight: FontWeight.w700),
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
            ],
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
