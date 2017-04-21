# -*- mode: sh -*-

normalize_name()
{
	local res
	for name; do
		res=$(printf '%s\n' "$name" | sed -e 's/[^a-zA-Z0-9_][^a-zA-Z0-9_]*/-/g' -e 's/^-*//' -e 's/-*$//' | tr A-Z a-z)
		if [ -n "$res" ]; then
			PACKNAME=opera-widget-$res
			return
		fi
	done
	echo "Cannot derive a suitable package name" >&2
	exit 1
}
