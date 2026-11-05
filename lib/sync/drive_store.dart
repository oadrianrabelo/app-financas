// Arquivos de sincronização na pasta OCULTA do app no Google Drive
// (appDataFolder): não aparece no Drive de vocês e o app só enxerga o que ele
// mesmo criou (permissão drive.appdata, a mais restrita que existe).
import 'dart:async';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'remote_store.dart';

const driveScope = drive.DriveApi.driveAppdataScope;

class DriveStore implements RemoteStore {
  DriveStore(http.Client authedClient) : _api = drive.DriveApi(authedClient);

  final drive.DriveApi _api;
  final Map<String, String> _ids = {}; // nome -> id no Drive

  @override
  Future<List<RemoteFile>> list() async {
    final out = <RemoteFile>[];
    String? page;
    do {
      final res = await _api.files.list(
        spaces: 'appDataFolder',
        $fields: 'nextPageToken, files(id, name, modifiedTime)',
        pageSize: 100,
        pageToken: page,
      );
      for (final f in res.files ?? const <drive.File>[]) {
        _ids[f.name!] = f.id!;
        out.add(RemoteFile(f.name!, f.modifiedTime ?? DateTime(0)));
      }
      page = res.nextPageToken;
    } while (page != null);
    return out;
  }

  @override
  Future<List<int>?> read(String name) async {
    if (!_ids.containsKey(name)) await list();
    final id = _ids[name];
    if (id == null) return null;
    final media = await _api.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  @override
  Future<void> write(String name, List<int> bytes) async {
    if (!_ids.containsKey(name)) await list();
    final media = drive.Media(Stream.value(bytes), bytes.length, contentType: 'application/octet-stream');
    final id = _ids[name];
    if (id != null) {
      await _api.files.update(drive.File(), id, uploadMedia: media);
    } else {
      final created = await _api.files.create(
        drive.File(name: name, parents: ['appDataFolder']),
        uploadMedia: media,
        $fields: 'id',
      );
      _ids[name] = created.id!;
    }
  }
}
