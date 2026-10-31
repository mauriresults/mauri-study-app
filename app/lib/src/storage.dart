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
  static const clientHeaders = {'User-Agent':'MauriStudent/0.2.0'};
  Database? _database;
  Database get db => _database ?? (throw StateError('Storage is not open'));
  bool _disposed = false;
  final String api;
  final String? databasePath;
  final Map<int, Future<String>> _activeDownloads = {};
  AppStorage(this.api,{this.databasePath});

  Future<void> open() async {
    final location = databasePath??p.join(await getDatabasesPath(),'mauri_study_v1.sqlite');
    final opened = await openDatabase(location,version:2,
      onCreate:(d,v) async {
        await d.execute('CREATE TABLE catalog(id INTEGER PRIMARY KEY, payload TEXT NOT NULL, synced_at TEXT NOT NULL)');
        await d.execute('CREATE TABLE downloads(id INTEGER PRIMARY KEY, local_path TEXT NOT NULL, saved_at TEXT NOT NULL)');
        await _createUserTables(d);
      },
      onUpgrade:(d,oldVersion,newVersion) async {
        if (oldVersion < 2) await _createUserTables(d);
      });
    if (_disposed) {
      await opened.close();
      throw StateError('Storage was disposed');
    }
    _database = opened;
  }

  static Future<void> _createUserTables(DatabaseExecutor database) async {
    await database.execute('CREATE TABLE IF NOT EXISTS favorites(resource_id INTEGER PRIMARY KEY)');
    await database.execute('CREATE TABLE IF NOT EXISTS preferences(setting_key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  }

  Future<UserPreferences> preferences() async {
    final rows = await db.query('preferences');
    return UserPreferences.fromMap({for (final row in rows) row['setting_key'] as String:row['value'] as String});
  }

  Future<void> savePreferences(UserPreferences preferences) async {
    final batch = db.batch();
    for (final entry in preferences.toMap().entries) {
      batch.insert('preferences',{'setting_key':entry.key,'value':entry.value},conflictAlgorithm:ConflictAlgorithm.replace);
    }
    await batch.commit(noResult:true);
  }

  Future<Set<int>> favorites() async => (await db.query('favorites')).map((row)=>row['resource_id'] as int).toSet();

  Future<void> setFavorite(int id,bool value) async {
    if (value) {
      await db.insert('favorites',{'resource_id':id},conflictAlgorithm:ConflictAlgorithm.ignore);
    } else {
      await db.delete('favorites',where:'resource_id=?',whereArgs:[id]);
    }
  }

  Future<int> storageBytes() async {
    final directory = Directory(p.join((await getApplicationDocumentsDirectory()).path,'pdfs'));
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final file in directory.list(followLinks:false)) {
      if (file is File) total += await file.length();
    }
    return total;
  }

  Future<void> clearDownloads() async {
    if (_activeDownloads.isNotEmpty) throw StateError('Downloads are active');
    final directory = Directory(p.join((await getApplicationDocumentsDirectory()).path,'pdfs'));
    if (await directory.exists()) {
      await for (final file in directory.list(followLinks:false)) {
        if (file is File && RegExp(r'^\d+(?:-[a-f0-9]{64})?\.pdf(?:\.part)?$').hasMatch(p.basename(file.path))) {
          await file.delete();
        }
      }
    }
    await db.delete('downloads');
  }

  Future<Catalog?> cachedCatalog() async {
    final rows = await db.query('catalog',where:'id=?',whereArgs:[1],limit:1);
    if (rows.isEmpty) return null;
    return Catalog.fromMap(Map<String,dynamic>.from(jsonDecode(rows.first['payload']! as String) as Map));
  }

  /// Refresh taxonomy and read all published files using bounded pagination.
  /// Large libraries must not be loaded by the API in one unbounded response.
  Future<Catalog> sync() async {
    final response = await http.get(Uri.parse('$api/v1/catalog?taxonomy_only=1'),headers:clientHeaders).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) throw Exception('API HTTP ${response.statusCode}');
    final map = Map<String,dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)) as Map);

    final all = <dynamic>[];
    var cursor = 0;
    // At most 100,000 files per sync; extend with background incremental sync later.
    for (var page = 0; page < 1000; page++) {
      final uri = Uri.parse('$api/v1/resources').replace(queryParameters: {
        'limit': '500', 'after': cursor.toString(),
      });
      final r = await http.get(uri,headers:clientHeaders).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) throw Exception('Catalog page HTTP ${r.statusCode}');
      final chunk = Map<String,dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);
      final items = chunk['resources'] as List<dynamic>? ?? const [];
      if (items.isEmpty) break;
      all.addAll(items);
      final next = (chunk['next_after'] as num?)?.toInt();
      if (next == null || next <= cursor) throw Exception('Invalid catalog pagination');
      cursor = next;
      if (items.length < 500) break;
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
      if (await File(path).exists()) {
        valid[id] = path;
      } else {
        await db.delete('downloads',where:'id=?',whereArgs:[id]);
      }
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
      req.headers.addAll(clientHeaders);
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

  Future<void> dispose() async {
    _disposed = true;
    final database = _database;
    _database = null;
    if (database != null && database.isOpen) await database.close();
  }
}
