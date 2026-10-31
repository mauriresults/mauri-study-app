import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mauri_study/src/models.dart';
import 'package:mauri_study/src/storage.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll((){sqfliteFfiInit();databaseFactory=databaseFactoryFfi;});
  test('upgrading existing offline storage preserves catalog and downloads and persists user settings',() async {
    final temporary=await Directory.systemTemp.createTemp('mauri-student-migration-');
    final location=p.join(temporary.path,'library.sqlite');
    var store=AppStorage('https://example.invalid',databasePath:location);
    addTearDown(() async {await store.dispose();await temporary.delete(recursive:true);});
    final legacy=await databaseFactoryFfi.openDatabase(location,options:OpenDatabaseOptions(version:1,onCreate:(database,version) async {
      await database.execute('CREATE TABLE catalog(id INTEGER PRIMARY KEY,payload TEXT NOT NULL,synced_at TEXT NOT NULL)');
      await database.execute('CREATE TABLE downloads(id INTEGER PRIMARY KEY,local_path TEXT NOT NULL,saved_at TEXT NOT NULL)');
    }));
    await legacy.insert('catalog',{'id':1,'payload':jsonEncode({'resources':[{'id':7,'subject_id':'math','title_ar':'ملف محفوظ','kind':'lesson'}]}),'synced_at':'2026-10-31'});
    await legacy.insert('downloads',{'id':7,'local_path':'existing.pdf','saved_at':'2026-10-31'});
    await legacy.close();
    await store.open();
    expect((await store.cachedCatalog())!.resources.single.id,7);
    expect((await store.db.query('downloads')).single['local_path'],'existing.pdf');
    await store.savePreferences(const UserPreferences(french:true,theme:'dark'));
    await store.setFavorite(7,true);
    await store.dispose();
    store=AppStorage('https://example.invalid',databasePath:location);
    await store.open();
    expect((await store.preferences()).french,isTrue);
    expect((await store.preferences()).theme,'dark');
    expect(await store.favorites(),{7});
    expect((await store.cachedCatalog())!.resources.single.id,7);
    await store.setFavorite(7,false);
    expect(await store.favorites(),isEmpty);
  });
}
