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
  final String subjectId, titleAr, titleFr, kind, sha256;
  final int? examYear;
  final int size;
  Resource.fromMap(Map<String, dynamic> m)
      : id = (m['id'] as num).toInt(),
        subjectId = m['subject_id'].toString(),
        titleAr = (m['title_ar'] ?? '').toString(),
        titleFr = (m['title_fr'] ?? '').toString(),
        kind = (m['kind'] ?? 'lesson').toString(),
        sha256 = (m['sha256'] ?? '').toString(),
        examYear = (m['exam_year'] as num?)?.toInt(),
        size = (m['file_size'] as num?)?.toInt() ?? 0;

  String display(bool french) => french && titleFr.isNotEmpty ? titleFr : titleAr;
  String typeLabel(bool french) {
    const ar = {'lesson':'درس','exam':'امتحان','exercise':'تمرين','summary':'ملخص','book':'كتاب'};
    const fr = {'lesson':'Cours','exam':'Examen','exercise':'Exercice','summary':'Résumé','book':'Livre'};
    return (french ? fr : ar)[kind] ?? kind;
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
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
