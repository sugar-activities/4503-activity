#!/bin/sh

set -e

PACKAGE_TYPES='deb rpm tar'

for file in ${INCDIR:-/usr/share/opera/package}/*.sh; do
	. "$file"
done

main "$@"
