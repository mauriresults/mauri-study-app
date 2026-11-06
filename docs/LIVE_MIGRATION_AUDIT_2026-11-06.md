# Mauri Student — live independent library migration checkpoint

**Verified 2026-11-06 (UTC)** against application-only Cloudflare D1 `mauri-study-app-db` and R2 `mauri-study-files`. No modification was made to `mauriresults/nejahi`, its website database, its deployment or its storage.

## Live after this batch

| Check | Verified |
|---|---:|
| Published PDF resources in app D1 | **139** |
| Published D1 bytes | **58,548,722** |
| R2 object count | **139** |
| R2 object bytes | **58,548,722** |
| Distinct published SHA-256 digests | **139** |
| Newly published PDF objects in this checkpoint | **21** |
| New, published bytes | **15,208,890** |
| Source entries imported | **108** |
| Source entries linked as duplicates | **7** |
| Source entries still pending | **596** |
| Source entries unavailable | **1** |
| Total source entries in independent D1 inventory | **712** |

These numbers are live database/storage counts rather than an app-build or website report. Before the batch, the application had 118 PDFs (43,339,832 bytes), 87 imported source records, 4 duplicate source records and 621 pending source records.

## Newly published files

Each of the **21 net new PDF files** was fetched from an authorized Drive source/copy, checked for PDF header and trailer and expected byte size, deduplicated by SHA-256 against published resources, written as a binary object to the app's own private R2 bucket, independently fetched from R2, rehashed and compared byte-for-byte via SHA-256 **before** publishing an app D1 resource and updating the source ledger.

| New app resource ID | Document (original or verified display title) | Bytes |
|---:|---|---:|
| 121 | Résumé de cours Sn 6AF | 203,871 |
| 122 | 7D mathematics Bac 2023 | 205,558 |
| 123 | 4AS mathematics term-1 test | 211,534 |
| 124 | Résumé monohybridisme | 220,297 |
| 125 | Sujet n°1 physique chimie | 220,597 |
| 126 | 7D natural-sciences mock Bac 2026 | 229,214 |
| 127 | منهجية السرد | 237,113 |
| 128 | 4AS mathematics third-term test | 237,330 |
| 129 | English Bac 2024 (M/SN/TM) | 257,290 |
| 130 | 4AS physics/chemistry term-2 test | 257,922 |
| 131 | Natural-sciences mock Bac 2026, #2 | 276,614 |
| 132 | 4AS mathematics second-term test | 283,249 |
| 133 | 7A English student book | 539,517 |
| 134 | النفيس الجديد 4AS | 676,940 |
| 135 | 7A French student book | 754,114 |
| 136 | Joussour Maths 7D | 960,357 |
| 138 | Cahier arabe 1AP | 1,846,981 |
| 139 | Maths 4AS Passeport | 1,413,117 |
| 140 | Livre chimie | 1,635,258 |
| 141 | المفيد — teacher-training competition reference; original site indexed as 4AS, classification needs further editorial review | 2,065,178 |
| 142 | Brochure math 6AF | 2,476,839 |

Resource identifiers are intentionally non-contiguous because an invalid PDF and a content duplicate were retracted.

### QA, classification and source deduplication

- The 1,240-byte source `Bac D SN 2021 sn.pdf` (temporary resource #120) parsed as a PDF but rendered as a blank page. It was **unpublished and deleted from R2/D1**, with the source marked `unavailable` and a failure explanation recorded. It is **not** counted as new content.
- Two `Joussour Maths 7D` copies (#136 and former #137) had distinct binary hashes but text across all 15 pages was identical; the redundant second object/resource was deleted, and its source now points to resource #136 as a duplicate.
- Additional incoming PDFs matching existing app SHA-256 values were linked to published resources without a duplicate R2 upload.
- Real page/content checks with PyMuPDF were used on the transferred files, including scanned/image-based references. Verified exam subjects, years and meaningful Arabic titles were updated in the application database for resources #122, #123, #126, #128–#132.
- The file `كتاب المفيد AR.pdf` is an apparent teacher-training-competition study book according to its scanned cover, rather than clearly a 4AS textbook. The original source inventory placed it in 4AS; **its taxonomy requires separate editorial review**.
- Five zero-size entries for important books were updated from actual Google Drive metadata so future transfers can check exact expected sizes; metadata verification **is not a transfer**.

### Remaining limitations

- **596 indexed source records remain pending.** They have not been checked or published merely because their titles appear in the source catalog.
- An attempt to transfer the 3,210,317-byte sixth-primary Arabic support book hit a connector transport error; readback confirmed its app source still `pending` and **no R2 object was written**. It must be retried with an importer suited to larger files.
- The remaining collection references (external folders and textbook catalogs) may contain additional files not included in the 712-row inventory.
- Production Flutter installation / end-to-end public API checks were not run in this batch; verification here covers live D1 and R2 consistency and the transferred PDF bytes.
- The existing `scripts/migrate_site_drive.py` and `.github/workflows/migrate-site-library.yml` allow bounded migration with required OAuth/API/S3 secrets. The workflow has **not** been dispatched by this checkpoint and no claim is made that the remaining inventory will import automatically.
- No new paid infrastructure or services were enabled.

**Next priority:** continue verified, rights-authorized imports in batches with a suitable streaming uploader; review classifications and unavailable/duplicate files; extend beyond the source inventory after enumerating additional authorized collections.
