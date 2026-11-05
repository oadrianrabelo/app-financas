// O "latest.json" de cada release: diz qual é a versão nova e onde baixar o
// instalador de cada plataforma. O arquivo é assinado (ed25519) no CI e o app
// só confia nele se a assinatura bater com a chave pública embutida.
// Cada instalador ainda tem o SHA-256 conferido depois do download.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class UpdateAsset {
  const UpdateAsset({required this.url, required this.sha256});
  final String url;
  final String sha256;

  factory UpdateAsset.fromJson(Map<String, dynamic> j) =>
      UpdateAsset(url: j['url'] as String, sha256: j['sha256'] as String);
  Map<String, dynamic> toJson() => {'url': url, 'sha256': sha256};
}

class UpdateManifest {
  const UpdateManifest({required this.version, required this.notes, required this.pubDate, required this.platforms});
  final String version;
  final String notes;
  final String pubDate;
  final Map<String, UpdateAsset> platforms; // 'android', 'windows-x64', 'linux-x64'

  factory UpdateManifest.fromJson(Map<String, dynamic> j) => UpdateManifest(
    version: j['version'] as String,
    notes: j['notes'] as String? ?? '',
    pubDate: j['pub_date'] as String? ?? '',
    platforms: {
      for (final MapEntry(:key, :value) in (j['platforms'] as Map<String, dynamic>).entries)
        key: UpdateAsset.fromJson(value as Map<String, dynamic>),
    },
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'notes': notes,
    'pub_date': pubDate,
    'platforms': {for (final e in platforms.entries) e.key: e.value.toJson()},
  };
}

final _ed25519 = Ed25519();

/// Confere a assinatura (base64) dos bytes exatos do latest.json.
Future<bool> verifyManifest(List<int> bytes, String signatureB64, String publicKeyB64) async {
  try {
    return await _ed25519.verify(
      bytes,
      signature: Signature(
        base64.decode(signatureB64.trim()),
        publicKey: SimplePublicKey(base64.decode(publicKeyB64), type: KeyPairType.ed25519),
      ),
    );
  } catch (_) {
    return false; // base64 inválido, tamanho errado etc.
  }
}

/// Assina os bytes do manifesto com a semente privada (base64, 32 bytes).
Future<String> signManifest(List<int> bytes, String privateSeedB64) async {
  final keyPair = await _ed25519.newKeyPairFromSeed(base64.decode(privateSeedB64.trim()));
  final sig = await _ed25519.sign(bytes, keyPair: keyPair);
  return base64.encode(sig.bytes);
}

Future<String> sha256Hex(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Compara "1.2.3" com "1.10.0" (ignora "v" e sufixos como "-previa.4").
int compareVersions(String a, String b) {
  List<int> parse(String v) =>
      v.replaceFirst(RegExp('^v'), '').split(RegExp('[-+]')).first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final pa = parse(a), pb = parse(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < pa.length ? pa[i] : 0) - (i < pb.length ? pb[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}
