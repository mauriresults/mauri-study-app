#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../app"
# Generate genuine Android/iOS project files from the pinned installed Flutter SDK.
python ../scripts/generate_platforms.py
python ../scripts/configure_android.py
flutter pub get
flutter analyze
flutter test
printf '\nTo run: flutter run --dart-define=API_BASE_URL=https://mauri-study-app-api.mauri-study-app.workers.dev\n'
