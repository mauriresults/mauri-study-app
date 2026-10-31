class Node {
  final String id, ar, fr;
  final String? levelId, trackId;
  Node.fromMap(Map<String, dynamic> m)
      : id = m['id'].toString(),
        ar = (m['name_ar'] ?? '').toString(),
        fr = (m['name_fr'] ?? '').toString(),
        levelId = m['level_id']?.toString(),
        trackId = m['track_id']?.toString();

  String display(bool french) => french && fr.isNotEmpty ? fr : ar;
}

class Resource {
  final int id;
  final String subjectId, titleAr, titleFr, kind, sha256, sourceCategory, yearLabel;
  final int? examYear;
  final int size;
  Resource.fromMap(Map<String, dynamic> m)
      : id = (m['id'] as num).toInt(),
        subjectId = m['subject_id'].toString(),
        titleAr = (m['title_ar'] ?? '').toString(),
        titleFr = (m['title_fr'] ?? '').toString(),
        kind = (m['kind'] ?? 'lesson').toString(),
        sha256 = (m['sha256'] ?? '').toString(),
        sourceCategory = (m['source_category'] ?? '').toString(),
        yearLabel = (m['year_label'] ?? '').toString(),
        examYear = (m['exam_year'] as num?)?.toInt(),
        size = (m['file_size'] as num?)?.toInt() ?? 0;

  String display(bool french) => french && titleFr.isNotEmpty ? titleFr : titleAr;

  /// Keep corrections separate without changing old D1 kind values or
  /// invalidating existing downloads, bookmarks and offline catalog caches.
  String get browseKind {
    if (kind == 'book') return kind;
    final title = normalizeSearch('$titleAr $titleFr $sourceCategory');
    if (RegExp(r'corrig|solution|تصحيح|حلول|اجاب|الاجاب').hasMatch(title)) {
      return 'solution';
    }
    return kind;
  }

  String typeLabel(bool french) {
    const ar = {'lesson':'درس','exam':'امتحان','exercise':'تمرين','summary':'ملخص','book':'كتاب','solution':'تصحيح وحل'};
    const fr = {'lesson':'Cours','exam':'Examen','exercise':'Exercice','summary':'Résumé','book':'Livre','solution':'Corrigé'};
    return (french ? fr : ar)[browseKind] ?? browseKind;
  }
}

class Catalog {
  final List<Node> levels, tracks, subjects;
  final List<Resource> resources;
  const Catalog({required this.levels,required this.tracks,required this.subjects,required this.resources});

  factory Catalog.fromMap(Map<String, dynamic> m) {
    List<Map<String, dynamic>> records(String key) =>
        (m[key] as List<dynamic>? ?? const []).map((e) => Map<String,dynamic>.from(e as Map)).toList();
    return Catalog(
      levels: records('levels').map(Node.fromMap).toList(),
      tracks: records('tracks').map(Node.fromMap).toList(),
      subjects: records('subjects').map(Node.fromMap).toList(),
      resources: records('resources').map(Resource.fromMap).toList(),
    );
  }
}

String humanSize(int bytes) {
  if (bytes <= 0) return '—';
  if (bytes >= 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class UserPreferences {
  final bool french;
  final String theme;
  const UserPreferences({this.french=false,this.theme='system'});
  factory UserPreferences.fromMap(Map<String,String> values) => UserPreferences(
    french:values['language']=='fr',
    theme:const {'light','dark','system'}.contains(values['theme'])?values['theme']!:'system',
  );
  Map<String,String> toMap() => {'language':french?'fr':'ar','theme':theme};
  UserPreferences copyWith({bool? french,String? theme}) => UserPreferences(french:french??this.french,theme:theme??this.theme);
}

String normalizeSearch(String value) => value.toLowerCase()
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'),'')
    .replaceAll(RegExp('[أإآٱ]'),'ا')
    .replaceAll(RegExp('[éèêë]'),'e')
    .replaceAll(RegExp('[àâä]'),'a')
    .replaceAll(RegExp('[îï]'),'i')
    .replaceAll(RegExp('[ôö]'),'o')
    .replaceAll(RegExp('[ùûü]'),'u')
    .replaceAll('ç','c').trim();

List<Resource> filterResources(Catalog catalog,{
  String? levelId,String? trackId,String? subjectId,String section='all',
  int? year,String query='',Set<int>? allowedIds,
}) {
  final tracks = catalog.tracks.where((node)=>levelId==null||node.levelId==levelId).map((node)=>node.id).toSet();
  final subjects = catalog.subjects.where((node)=>(trackId==null||node.trackId==trackId)&&tracks.contains(node.trackId)).map((node)=>node.id).toSet();
  final words = normalizeSearch(query).split(RegExp(r'\s+')).where((word)=>word.isNotEmpty).toList();
  final subjectsById = {for(final node in catalog.subjects) node.id:node};
  final tracksById = {for(final node in catalog.tracks) node.id:node};
  final levelsById = {for(final node in catalog.levels) node.id:node};
  final result = catalog.resources.where((resource){
    if (allowedIds!=null&&!allowedIds.contains(resource.id)) return false;
    if (subjectId!=null&&resource.subjectId!=subjectId) return false;
    if ((levelId!=null||trackId!=null)&&!subjects.contains(resource.subjectId)) return false;
    if (year!=null&&resource.examYear!=year) return false;
    if (section=='practice'&&!const {'exercise','summary'}.contains(resource.browseKind)) return false;
    if (section!='all'&&section!='practice'&&resource.browseKind!=section) return false;
    final subjectNode=subjectsById[resource.subjectId];
    final trackNode=tracksById[subjectNode?.trackId];
    final levelNode=levelsById[trackNode?.levelId];
    final haystack = normalizeSearch('${resource.titleAr} ${resource.titleFr} ${resource.examYear??''} '
      '${subjectNode?.ar??''} ${subjectNode?.fr??''} '
      '${trackNode?.ar??''} ${trackNode?.fr??''} '
      '${levelNode?.ar??''} ${levelNode?.fr??''}');
    return words.every(haystack.contains);
  }).toList();
  result.sort((a,b){
    if (section=='exam'||section=='solution') {
      final years = (b.examYear??0).compareTo(a.examYear??0);
      if (years!=0) return years;
    }
    return b.id.compareTo(a.id);
  });
  return result;
}
