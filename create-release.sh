#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: ./create-release.sh <version>  (e.g. 1.0.0)"
    exit 1
fi

VERSION=$1
TAG="v${VERSION}"

sed -i '' "s/appVersion = \".*\"/appVersion = \"${VERSION}\"/" Sources/BrewBar/Version.swift

git add Sources/BrewBar/Version.swift
if ! git diff --cached --quiet; then
    git commit -m "bump version to ${VERSION}"
fi
git tag -a "${TAG}" -m "Release ${VERSION}"

git push origin main
git push origin "${TAG}"

echo "✓ Released ${TAG}"
