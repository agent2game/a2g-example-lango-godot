#!/bin/sh
# Replace addons/a2g with the A2G SDK for Godot at a given release tag.
# Usage: scripts/update-a2g-sdk.sh v0.1.0
set -eu
tag="${1:?usage: scripts/update-a2g-sdk.sh <tag>}"
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "https://github.com/agent2game/a2g-sdk-godot/archive/refs/tags/${tag}.tar.gz" | tar -xz -C "$tmp"
rm -rf addons/a2g
mkdir -p addons
mv "$tmp"/a2g-sdk-godot-*/addons/a2g addons/a2g
echo "addons/a2g updated to ${tag}"
