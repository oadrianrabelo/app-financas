// Atualização automática a partir das Releases do GitHub.
//
// Fluxo: ao abrir, o app baixa o latest.json (+ .sig), confere a assinatura,
// vê se a versão é mais nova e já baixa o instalador em segundo plano.
// Aí mostra "Reiniciar para atualizar":
//  - Windows: roda o instalador em modo silencioso; ele reabre o app.
//  - Linux (AppImage): troca o arquivo .AppImage e reabre.
//  - Android: abre o instalador do sistema (o Android exige um toque).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'manifest.dart';
import 'update_key.dart';

const releasesRepo = 'oadrianrabelo/app-financas';
const _base = 'https://github.com/$releasesRepo/releases/latest/download';
const releasesPage = 'https://github.com/$releasesRepo/releases/latest';

enum UpdateStatus { idle, checking, upToDate, downloading, ready, permissionRequired, installing, unsupported, error }

String? get currentPlatformKey {
  if (Platform.isAndroid) return 'android';
  if (Platform.isWindows) return 'windows-x64';
  if (Platform.isLinux) return 'linux-x64';
  return null;
}

class Updater extends ChangeNotifier {
  Updater({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  static const _channel = MethodChannel('livro_caixa/updates');

  UpdateStatus status = UpdateStatus.idle;
  UpdateManifest? available;
  double? progress; // 0..1 durante o download
  String? error;
  String currentVersion = '';
  File? _downloaded;

  bool get enabled => updatePublicKey.isNotEmpty && currentPlatformKey != null && !kDebugMode;

  void _set(UpdateStatus s, {String? err}) {
    status = s;
    error = err;
    notifyListeners();
  }

  /// Procura versão nova. Com [autoDownload], já baixa o instalador.
  Future<void> check({bool autoDownload = true}) async {
    currentVersion = (await PackageInfo.fromPlatform()).version;
    if (!enabled) return _set(UpdateStatus.unsupported);
    if (status == UpdateStatus.downloading || status == UpdateStatus.ready) return;
    _set(UpdateStatus.checking);
    try {
      final res = await _http.get(Uri.parse('$_base/latest.json'));
      if (res.statusCode == 404) return _set(UpdateStatus.upToDate); // nenhuma release ainda
      if (res.statusCode != 200) throw HttpException('GitHub respondeu ${res.statusCode}');
      final sig = await _http.get(Uri.parse('$_base/latest.json.sig'));
      if (sig.statusCode != 200 || !await verifyManifest(res.bodyBytes, sig.body, updatePublicKey)) {
        throw const FormatException('Assinatura da atualização inválida.');
      }
      final manifest = UpdateManifest.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
      if (compareVersions(manifest.version, currentVersion) <= 0 || manifest.platforms[currentPlatformKey] == null) {
        return _set(UpdateStatus.upToDate);
      }
      available = manifest;
      if (autoDownload) await download();
    } catch (e) {
      _set(UpdateStatus.error, err: '$e');
    }
  }

  Future<void> download() async {
    final asset = available!.platforms[currentPlatformKey]!;
    _set(UpdateStatus.downloading);
    progress = 0;
    final res = await _http.send(http.Request('GET', Uri.parse(asset.url)));
    if (res.statusCode != 200) throw HttpException('Download falhou (${res.statusCode})');
    final total = res.contentLength ?? 0;
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in res.stream) {
      bytes.add(chunk);
      if (total > 0) {
        progress = bytes.length / total;
        notifyListeners();
      }
    }
    final data = bytes.takeBytes();
    if (await sha256Hex(data) != asset.sha256) throw const FormatException('Arquivo baixado está corrompido.');

    final dir = await getApplicationCacheDirectory();
    final file = File('${dir.path}/updates/${Uri.parse(asset.url).pathSegments.last}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data, flush: true);
    _downloaded = file;
    progress = null;
    _set(UpdateStatus.ready);
  }

  /// Instala o que foi baixado. No desktop o app fecha e reabre sozinho.
  Future<void> install() async {
    final file = _downloaded;
    if (file == null) return;
    try {
      if (Platform.isAndroid) {
        if (!(await _channel.invokeMethod<bool>('canInstall') ?? false)) {
          await _channel.invokeMethod('openInstallSettings');
          return _set(UpdateStatus.permissionRequired);
        }
        _set(UpdateStatus.installing);
        await _channel.invokeMethod('installApk', {'path': file.path});
        _set(UpdateStatus.ready); // se a pessoa cancelar, dá para tentar de novo
      } else if (Platform.isWindows) {
        _set(UpdateStatus.installing);
        // O instalador fecha o app, instala sem perguntar nada e o reabre.
        await Process.start(file.path, [
          '/VERYSILENT',
          '/SUPPRESSMSGBOXES',
          '/NORESTART',
        ], mode: ProcessStartMode.detached);
        exit(0);
      } else if (Platform.isLinux) {
        final appImage = Platform.environment['APPIMAGE'];
        if (appImage == null) {
          return _set(
            UpdateStatus.unsupported,
            err: 'Instalado sem ser AppImage: baixe a versão nova em $releasesPage',
          );
        }
        _set(UpdateStatus.installing);
        final tmp = '$appImage.new';
        await file.copy(tmp);
        await Process.run('chmod', ['+x', tmp]);
        await File(tmp).rename(appImage); // no Linux dá para trocar o arquivo em uso
        await Process.start(appImage, const [], mode: ProcessStartMode.detached);
        exit(0);
      }
    } catch (e) {
      _set(UpdateStatus.error, err: '$e');
    }
  }
}
