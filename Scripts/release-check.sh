#!/bin/bash
# The M12 release check, repeatable.
#
# ⚠️ Builds the *project*, never the workspace. A local package in a workspace
# shadows its resolved remote version, so a workspace build can be green
# against uncommitted siblings and broken against the tags. Building the
# project resolves from git and nowhere else.
#
# Usage:  Scripts/release-check.sh
set -euo pipefail

DD="${DERIVED_DATA:-$(mktemp -d)/dd}"
DEST='platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0'

echo "== Release build, tags only =="
xcodebuild -project Sparrow.xcodeproj -scheme Sparrow \
    -destination "$DEST" -derivedDataPath "$DD" \
    -configuration Release CODE_SIGNING_ALLOWED=NO \
    clean build 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'

echo
echo "== It compiled against these checkouts =="
find "$DD/SourcePackages/checkouts" -maxdepth 1 -mindepth 1 -type d \
    | sed 's|.*/|  |'

echo
echo "== The metadata gate =="
# Extraction failures are silent: the build succeeds and nothing appears in
# Shortcuts. Both processors must print.
xcodebuild -project Sparrow.xcodeproj -scheme Sparrow \
    -destination "$DEST" -derivedDataPath "$DD" \
    -configuration Release CODE_SIGNING_ALLOWED=NO \
    clean build 2>&1 \
    | grep -iE 'appintentsmetadataprocessor|appintentsnltrainingprocessor' \
    | grep -E 'Writing Metadata|Training |no relevant' \
    | sed 's/^[0-9-]* [0-9:.]* //'
