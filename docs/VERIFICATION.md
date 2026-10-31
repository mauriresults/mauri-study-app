# Actual verification and delivery status

This is a partial development update to the supplied starter. It is not a completed Android/iOS delivery.

## Executed checks

- `node backend/test/api.test.js`: 13 tests passed. These are local request tests with D1/R2 doubles, not external service tests.
- `python -m unittest discover -s scripts/tests -v`: 8 tests passed. Includes rejection of corrupt readback and missing publication-rights evidence.
- Cloudflare connected-account reads confirmed the exact independent D1 database `124dee36-99ce-4365-8cf9-af0b01b2d1d7`, R2 bucket `mauri-study-files`, and Worker `mauri-study-app-api` bindings `DB` and `FILES`. No other project was modified.

## Not verified or delivered

- Flutter SDK and Android SDK are unavailable. Their download could not complete because the execution proxy was unreachable and network permission requests did not complete. `flutter pub get`, `flutter analyze`, `flutter test`, APK and AAB builds were not run.
- No macOS/Xcode environment or Apple signing was available. No iOS build was performed. Native Android/iOS projects are still absent; the existing bootstrap script generates them on a suitably equipped machine.
- New Dart changes require analysis, tests, and device checks. Resume, simultaneous downloads, airplane mode, PDF rendering, localization, and large-list performance have not been verified on a device.
- No external API HTTP smoke test, storage-private-access test, stress test, or Worker deployment was completed.
- No new educational files were transferred or published. Historical claims of 8 files / 1,816,924 bytes in the starter have not been independently verified by downloading and hashing those files.
- The full requested interface, favorites, persisted settings, corrections, production signing, Drive ingestion pipeline, and resumable multipart imports remain incomplete.
- The owner created the independent public repository `mauriresults/mauri-study-app` and added it to the connected GitHub app installation. Its identity and inclusion in the allowed repositories were verified. The previous missing-repository and installation-access blockers are resolved. No existing application repository was used or modified.

## Changed behavior

- R2 metadata is read with `head`; HEAD and invalid ranges never open a full body. Full and partial downloads each use one body read guarded against a concurrent object replacement.
- Suffix ranges, If-Range, If-None-Match, exposed range headers and bodyless HEAD responses are handled. Invalid pagination cursors return 400.
- Downloads deduplicate concurrent requests for the same ID; files and partials are versioned by SHA-256. Existing completed files are checked before reuse. Writes await disk completion and idle streams time out.
- Import publication requires a recorded rights-evidence field. This is a human-supplied reference, not automated legal verification. Stored bytes are streamed back and hashed before D1 indexing. Existing keys with different content are not overwritten.
- A GitHub Actions workflow was added for local API and importer tests. It has not run remotely.

## Next execution steps

1. Use the independent repository `https://github.com/mauriresults/mauri-study-app` and check its Actions runs after each push. Remote CI success requires a completed successful run and must not be inferred from the workflow files alone.
2. Install Flutter stable plus Android SDK; run `bash scripts/bootstrap_flutter.sh`, then build and test a debug APK. Resolve any Dart or platform failures before distributing it.
3. Run the API tests against local real D1/R2 bindings, then deploy only the independent Worker and run `python scripts/verify_remote_api.py --check-download`. Add full-file SHA-256, pagination, privacy and cache checks before release.
4. Complete the outstanding UI, offline and import requirements. Record explicit redistribution rights for each source before publication.
5. For Google Play, supply a private release keystore through CI secrets and build a signed AAB. Do not use the debug certificate for a store release.
6. For App Store, generate the iOS platform on macOS, configure the bundle ID/team and signing in Xcode, test on an iPhone, and archive with an authorized Apple developer account. Neither store publication nor paid account enrollment has been performed.
