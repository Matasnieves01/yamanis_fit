#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Install Flutter using git.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for iOS.
flutter precache --ios

# Install Flutter dependencies (generates ios/Flutter/Generated.xcconfig).
flutter pub get

# Install CocoaPods using Homebrew.
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

# Install CocoaPods dependencies (generates Pods/ and xcfilelists).
cd ios && pod install

exit 0
