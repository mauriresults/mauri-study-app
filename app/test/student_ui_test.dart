import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mauri_study/main.dart';
import 'package:mauri_study/src/models.dart';
import 'package:mauri_study/src/storage.dart';

class PreviewStore extends AppStorage {
  UserPreferences settings=const UserPreferences();
  final bookmarks=<int>{};
  PreviewStore():super('https://example.invalid');
  @override Future<void> open() async {}
  @override Future<void> dispose() async {}
  @override Future<UserPreferences> preferences() async=>settings;
  @override Future<void> savePreferences(UserPreferences value) async {settings=value;}
  @override Future<Set<int>> favorites() async=>Set.of(bookmarks);
  @override Future<void> setFavorite(int id,bool value) async {if(value){bookmarks.add(id);}else{bookmarks.remove(id);}}
  @override Future<Map<int,String>> downloaded() async=>{};
  @override Future<int> storageBytes() async=>0;
  @override Future<Catalog?> cachedCatalog() async=>Catalog.fromMap({
    'levels':[{'id':'bac','name_ar':'البكالوريا','name_fr':'Baccalauréat'}],
    'tracks':[{'id':'d','level_id':'bac','name_ar':'العلوم الطبيعية','name_fr':'Sciences naturelles'}],
    'subjects':[{'id':'math','track_id':'d','name_ar':'الرياضيات','name_fr':'Mathématiques'}],
    'resources':[
      {'id':1,'subject_id':'math','title_ar':'درس الدوال','title_fr':'Cours de fonctions','kind':'lesson','file_size':2048},
      {'id':2,'subject_id':'math','title_ar':'امتحان الرياضيات','title_fr':'Examen de mathématiques','kind':'exam','exam_year':2025,'file_size':4096},
      {'id':3,'subject_id':'math','title_ar':'تمارين المراجعة','title_fr':'Exercices de révision','kind':'exercise','file_size':2048},
    ],
  });
}

Future<void> launch(WidgetTester tester,PreviewStore store) async {
  tester.view.physicalSize=const Size(320,720);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MauriStudyApp(storage:store,syncOnStart:false));
  await tester.pumpAndSettle();
}

void main(){
  testWidgets('Arabic home and library fit a narrow phone', (tester) async {
    await launch(tester,PreviewStore());
    expect(find.text('Mauri student'),findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(Scaffold).first)),TextDirection.rtl);
    expect(tester.takeException(),isNull);
    await tester.tap(find.byKey(const ValueKey('nav-library')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-field')),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.tap(find.byKey(const ValueKey('filter-button')));
    await tester.pumpAndSettle();
    expect(find.text('اختر ما يناسب دراستك'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('language switches the full application to French LTR and persists', (tester) async {
    final store=PreviewStore();
    await launch(tester,store);
    await tester.tap(find.byKey(const ValueKey('language-toggle')));
    await tester.pumpAndSettle();
    expect(store.settings.french,isTrue);
    expect(Directionality.of(tester.element(find.byType(Scaffold).first)),TextDirection.ltr);
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Langue de l’application'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('bookmarks are saved and appear in My Library without downloading', (tester) async {
    final store=PreviewStore();
    await launch(tester,store);
    await tester.tap(find.byKey(const ValueKey('nav-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip,'دروس'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-1')));
    await tester.pumpAndSettle();
    expect(store.bookmarks,{1});
    await tester.tap(find.byKey(const ValueKey('nav-saved')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المفضلة'));
    await tester.pumpAndSettle();
    expect(find.text('درس الدوال'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('theme settings are persisted', (tester) async {
    final store=PreviewStore();
    await launch(tester,store);
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('theme-dark')));
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    expect(store.settings.theme,'dark');
    expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness,Brightness.dark);
    expect(tester.takeException(),isNull);
  });
}
