# -*- mode: sh -*-

main()
{
	guess_os

	PREFIX=/usr
	BASENAME=''
	PACKTYPE=''
	DESTDIR=.
	OVERRIDENAME=''
	INPUT=''
	local arg next_var stem run_lint i
	next_var=''
	run_lint=true
	for arg; do
		if [ -n "$next_var" ]; then
			eval $next_var='$arg'
			next_var=''
			continue
		fi
		case "$arg" in
			--prefix)
				next_var=PREFIX
				;;
			--name)
				next_var=BASENAME
				;;
			--format)
				next_var=PACKTYPE
				;;
			--dest)
				next_var=DESTDIR
				;;
			# This one is for testing purpose, I want to invoke script with option
			# to name the output file whatever I want e.g. foo, so output is foo.deb
			--override-name)
				next_var=OVERRIDENAME
				;;
			--nolint)
				run_lint=false
				;;
			--help)
				main_help
				exit
				;;
			--*)
				echo "Unrecognized option: $arg" >&2
				exit 1
				;;
			*)
				if [ -n "$INPUT" ]; then
					main_help
					exit 1
				fi
				INPUT=$arg
				;;
		esac
	done
	if [ -n "$next_var" ]; then
		echo "Missing argument to $arg" >&2
		exit 1
	fi
	if [ -z "$INPUT" ]; then
		main_help
		exit 1
	fi
	local found
	found=false
	for i in $PACKAGE_TYPES; do
		if [ "$i" = "$PACKTYPE" ]; then
			found=true
			break
		fi
	done
	if ! $found; then
		echo "Package format must be specified as one of: $PACKAGE_TYPES" >&2
		exit 1
	fi
	
	TEMPAREA=$(mktemp -d -t opera.XXXXXXXXXX)
	trap main_cleanup 0 INT TERM HUP QUIT
	if [ ! -w "$TEMPAREA" ]; then
		echo 'Failed to create a temporary area' >&2
		exit 1
	fi
	
	main_prepare_input

	if $run_lint; then
		xmllint "$INDIR/config.xml" >/dev/null
		if [ $(xmllint --walker --pattern /widget "$INDIR/config.xml" | wc -l) != 1 ]; then
			echo 'The root element in config.xml must be <widget>' >&2
			exit 1
		fi
	fi
	xml_parse <"$INDIR/config.xml"
	if [ -n "$BASENAME" ]; then
		normalize_name $BASENAME
	else
		stem=${INPUT##*/}
		normalize_name "$widget_widgetname" ${stem%.wgt}
	fi
	main_prepare_output
	layout_common
	layout_${PACKTYPE}
	package_${PACKTYPE}
	echo "$OUTFILE"
}

main_cleanup()
{
	local res
	res=$?
	rm -rf "$TEMPAREA"
	exit $res
} 

guess_os()
{
    os=`uname -s` || echo "Error: uname not defined, aborting"

    case $os in
        FreeBSD|NetBSD|DragonFly) os=AnyBSD
    ;;
    esac
}

main_prepare_input()
{
	if [ -d "$INPUT" ]; then
		INDIR=$INPUT
	else
		INDIR="$TEMPAREA/widget"
		case $os in
			AnyBSD) 
				mkdir -p "$INDIR"
				tar xf "$INPUT" -C "$INDIR"
			;;
			*)
				unzip -qq -L -d "$INDIR" "$INPUT"
			;;
		esac
	fi
	if [ ! -f "$INDIR/config.xml" ]; then
		set "$INDIR"/*
		if [ -z "$1" -o -n "$2" -o ! -f "$1/config.xml" ]; then
			echo "Cannot find config.xml" >&2
			exit 1
		fi
		INDIR=$1
	fi
}

main_prepare_output()
{
	OUTDIR="$TEMPAREA/tree"
	METADIR="$TEMPAREA/meta"
	mkdir -p "$OUTDIR" "$METADIR"
}

main_help()
{
	cat <<EOF
Usage: package-opera-widget [options] <wgt file or unpacked directory>

  --prefix PREFIX
                 set the package installation prefix (/usr by default)
  --name NAME
                 set the name of the package (opera-widget- will be prepended)
  --format FORMAT
                 select package format (supported: $PACKAGE_TYPES)
  --dest DESTDIR
                 set the output directory (current directory by default)
  --nolint
                 assume that config.xml is valid and do not run xmllint
  --help
                 display this help message
EOF
}
