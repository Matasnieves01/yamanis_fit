#!/usr/bin/env bash
set -euo pipefail

# sync_versions.sh
# Usage: ./scripts/sync_versions.sh
# Reads version from pubspec.yaml (format: X.Y.Z+N) and writes
# FLUTTER_BUILD_NAME/NUMBER in ios/Flutter/Generated.xcconfig and
# flutter.versionName/flutter.versionCode in android/local.properties.

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC="$PROJECT_ROOT/pubspec.yaml"
XCCONFIG="$PROJECT_ROOT/ios/Flutter/Generated.xcconfig"
LOCALPROPS="$PROJECT_ROOT/android/local.properties"

if [ ! -f "$PUBSPEC" ]; then
  echo "Cannot find pubspec.yaml at $PUBSPEC"
  exit 1
fi

# Extract version line (remove whitespace)
version_raw=$(sed -n 's/^version:[[:space:]]*//p' "$PUBSPEC" | tr -d '[:space:]')
if [ -z "$version_raw" ]; then
  echo "No version found in pubspec.yaml"
  exit 1
fi

# Split into name and build
if [[ "$version_raw" == *+* ]]; then
  version_name="${version_raw%%+*}"
  build_number="${version_raw##*+}"
else
  version_name="$version_raw"
  build_number="1"
fi

echo "Found version: $version_name (build $build_number)"

update_xcconfig() {
  if [ -f "$XCCONFIG" ]; then
    # macOS sed in-place uses an empty extension
    if grep -q '^FLUTTER_BUILD_NAME=' "$XCCONFIG"; then
      sed -i '' -e "s/^FLUTTER_BUILD_NAME=.*/FLUTTER_BUILD_NAME=$version_name/" "$XCCONFIG"
    else
      printf "\nFLUTTER_BUILD_NAME=%s\n" "$version_name" >> "$XCCONFIG"
    fi

    if grep -q '^FLUTTER_BUILD_NUMBER=' "$XCCONFIG"; then
      sed -i '' -e "s/^FLUTTER_BUILD_NUMBER=.*/FLUTTER_BUILD_NUMBER=$build_number/" "$XCCONFIG"
    else
      printf "FLUTTER_BUILD_NUMBER=%s\n" "$build_number" >> "$XCCONFIG"
    fi

    echo "Updated $XCCONFIG"
  else
    echo "File $XCCONFIG not found. Skipping iOS xcconfig update."
  fi
}

update_local_properties() {
  if [ -f "$LOCALPROPS" ]; then
    if grep -q '^flutter.versionName=' "$LOCALPROPS"; then
      sed -i '' -e "s/^flutter.versionName=.*/flutter.versionName=$version_name/" "$LOCALPROPS"
    else
      printf "\nflutter.versionName=%s\n" "$version_name" >> "$LOCALPROPS"
    fi

    if grep -q '^flutter.versionCode=' "$LOCALPROPS"; then
      sed -i '' -e "s/^flutter.versionCode=.*/flutter.versionCode=$build_number/" "$LOCALPROPS"
    else
      printf "flutter.versionCode=%s\n" "$build_number" >> "$LOCALPROPS"
    fi

    echo "Updated $LOCALPROPS"
  else
    # Create local.properties with sdk.dir empty; keep existing content minimal
    printf "flutter.versionName=%s\nflutter.versionCode=%s\n" "$version_name" "$build_number" > "$LOCALPROPS"
    echo "Created $LOCALPROPS with version values"
  fi
}

update_xcconfig
update_local_properties

echo "Sync complete. Now run 'flutter pub get' and rebuild your app."

