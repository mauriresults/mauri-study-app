import 'package:flutter_test/flutter_test.dart';
import 'package:mauri_study/src/models.dart';
void main(){
  test('catalog parses empty offline library',(){
    final c=Catalog.fromMap({'levels':[],'tracks':[],'subjects':[],'resources':[]});
    expect(c.resources,isEmpty);
  });
  test('resource labels keep year and size',(){
    final r=Resource.fromMap({'id':1,'subject_id':'bac-d-math','title_ar':'درس','title_fr':'Cours','kind':'lesson','file_size':2048,'exam_year':2025});
    expect(r.display(false),'درس');
    expect(r.display(true),'Cours');
    expect(r.examYear,2025);
    expect(humanSize(r.size),'2 KB');
  });
  test('search ignores Arabic diacritics and French accents',(){
    expect(normalizeSearch('إِمْتِحَان'),normalizeSearch('امتحان'));
    expect(normalizeSearch('Génétique'),normalizeSearch('genetique'));
  });
  test('saved preferences accept only supported themes',(){
    expect(UserPreferences.fromMap({'language':'fr','theme':'dark'}).french,isTrue);
    expect(UserPreferences.fromMap({'theme':'unexpected'}).theme,'system');
    expect(const UserPreferences().copyWith(french:true).toMap()['language'],'fr');
  });
  test('catalog filters respect level, track, year and saved IDs',(){
    final c=Catalog.fromMap({
      'levels':[{'id':'bac','name_ar':'البكالوريا'},{'id':'brevet','name_ar':'ابريفه'}],
      'tracks':[{'id':'d','level_id':'bac'},{'id':'b','level_id':'brevet'}],
      'subjects':[{'id':'math','track_id':'d'},{'id':'ar','track_id':'b'}],
      'resources':[
        {'id':1,'subject_id':'math','title_ar':'تمارين الرياضيات','title_fr':'Mathématiques','kind':'exercise'},
        {'id':2,'subject_id':'ar','title_ar':'امتحان','kind':'exam','exam_year':2025},
        {'id':3,'subject_id':'math','title_ar':'امتحان رياضيات','kind':'exam','exam_year':2024},
      ],
    });
    expect(filterResources(c,levelId:'bac').map((r)=>r.id),[3,1]);
    expect(filterResources(c,trackId:'b',year:2025).single.id,2);
    expect(filterResources(c,section:'practice',query:'mathematiques').single.id,1);
    expect(filterResources(c,allowedIds:{2}).single.id,2);
  });
}
