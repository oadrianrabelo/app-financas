// Gera o par de chaves que assina as atualizações.
//   dart run tool/gen_keys.dart
// - Grava a chave pública em lib/updates/update_key.dart (vai para o Git).
// - Mostra a chave PRIVADA: coloque no secret UPDATE_SIGNING_KEY do GitHub e
//   guarde uma cópia num lugar seguro. NUNCA faça commit dela.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main() async {
  final keyFile = File('lib/updates/update_key.dart');
  final current = await keyFile.readAsString();
  if (!current.contains("updatePublicKey = ''") && !(Platform.environment['FORCE'] == '1')) {
    stderr.writeln(
      'Já existe uma chave pública. Trocar a chave impede os apps instalados de '
      'aceitarem novas versões. Se tem certeza, rode com FORCE=1.',
    );
    exit(1);
  }
  final pair = await Ed25519().newKeyPair();
  final seed = base64.encode(await pair.extractPrivateKeyBytes());
  final pub = base64.encode((await pair.extractPublicKey()).bytes);
  await keyFile.writeAsString(current.replaceFirst(RegExp(r"updatePublicKey = '[^']*'"), "updatePublicKey = '$pub'"));

  stdout.writeln('Chave pública gravada em ${keyFile.path}.');
  stdout.writeln('\nChave PRIVADA (secret UPDATE_SIGNING_KEY):\n\n$seed\n');
}
