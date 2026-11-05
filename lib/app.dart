import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ui/pages/accounts_page.dart';
import 'ui/pages/entries_page.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/widgets/update_banner.dart';

const appName = 'Livro-Caixa';
const _seed = Color(0xFF1F4D3A); // verde de livro contábil

class LivroCaixaApp extends StatelessWidget {
  const LivroCaixaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const Shell(),
    );
  }
}

ThemeData _theme(Brightness b) => ThemeData(
  colorSchemeSeed: _seed,
  brightness: b,
  cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 4)),
);

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon, this.page);
  final String label;
  final IconData icon, selectedIcon;
  final Widget page;
}

const _destinations = [
  _Dest('Início', Icons.home_outlined, Icons.home, HomePage()),
  _Dest('Lançamentos', Icons.receipt_long_outlined, Icons.receipt_long, EntriesPage()),
  _Dest('Contas', Icons.account_balance_outlined, Icons.account_balance, AccountsPage()),
  _Dest('Ajustes', Icons.settings_outlined, Icons.settings, SettingsPage()),
];

/// Menu embaixo no celular, na lateral no computador.
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
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Text(
                '📒 $appName',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
