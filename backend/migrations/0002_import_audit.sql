-- Internal provenance only, not accessible through the public read-only API.
CREATE TABLE IF NOT EXISTS import_audit (
  drive_file_id TEXT PRIMARY KEY,
  resource_id INTEGER NOT NULL REFERENCES resources(id),
  original_filename TEXT NOT NULL,
  object_key TEXT UNIQUE NOT NULL,
  imported_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_import_audit_resource ON import_audit(resource_id);
