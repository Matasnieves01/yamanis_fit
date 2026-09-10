#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# Navigate to the root of the repository
cd "${CI_PRIMARY_REPOSITORY_PATH:-$CI_WORKSPACE}"

# 1. Install Flutter SDK if not present
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
fi
export PATH="$PATH:$HOME/flutter/bin"

# 2. Precache iOS artifacts
flutter precache --ios

# 3. Get Flutter dependencies
flutter pub get

# 4. Install CocoaPods if not installed
if ! which pod > /dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
fi

# 5. Install Pods
cd ios
pod install
cd "${CI_PRIMARY_REPOSITORY_PATH:-$CI_WORKSPACE}"

# 6. Generate Flutter iOS Release configuration and plugin registrations
flutter build ios --config-only --release --no-codesign

exit 0
