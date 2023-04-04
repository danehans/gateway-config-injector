#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_ROOT=$(dirname "${BASH_SOURCE}")/..

make -C "${SCRIPT_ROOT}" generate

if git status -s 2>&1 | grep -E -q '^\s+[MADRCU]'
then
	echo Uncommitted changes in generated sources:
	git status -s
	exit 1
fi
