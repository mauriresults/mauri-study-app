# Mauri Student — continued verified transfer checkpoint (2026-11-06)

This report is a **newer live checkpoint** than `LIVE_MIGRATION_AUDIT_2026-11-06.md`. It concerns only the independent Flutter app, the D1 database `mauri-study-app-db` and the private R2 bucket `mauri-study-files`. It did **not** modify the original website `mauriresults/nejahi`, its storage or its database.

## Live counts after the continued batch

| Metric | Before | After | Change |
|---|---:|---:|---:|
| Published PDF resources in D1 | 139 | **160** | **+21** |
| Published PDF bytes in D1 | 58,548,722 | **64,099,712** | **+5,550,990** |
| R2 object count | 139 | **160** | +21 |
| R2 object bytes | 58,548,722 | **64,099,712** | +5,550,990 |
| Distinct published SHA-256 values | 139 | **160** | +21 |
| Imported source entries | 108 | **129** | +21 |
| Source entries linked as duplicates | 7 | **9** | +2 |
| Pending source entries | 596 | **573** | -23 |
| Unavailable source entries | 1 | **1** | unchanged |
| Total source inventory entries | 712 | **712** | unchanged |

The live D1 and R2 byte totals match exactly; `PRAGMA foreign_key_check` reported **0 violations**. Eleven previously zero-size source entries were corrected from connected Google Drive file metadata, without claiming that those files were transferred.

## New documents published in the app

| Resource ID | Source document title | File bytes |
|---:|---|---:|
| 143 | ملخص للباك-1.pdf | 212,048 |
| 144 | مذكرة الأصول.pdf | 216,267 |
| 145 | Compo7C Lycée Zte.pdf | 217,701 |
| 146 | الإعجاز.pdf | 219,030 |
| 147 | الفيزياء  PC.pdf | 228,724 |
| 148 | دروس التمهيدي (التشريع) 2.pdf | 239,584 |
| 149 | الدرس 3 أصول الفقه.pdf | 240,503 |
| 150 | المنهجية الجديدة بكالوريا آداب.pdf | 256,055 |
| 151 | مفاهيم التاريخ 1.pdf | 260,647 |
| 152 | 4AS PC C3.pdf | 293,205 |
| 153 | 4AS Maths  Excellence 2020.pdf | 302,100 |
| 154 | Ebah Brz (دفتر التحضير).pdf | 248,756 |
| 155 | الدرس 4 الفقه الشهادات.pdf | 263,704 |
| 156 | 7D 10.02.26 MEDO.pdf | 281,228 |
| 157 | بكلوريا-الفرنسية-شعبة-الاداب-الاصلية-2024.pdf | 282,592 |
| 158 | Série Mh 25-26 mourad.pdf | 286,507 |
| 159 | Sujet de revision N2.pdf | 287,535 |
| 160 | مفاهيم فلسفية   EL OURWA.pdf | 287,657 |
| 161 | feuille_exercices_electrotechnique_TD.pdf | 298,353 |
| 162 | Correction du devoir 1 lycée d'atar et E.P Echab Echater.pdf | 298,651 |
| 163 | Résumé de dihybridisme.pdf | 330,143 |

All newly transferred documents were downloaded from accessible authorized Drive sources or user-owned copies and checked locally as parseable PDFs (header/trailer and first-page text or image presence), with local SHA-256 and MD5 digests. After each R2 upload, the independently queried R2 object listing matched the source size and MD5 ETag before inserting a published D1 resource and linking its private source ledger. This is a **size/ETag readback check**, not a claim of an independent R2 SHA-256 download. The existing app Worker serves the files from its own R2 bucket, rather than from Drive or the website.

## Deduplication, blocked attempt and CI

- `Rallye5AST1M2021.pdf` matched published resource #25; source marked `duplicate` without another upload.
- `منهجية الشعر_250528_163856.pdf` matched published resource #39; source marked `duplicate` without another upload.
- `BacBlanc2026.pdf` remained **pending** when its connector-mediated upload could not complete. It is not counted in the new resources.
- PRs [#6](https://github.com/mauriresults/mauri-study-app/pull/6) and [#7](https://github.com/mauriresults/mauri-study-app/pull/7) were merged. Importer/API CI passed, but one-time workflow [run 42259022049](https://github.com/mauriresults/mauri-study-app/actions/runs/42259022049) failed safely because GitHub Actions has none of the five required import secrets (`CF_ACCOUNT_ID`, `CF_API_TOKEN`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `GOOGLE_DRIVE_ACCESS_TOKEN`). The 21 resources reported above were transferred **directly through the connected Drive and Cloudflare tools**, not through that failed run.
- The user's prior assertion of redistribution authorization is recorded; this checkpoint does not independently verify rights for external third-party files.

## Remaining work

**573** source records still have state `pending`. The source inventory is not necessarily exhaustive of external source collections. Continue bounded verified imports, audit file classifications and update batch reports, while preserving website independence and staying inside the approved storage budget. No claim is made here that all source files or the advertised large library have been migrated.
