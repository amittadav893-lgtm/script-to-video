#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter SDK is required. Install Flutter, then rerun this script.' >&2
  exit 1
fi

root="$(cd "$(dirname "$0")" && pwd)"
cd "$root"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
cp pubspec.yaml "$tmp_dir/pubspec.yaml"
cp lib/main.dart "$tmp_dir/main.dart"
cp android/app/src/main/AndroidManifest.xml "$tmp_dir/AndroidManifest.xml"

flutter create --platforms=android .
cp "$tmp_dir/pubspec.yaml" pubspec.yaml
cp "$tmp_dir/main.dart" lib/main.dart
cp "$tmp_dir/AndroidManifest.xml" android/app/src/main/AndroidManifest.xml
flutter pub get

echo 'Project bootstrapped. Run: flutter run'
