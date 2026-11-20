#!/bin/bash
# Unit-tests the time parsing (no app needed).
set -euo pipefail
cd "$(dirname "$0")"
out="$(mktemp -d)/parse-tests"
swiftc -swift-version 5 Sources/Parse.swift Tests/main.swift -o "$out"
"$out"
