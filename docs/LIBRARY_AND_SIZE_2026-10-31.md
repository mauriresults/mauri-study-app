# Mauri student — library migration and small-build status (2026-10-31)

This report covers only the **independent** Mauri student resources. The MauriResults website and database were not modified.

## Confirmed migration in Cloudflare R2 and D1

- R2 bucket: `mauri-study-files`, private.
- D1 database: `mauri-study-app-db`.
- 19 published PDF resources, 19 matching R2 objects, 19 import audit records.
- Total bytes: **3,872,734** (about 3.87 MB), confirmed by independently comparing D1 totals and the R2 object listing.
- Original baseline: 8 BAC files totaling 1,816,924 bytes.
- New in this batch: 11 fifth-year (5AS) files totaling 2,055,810 bytes.
- New curriculum structure: `5as` -> `5c` and `5d` -> Maths / Physique-chimie.
- File sizes and original PDF signatures were verified before indexing. SHA-256 digests were calculated for local source bytes and stored in D1.
- `PRAGMA foreign_key_check` reported no database violations.

The previously suggested **50 GB library has NOT been transferred**. Large scale ingestion will require authenticated streaming access to its actual files, source-by-source permission documentation, an import batch workflow, retries, and a storage-cost decision.

The source owners' redistribution permissions were reported by the project owner; this report does not claim independent licensing verification.

## Storage-budget note

As of 2026-10-31, Cloudflare R2 Standard includes 10 GB-month of free storage. Storing 50 GB steadily would exceed the free allowance by about 40 GB; list and write operations are billed separately if free usage is exceeded. Do not silently exceed the free allowance without confirming the project's cost budget.

Official pricing: https://developers.cloudflare.com/r2/pricing/

## Smaller Android output

Verified from GitHub Actions run `41225675552`:
- ARM 64-bit release-mode preview: **18,699,971 bytes** (18.7 MB).
- ARM 32-bit release-mode preview: **16,152,093 bytes** (16.2 MB).
- The two APKs together are stored in a ~17 MB GitHub Actions ZIP artifact.
- Release-mode preview AAB: **52,457,893 bytes** (52.5 MB), stored as an Actions artifact.
- Debug APK replaced for end-user distribution: ~161 MB. Do not suggest users download the old debug APK when smaller builds are available.

Build configurations:
- `.github/workflows/compact-android.yml`: release-mode Android split-ABI previews, signature and SHA-256 checks, size cap of 30 MB per APK, AAB preview preparation.
- `.github/workflows/publish-compact.yml`: publish verified preview APKs via public GitHub Releases.
- `.github/workflows/play-aab.yml`: manually initiated, production-upload-key signed AAB. Requires all four GitHub Actions secrets `MAURI_UPLOAD_KEYSTORE_BASE64`, `MAURI_UPLOAD_KEY_ALIAS`, `MAURI_UPLOAD_KEY_PASSWORD`, `MAURI_UPLOAD_STORE_PASSWORD`. Signing occurs only on the runner; production signing credentials are never committed.

**Do not upload the preview AAB to Google Play**. To publish, configure a private Play upload key, run the signed workflow, and complete store compliance, testing and app registration. The app still needs real-device verification for each CPU architecture and for installing over older builds signed with different certificates.

PDFs remain remote until students explicitly download them; the installer size does not grow with library size.
