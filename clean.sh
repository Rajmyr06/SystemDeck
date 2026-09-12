#!/bin/zsh
set -e
cd "$(dirname "$0")"
swift package clean
rm -rf .build
