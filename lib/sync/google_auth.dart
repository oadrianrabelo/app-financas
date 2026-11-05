// Entrar com a conta Google e conseguir um acesso ao Drive.
//
// - Android: login nativo do Google (google_sign_in), pede só a permissão da
//   pasta oculta do app.
// - Windows/Linux: abre o navegador, você autoriza, e o Google devolve para o
//   app (endereço local 127.0.0.1). O acesso fica guardado neste aparelho.
//
// Os IDs vêm do Google Cloud (veja o README, "Sincronização") e entram no
// build por --dart-define; sem eles a sincronização fica desligada.
import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart' as gauth;
import 'package:http/http.dart' as http;

import '../data/database.dart';
import 'drive_store.dart';

const _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const _desktopClientId = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
const _desktopClientSecret = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

abstract class GoogleAuth {
  static GoogleAuth create(AppDatabase db) => Platform.isAndroid ? _AndroidAuth() : _DesktopAuth(db);

  /// Se este build sabe falar com o Google (IDs configurados).
  bool get configured;

  /// Cliente HTTP autorizado. Com [interactive], pode abrir a tela de login.
  /// Devolve null se precisar de login e [interactive] for false.
  Future<http.Client?> client({bool interactive = false});

  Future<void> signOut();
}

class _AndroidAuth implements GoogleAuth {
  bool _ready = false;

  @override
  bool get configured => _webClientId.isNotEmpty;

  Future<void> _init() async {
    if (_ready) return;
    await GoogleSignIn.instance.initialize(serverClientId: _webClientId.isEmpty ? null : _webClientId);
    _ready = true;
  }

  @override
  Future<http.Client?> client({bool interactive = false}) async {
    await _init();
    final authz = GoogleSignIn.instance.authorizationClient;
    final token =
        await authz.authorizationForScopes([driveScope]) ??
        (interactive ? await authz.authorizeScopes([driveScope]) : null);
    if (token == null) return null;
    final creds = gauth.AccessCredentials(
      gauth.AccessToken('Bearer', token.accessToken, DateTime.now().toUtc().add(const Duration(minutes: 50))),
      null,
      [driveScope],
    );
    return gauth.authenticatedClient(http.Client(), creds);
  }

  @override
  Future<void> signOut() async {
    await _init();
    await GoogleSignIn.instance.disconnect();
  }
}

class _DesktopAuth implements GoogleAuth {
  _DesktopAuth(this._db);
  final AppDatabase _db;
  static const _key = 'google_credentials';

  gauth.ClientId get _id => gauth.ClientId(_desktopClientId, _desktopClientSecret);

  @override
  bool get configured => _desktopClientId.isNotEmpty && _desktopClientSecret.isNotEmpty;

  @override
  Future<http.Client?> client({bool interactive = false}) async {
    final saved = (await _db.watchSettings().first)[_key];
    gauth.AccessCredentials? creds;
    if (saved != null && saved.isNotEmpty) {
      creds = gauth.AccessCredentials.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    }
    if (creds == null || creds.refreshToken == null) {
      if (!interactive) return null;
      creds = await gauth.obtainAccessCredentialsViaUserConsent(_id, [driveScope], http.Client(), _openBrowser);
      await _save(creds);
    }
    final client = gauth.autoRefreshingClient(_id, creds, http.Client());
    client.credentialUpdates.listen(_save);
    return client;
  }

  Future<void> _save(gauth.AccessCredentials c) => _db.setSetting(_key, jsonEncode(c.toJson()));

  static Future<void> _openBrowser(String url) async {
    if (Platform.isWindows) {
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else {
      await Process.run('xdg-open', [url]);
    }
  }

  @override
  Future<void> signOut() => _db.setSetting(_key, '');
}
