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
}
