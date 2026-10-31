# Mauri Student — live migration and UI verification (31 October 2026)

This is a **point-in-time** audit of the **independent application** only. The MauriResults website's production repository, database and storage were not modified.

## Direct live checks

| Metric | Verified value |
|---|---:|
| Published rows in app D1 | **118** |
| Distinct stored SHA-256 values in published D1 rows | **118** |
| Objects in independent R2 bucket | **118** |
| Total R2/D1 published bytes | **43,339,832** |
| Newly uploaded and published PDF objects in this implementation session | **27** |
| New object bytes | **8,616,705** |
| Source inventory rows in app D1 | **712** |
| Source inventory imported | **87** |
| Source inventory duplicate | **4** |
| Source inventory pending | **621** |
| Pending inventory advertised bytes | **2,476,147,347** |
| Source failures currently persisted | **0** |

The initial **159-row legacy migration queue** overlaps the larger 712-row inventory. At the last check it reported 76 imported and **83 pending** (548,752,296 bytes), following 8 successfully imported items from this older queue. These numbers must not be added to the 629 pending source records.

## What was actually transferred

Twenty-seven verified PDF documents were read from the connected Google Drive sources and uploaded as **binary PDF objects**, *not link shortcuts*, to the application's private R2 bucket. For each new upload:

- confirmed source file was a PDF, with `%PDF-` signature and `%%EOF` trailer;
- confirmed actual byte count against advertised size when known;
- computed source file SHA-256 and checked against published resource hashes to avoid duplicate uploads;
- uploaded to the application-only R2 bucket, verified R2 listing key, size, content type and ETag against the corresponding upload result;
- added a published resource in application D1 only after upload verification;
- wrote an independent source audit linkage and updated its state.

Independent local verification parsed **all 27 PDFs successfully** with PyMuPDF and matched each locally computed source MD5 to the corresponding uploaded R2 ETag. All 27 original SHA-256 values were computed during import. This does **not** replace an independent SHA-256 re-download check of every prior R2 object. The existing long-running importer (`scripts/migrate_site_drive.py`) includes R2 byte-for-byte SHA-256 readback for later batches and persistent failed-source retry handling.

## Source inventory reviewed

- `data/indexed-drive-study-files.json`: 574 indexed file records (original site inventory).
- `data/ushare-literary-files.json`: 142 archive records, including 138 newly owned Drive copies.
- `data/study-owned-drive-part-a.json` and `part-b.json`: 574 original-to-owned-copy mappings.
- `data/study-catalog.mjs`, `data/study-library.mjs`, `data/study-resource-collections.mjs`.
- `app/api/lessons-catalog/route.ts`: additional textbook references covering school grades; **not all have been transferred** into independent R2.
- External MediaFire and uShare folders are additional collection references, **not proof of downloaded and published individual PDFs**.

## Flutter and API changes in PR #5

- Simpler home: search, nonempty study years, books, lessons, exam subjects, shortcuts to downloads and favourites.
- Library browsing year → track → subject → document kind, plus available exam years and separate correction/solution grouping.
- Preserves preexisting offline download database and saved favourites; PDF reading stays via `pdfrx` online Range requests with a separate offline download action.
- Worker public catalog gains non-sensitive source category/year labels without exposing R2 keys; legacy clients continue to work.
- Added Flutter model regression tests, Worker API regression tests and Android PR CI.

## Incomplete work and safeguards

**Remaining source inventory: 621 entries**, including files needing further accessibility verification and transfer. Additional site textbook URLs and external folder contents may expand the total. An indexed source is **not** a published application file. The 629 records' total advertised size is not a measurement of confirmed accessible PDF bytes.

At this checkpoint, 27 new PDF transfers succeeded and no new import failures were recorded. Earlier R2 files were checked for presence, size and catalog consistency; no blanket per-object cryptographic readback of all previously published bytes is claimed.

Do not enable paid storage or other services. Keep the import batches capped by files and bytes, skip inaccessible and non-PDF responses, respect distribution permissions and retry only recorded failures. Merge code and deploy Worker only after relevant CI tests pass.
