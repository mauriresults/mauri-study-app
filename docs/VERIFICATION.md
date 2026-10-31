# Verified delivery and outstanding work — 2026-10-31

This is a partial development delivery of the supplied starter. A real debug APK was built and signed, but it has not been installed on a device and the full requested product scope is incomplete.

## Download and source

- Repository: https://github.com/mauriresults/mauri-study-app
- Successful Android/API-smoke run: https://github.com/mauriresults/mauri-study-app/actions/runs/41211960313
- APK ZIP: https://github.com/mauriresults/mauri-study-app/actions/runs/41211960313/artifacts/13047215595
- Native Android/iOS projects and dependency lock: https://github.com/mauriresults/mauri-study-app/actions/runs/41211960313/artifacts/13046389089
- API: https://mauri-study-app-api.mauri-study-app.workers.dev
- Full deployed API/PDF audit: https://github.com/mauriresults/mauri-study-app/actions/runs/41212161760
- API audit checksum-report artifact: https://github.com/mauriresults/mauri-study-app/actions/runs/41212161760/artifacts/13047125554

The APK source commit is `1b4aed188e31f9b4d54bd5d5bf3d597a93f012a3`. Subsequent audit/documentation commits do not change the app. Artifact downloads require GitHub login and expire on 2027-01-29. Extract `app-debug.apk` and allow installation from your chosen file manager/browser on a test Android device; no installation success is claimed.

APK size: **153,979,716 bytes**; ZIP size: **73,327,806 bytes**. This is an unoptimized universal debug build containing Flutter runtime and multiple ABIs, not a bundled PDF library. A small optimized store build is still required.

APK SHA-256: `506c25459cad6ad8009024f50f41239d0287df260ec354da20f78438a2ec8d02`.

`apksigner verify --verbose --print-certs` passed with APK Signature Scheme v2. APK ZIP integrity, manifest/classes entries, and arm64 Flutter library were checked. It uses debug signing, not production store signing.

## Executed checks and evidence

| Check | Actual result |
| --- | --- |
| Flutter 3.47.9 package resolution | Passed on GitHub Actions |
| Flutter analysis | Passed, zero findings |
| Flutter tests | 2 existing model tests passed |
| Android debug APK build | Passed |
| APK structure/signature | Passed, artifact uploaded |
| API unit tests | 13 passed locally and remotely |
| Importer tests | 8 passed locally and remotely |
| External API/PDF audit | Passed for all 8 existing PDFs |
| D1 foreign keys | `PRAGMA foreign_key_check` returned no violations |
| R2 public-domain configuration | Managed domain disabled; no custom public domains |

The external audit tested all five requested endpoints, bounded pagination, resource detail, missing resources/files, rejection of public POST, HEAD, cache headers, full PDF downloads, SHA-256, split-range resume, suffix ranges, ETag 304 and invalid-range 416. It verified **8 files / 1,816,924 bytes**, with 3,643,175 HTTP response bytes used by the audit. See `API_AUDIT_2026-10-31.json`; the workflow artifact contains the individual hashes.

**New files imported or published: 0. The 50 GB target library has not been migrated.** Existing PDFs were read and checked without changing their publication state.

The initial external 403 was Cloudflare error 1010 rejecting the default Python library User-Agent on workers.dev. A descriptive Mauri Study application identity, as recommended in Cloudflare's error-1010 documentation, resolved it. No browser identity was impersonated or security setting disabled.

Worker corrections were deployed only to `mauri-study-app-api`, retaining D1 `124dee36-99ce-4365-8cf9-af0b01b2d1d7` and R2 `mauri-study-files`. No migrations, content imports or changes to the MauriResults application/repository/database/deployment were made. No new paid service or purchase was performed.

## Implemented corrections

- File HEAD and rejected ranges avoid opening an R2 body; full and ranged reads use an ETag guard against concurrent replacement.
- Suffix ranges, If-Range, If-None-Match, exposed range headers, bodyless HEAD and invalid pagination cursors are handled.
- Downloads deduplicate simultaneous requests for the same ID, version files/partials by SHA-256, verify existing files before reuse, await disk writes, and time out idle streams. These changes passed analysis but do not have mobile integration-test coverage yet.
- Import publication requires a human-supplied rights-evidence reference. Stored bytes are streamed back and hashed before D1 indexing; existing keys with different content are not overwritten. The rights field is not an automated legal verification.
- CI separates API availability checks from APK artifacts while preserving failing checks, verifies APK signatures/checksums, and generates native projects without counter-app tests.

## Not completed or verified

- The complete requested screens/sections, favorites, persisted language/theme settings, exam corrections, final icon/branding and official application-identifier review.
- Installation on Android, PDF rendering on a phone, airplane mode, actual interrupted/mobile downloads, concurrent-download behavior, Arabic/French/RTL device testing, large-list performance and API load testing. The external range audit verifies protocol behavior, not a real socket interruption or mobile UI.
- Download retry/queue management, UI cleanup of abandoned partial files and complete local-storage accounting.
- Google Drive folder ingestion, resumable multipart upload across importer restarts, SHA deduplication across different object keys, complete retry/audit logging and classification of the full library. Allowed source folders and explicit redistribution evidence are still needed for new publication.
- Native platform files are available as a generated artifact but are not committed to the repository. The dependency lock used by the build is in that artifact.
- AAB generation, production signing, store CI/release configuration, Play Console publication and optimized release size.
- macOS/Xcode/iPhone tests, iOS compilation, Apple certificates, App Store archive and publication. Generating the iOS scaffold on Linux is not an iOS build.
- Direct unauthenticated HTTP probing of the R2 hostname. Privacy was checked through management settings; public-write rejection was checked on the Worker API.

## Development and store preparation

1. Restore the generated native projects and `pubspec.lock` artifact if reproducing this exact build. Use Flutter 3.47.9 and Android SDK, then run `bash scripts/bootstrap_flutter.sh`. New Dart/platform changes require fresh analysis, tests and device checks.
2. Use `backend/wrangler.toml` and the correct existing Cloudflare account for future Worker changes; run tests before deployment and external audit afterward. The audit has a default 32 MiB response budget.
3. Complete the outstanding product and import work, obtain distribution rights for each new source, and perform device/offline/accessibility/performance testing.
4. For Google Play, review the package identifier, provision a private release keystore through CI secrets, configure release signing and build a signed AAB. Never publish the debug certificate as the store signing identity.
5. For App Store, use macOS/Xcode with an authorized Apple developer account, review bundle ID/team settings, configure signing, test on an iPhone and archive. No enrollment or purchase has been performed.
