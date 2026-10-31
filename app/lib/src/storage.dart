import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

/// This application uses its OWN SQLite storage; it does not touch website data.
class AppStorage {
  late final Database db;
  final String api;
  final Map<int, Future<String>> _activeDownloads = {};
  AppStorage(this.api);

  Future<void> open() async {
    final dir = await getDatabasesPath();
    db = await openDatabase(p.join(dir,'mauri_study_v1.sqlite'),version:1,
      onCreate:(d,v) async {
        await d.execute('CREATE TABLE catalog(id INTEGER PRIMARY KEY, payload TEXT NOT NULL, synced_at TEXT NOT NULL)');
        await d.execute('CREATE TABLE downloads(id INTEGER PRIMARY KEY, local_path TEXT NOT NULL, saved_at TEXT NOT NULL)');
      });
  }

  Future<Catalog?> cachedCatalog() async {
    final rows = await db.query('catalog',where:'id=?',whereArgs:[1],limit:1);
    if (rows.isEmpty) return null;
    return Catalog.fromMap(Map<String,dynamic>.from(jsonDecode(rows.first['payload']! as String) as Map));
  }

  /// Refresh taxonomy and read all published files using bounded pagination.
  /// Large libraries must not be loaded by the API in one unbounded response.
  Future<Catalog> sync() async {
    final response = await http.get(Uri.parse('$api/v1/catalog')).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) throw Exception('API HTTP ${response.statusCode}');
    final map = Map<String,dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)) as Map);

    final all = <dynamic>[];
    var cursor = 0;
    // At most 100,000 files per sync; extend with background incremental sync later.
    for (var page = 0; page < 1000; page++) {
      final uri = Uri.parse('$api/v1/resources').replace(queryParameters: {
        'limit': '100', 'after': cursor.toString(),
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) throw Exception('Catalog page HTTP ${r.statusCode}');
      final chunk = Map<String,dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);
      final items = chunk['resources'] as List<dynamic>? ?? const [];
      if (items.isEmpty) break;
      all.addAll(items);
      final next = (chunk['next_after'] as num?)?.toInt();
      if (next == null || next <= cursor) throw Exception('Invalid catalog pagination');
      cursor = next;
      if (items.length < 100) break;
      if (page == 999) throw Exception('Catalog exceeds current synchronization limit');
    }
    map['resources'] = all;
    map['truncated'] = false;
    final catalog = Catalog.fromMap(map);
    await db.insert('catalog',{
      'id':1, 'payload':jsonEncode(map), 'synced_at':DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm:ConflictAlgorithm.replace);
    return catalog;
  }

  Future<Map<int,String>> downloaded() async {
    final rows = await db.query('downloads');
    final valid = <int,String>{};
    for (final r in rows) {
      final id = r['id'] as int;
      final path = r['local_path']! as String;
      if (await File(path).exists()) valid[id] = path;
      else await db.delete('downloads',where:'id=?',whereArgs:[id]);
    }
    return valid;
  }

  /// Stream a file to disk without holding it in RAM; resume a partial download.
  Future<String> download(Resource resource,{void Function(int,int)? onProgress}) async {
    final active = _activeDownloads[resource.id];
    if (active != null) return active;
    final task = _download(resource,onProgress:onProgress);
    _activeDownloads[resource.id] = task;
    try {
      return await task;
    } finally {
      _activeDownloads.remove(resource.id);
    }
  }

  Future<String> _download(Resource resource,{void Function(int,int)? onProgress}) async {
    if (resource.size <= 0 || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(resource.sha256)) {
      throw Exception('Missing file integrity metadata');
    }
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path,'pdfs'));
    await dir.create(recursive:true);
    // Content-versioned paths prevent resuming bytes from a replaced PDF.
    final finalPath = p.join(dir.path,'${resource.id}-${resource.sha256.toLowerCase()}.pdf');
    final target = File(finalPath);
    if (await target.exists()) {
      final digest = (await sha256.bind(target.openRead()).first).toString();
      if (await target.length() == resource.size && digest == resource.sha256.toLowerCase()) {
        await _saveDownload(resource.id,finalPath);
        return finalPath;
      }
      await target.delete();
    }
    final temp = File('$finalPath.part');
    int existing = await temp.exists() ? await temp.length() : 0;
    if (resource.size > 0 && existing >= resource.size) {
      await temp.delete(); existing = 0;
    }
    final client = http.Client();
    try {
      final req = http.Request('GET',Uri.parse('$api/v1/files/${resource.id}'));
      if (existing > 0) req.headers['Range'] = 'bytes=$existing-';
      final res = await client.send(req).timeout(const Duration(seconds:30));
      if (res.statusCode != 200 && res.statusCode != 206) {
        throw Exception('Download failed (${res.statusCode})');
      }
      if (existing > 0 && res.statusCode == 206) {
        final cr = res.headers['content-range'];
        if (cr == null || !cr.startsWith('bytes $existing-')) throw Exception('Invalid resume response');
      }
      final resume = existing > 0 && res.statusCode == 206;
      int received = resume ? existing : 0;
      final sink = await temp.open(mode:resume?FileMode.append:FileMode.write);
      try {
        await for (final chunk in res.stream.timeout(const Duration(seconds:30))) {
          if (received + chunk.length > resource.size) throw Exception('File exceeds catalog size');
          // Await disk writes so a slow device cannot accumulate the PDF in RAM.
          await sink.writeFrom(chunk);
          received += chunk.length;
          onProgress?.call(received,resource.size>0?resource.size:received);
        }
        await sink.flush();
      } finally { await sink.close(); }
      if (resource.size > 0 && received != resource.size) {
        throw Exception('File incomplete: $received/${resource.size}');
      }
      if (resource.sha256.isNotEmpty) {
        final actual = (await sha256.bind(temp.openRead()).first).toString();
        if (actual.toLowerCase()!=resource.sha256.toLowerCase()) {
          await temp.delete();
          throw Exception('SHA256 verification failed');
        }
      }
      await temp.rename(finalPath);
      await _saveDownload(resource.id,finalPath);
      return finalPath;
    } finally {client.close();}
  }

  Future<void> _saveDownload(int id,String path) => db.transaction((txn) async {
    final previous = await txn.query('downloads',where:'id=?',whereArgs:[id]);
    await txn.insert('downloads',{'id':id,'local_path':path,'saved_at':DateTime.now().toUtc().toIso8601String()},conflictAlgorithm:ConflictAlgorithm.replace);
    for (final row in previous) {
      final oldPath = row['local_path']! as String;
      if (oldPath != path && await File(oldPath).exists()) await File(oldPath).delete();
    }
  });

  Future<void> remove(int id) async {
    final rows=await db.query('downloads',where:'id=?',whereArgs:[id]);
    if (rows.isNotEmpty) {
      final file=File(rows.first['local_path']! as String);
      if (await file.exists()) await file.delete();
    }
    await db.delete('downloads',where:'id=?',whereArgs:[id]);
  }

  Future<void> dispose() => db.close();
}
