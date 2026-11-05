#!/bin/sh
grep -E "^\s*[0-9]+\+?\s+[0-9A-F]{4}\s.*[[:space:]]$1:" "$(dirname "$0")/../build/circus2.lst" | head -1 | awk '{print $2}'
