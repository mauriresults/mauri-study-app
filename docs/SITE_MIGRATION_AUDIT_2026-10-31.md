# Mauri Student — independent library migration audit

Checked: 2026-10-31 UTC. Source of truth: LIVE app Cloudflare D1 `mauri-study-app-db` and R2 `mauri-study-files`; the website production database, storage and deployment were not modified.

## Verified app storage

| Metric | Live result |
|---|---:|
| Published resource rows | **72** |
| R2 object count | **72** |
| R2 bytes | **29,650,709** |
| D1 published bytes | **29,650,709** |
| Distinct resource SHA256 values | **72** |
| New published PDFs imported in this session | **22** |
| Duplicate source records found (no redundant upload) | **4** |

These totals independently corroborate **counts and sizes**, not a full byte-for-byte audit of every preexisting R2 object. The new dedicated importer verifies R2 readback SHA256 before marking any future file published.

## Source inventory already indexed in app D1

| Source-file state | Rows | Advertised size |
|---|---:|---:|
| Imported with confirmed source link | 41 | 5,654,769 B |
| Duplicate of a published SHA256 | 4 | 434,156 B |
| Pending | **667** | **2,489,836,470 B** |
| Total | **712** | **2,495,925,395 B** |

There are 693 filenames ending in `.pdf`, and 19 other file types. At least 16 entries have no advertised file size, requiring fresh metadata verification. **Do not equate 667 pending source records with 667 confirmed accessible PDFs.** The site catalogs contain additional external and collection references requiring further review.

## Original bounded migration queue

| State | Rows | Bytes |
|---|---:|---:|
| Imported | 59 | 28,537,852 |
| Pending | **100** | **557,391,151** |
| Total | 159 | 585,929,003 |

The initial 159 records overlap the 712 source inventory and must not be added together. The site inventory contains files from bac, fifth, fourth, sixth, uShare literature and newly indexed Drive collections.

## Application implementation

- Flutter in-app viewer supports online partial loading through the app-only Cloudflare API and does not automatically save a permanent offline copy.
- Download remains a separate user action with SHA256-checked local files, resumability, and persistent favourites.
- Direct D1+R2 API bindings are retained; no Supabase, Oracle MySQL HeatWave or website runtime dependency.
- Worker `mauri-study-app-api` updated to serve `Content-Disposition: inline` for viewing, and `?download=1` for attachment.
- Android/Flutter and backend API tests pass for merged reader feature.

## Resume and failures

Run `scripts/migrate_site_drive.py` with `--rights-confirmed` and read-only Google Drive OAuth credentials, or dispatch the bounded workflow `.github/workflows/migrate-site-library.yml` with the required GitHub Actions secrets. It indexes only real PDF bytes after checking the header, trailer, size, SHA256 and R2 **readback**. An idempotent source ledger avoids republishing unchanged files. The script writes failed attempts to `site_import_failures` and supports `--retry-failed`, with per-run byte/file caps.

**Remaining:** actually transfer and verify all accessible, authorized pending source PDFs; investigate stale/restricted external entries, other document formats, and additional website-only catalogs. Do not represent the migration as finished.
