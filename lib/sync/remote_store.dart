// Onde os arquivos de sincronização ficam. O app usa o Google Drive
// (drive_store.dart); os testes usam a versão em memória.

class RemoteFile {
  const RemoteFile(this.name, this.modified);
  final String name;
  final DateTime modified;
}

abstract class RemoteStore {
  Future<List<RemoteFile>> list();
  Future<List<int>?> read(String name);
  Future<void> write(String name, List<int> bytes);
}

class MemoryStore implements RemoteStore {
  final Map<String, (DateTime, List<int>)> files = {};

  @override
  Future<List<RemoteFile>> list() async => [for (final e in files.entries) RemoteFile(e.key, e.value.$1)];

  @override
  Future<List<int>?> read(String name) async => files[name]?.$2;

  @override
  Future<void> write(String name, List<int> bytes) async => files[name] = (DateTime.now(), List.of(bytes));
}
