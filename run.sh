#!/bin/bash
set -e

cd "$(dirname "$0")/ClaudeCodeMonitor"
swift build
exec .build/debug/ClaudeCodeMonitor
