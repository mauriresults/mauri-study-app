-- Independent educational app catalog. No connection to website data.
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS levels (
  id TEXT PRIMARY KEY,
  name_ar TEXT NOT NULL,
  name_fr TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS tracks (
  id TEXT PRIMARY KEY,
  level_id TEXT NOT NULL REFERENCES levels(id) ON DELETE RESTRICT,
  name_ar TEXT NOT NULL,
  name_fr TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS subjects (
  id TEXT PRIMARY KEY,
  track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE RESTRICT,
  name_ar TEXT NOT NULL,
  name_fr TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS resources (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT,
  title_ar TEXT NOT NULL,
  title_fr TEXT NOT NULL DEFAULT '',
  kind TEXT NOT NULL CHECK(kind IN ('lesson','exam','exercise','summary','book')),
  exam_year INTEGER CHECK(exam_year BETWEEN 1990 AND 2100),
  object_key TEXT NOT NULL UNIQUE,
  file_size INTEGER NOT NULL DEFAULT 0 CHECK(file_size >= 0),
  sha256 TEXT NOT NULL DEFAULT '',
  published INTEGER NOT NULL DEFAULT 0 CHECK(published IN (0,1)),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_subjects_track ON subjects(track_id,sort_order);
CREATE INDEX IF NOT EXISTS idx_tracks_level ON tracks(level_id,sort_order);
CREATE INDEX IF NOT EXISTS idx_resources_subject ON resources(subject_id,published,id);
CREATE INDEX IF NOT EXISTS idx_resources_published_updated ON resources(published,updated_at);
-- Seed taxonomy only; no fictitious documents.
INSERT OR IGNORE INTO levels(id,name_ar,name_fr,sort_order) VALUES ('bac','البكالوريا','Baccalauréat',1);
INSERT OR IGNORE INTO tracks(id,level_id,name_ar,name_fr,sort_order) VALUES
 ('bac-d','bac','العلوم الطبيعية','Sciences naturelles',1),
 ('bac-c','bac','الرياضيات','Mathématiques',2),
 ('bac-lo','bac','الآداب الأصلية','Lettres originelles',3),
 ('bac-lm','bac','الآداب العصرية','Lettres modernes',4),
 ('bac-tmgm','bac','الشعبة التقنية','Technique',5);
INSERT OR IGNORE INTO subjects(id,track_id,name_ar,name_fr,sort_order) VALUES
 ('bac-d-math','bac-d','الرياضيات','Mathématiques',1),
 ('bac-d-phys','bac-d','الفيزياء','Physique',2),
 ('bac-d-svt','bac-d','العلوم الطبيعية','SVT',3),
 ('bac-c-math','bac-c','الرياضيات','Mathématiques',1),
 ('bac-c-phys','bac-c','الفيزياء','Physique',2);
