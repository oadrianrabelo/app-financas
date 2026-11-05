import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/updates/manifest.dart';

void main() {
  test('assinatura: aceita o original e recusa alterado', () async {
    final pair = await Ed25519().newKeyPair();
    final seed = base64.encode(await pair.extractPrivateKeyBytes());
    final pub = base64.encode((await pair.extractPublicKey()).bytes);

    final bytes = utf8.encode('{"version":"1.0.0"}');
    final sig = await signManifest(bytes, seed);
    expect(await verifyManifest(bytes, sig, pub), isTrue);
    expect(await verifyManifest(utf8.encode('{"version":"9.9.9"}'), sig, pub), isFalse);
    expect(await verifyManifest(bytes, 'lixo', pub), isFalse);
  });

  test('compareVersions', () {
    expect(compareVersions('1.10.0', '1.2.0'), 1);
    expect(compareVersions('v0.2.0', '0.2.0'), 0);
    expect(compareVersions('0.1.9', '0.2.0'), -1);
    expect(compareVersions('0.3.0-previa.4', '0.2.0'), 1);
  });

  test('sha256Hex', () async {
    expect(await sha256Hex(utf8.encode('abc')), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });
}
