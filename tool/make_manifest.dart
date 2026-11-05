// Usado pelo CI: monta e assina o latest.json da release.
//   UPDATE_SIGNING_KEY=... dart run tool/make_manifest.dart \
//     --version 0.2.0 --notes "https://..." --base-url https://github.com/.../download/v0.2.0 \
//     --out dist android=dist/LivroCaixa_0.2.0_android.apk windows-x64=dist/... linux-x64=dist/...
import 'dart:convert';
import 'dart:io';

import 'package:livro_caixa/updates/manifest.dart';

Future<void> main(List<String> args) async {
  final opts = <String, String>{};
  final files = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      opts[args[i].substring(2)] = args[++i];
    } else {
      final [platform, path] = args[i].split('=');
      files[platform] = path;
    }
  }
  final key = Platform.environment['UPDATE_SIGNING_KEY'] ?? '';
  if (key.isEmpty) {
    stderr.writeln('UPDATE_SIGNING_KEY vazia.');
    exit(1);
  }

  final manifest = UpdateManifest(
    version: opts['version']!,
    notes: opts['notes'] ?? '',
    pubDate: DateTime.now().toUtc().toIso8601String(),
    platforms: {
      for (final MapEntry(key: platform, value: path) in files.entries)
        platform: UpdateAsset(
          url: '${opts['base-url']}/${path.split('/').last}',
          sha256: await sha256Hex(await File(path).readAsBytes()),
        ),
    },
  );
  final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest.toJson()));
  final out = opts['out'] ?? '.';
  await File('$out/latest.json').writeAsBytes(bytes);
  await File('$out/latest.json.sig').writeAsString(await signManifest(bytes, key));
  stdout.writeln('latest.json assinado com ${files.length} plataformas.');
}
