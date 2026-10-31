-- Imported website catalog is private inventory, never exposed as downloadable until R2 verification.
ALTER TABLE resources ADD COLUMN source_category TEXT NOT NULL DEFAULT '';
ALTER TABLE resources ADD COLUMN year_label TEXT NOT NULL DEFAULT '';
CREATE TABLE IF NOT EXISTS site_source_files (
  drive_file_id TEXT PRIMARY KEY,
  original_title TEXT NOT NULL,
  level_id TEXT NOT NULL,
  track_id TEXT NOT NULL,
  subject_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  category TEXT NOT NULL,
  year_label TEXT NOT NULL DEFAULT '',
  exam_year INTEGER,
  advertised_size INTEGER NOT NULL DEFAULT 0,
  source_name TEXT NOT NULL DEFAULT '',
  state TEXT NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','imported','unavailable','duplicate','failed')),
  resource_id INTEGER REFERENCES resources(id) ON DELETE SET NULL,
  checked_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_site_source_state ON site_source_files(state,level_id,category);
CREATE INDEX IF NOT EXISTS idx_resources_category ON resources(published,source_category,exam_year);
