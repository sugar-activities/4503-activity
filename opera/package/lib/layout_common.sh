# -*- mode: sh -*-

layout_common()
{
	local suffix

	mkdir -p "$OUTDIR$PREFIX/share/$PACKNAME"
	cp -r $INDIR/* "$OUTDIR$PREFIX/share/$PACKNAME"
	if [ -n "$widget_icon" -a -s "$INDIR/$widget_icon" ]; then
		suffix="${widget_icon##*.}"
		case "$suffix" in
			gif|png|svg)
				mkdir -p "$OUTDIR$PREFIX/share/pixmaps"
				ln -s "$PREFIX/share/$PACKNAME/$widget_icon" "$OUTDIR$PREFIX/share/pixmaps/$PACKNAME.$suffix"
				;;
		esac
	fi

	mkdir -p "$OUTDIR$PREFIX/bin"
	layout_common_wrapper >"$OUTDIR$PREFIX/bin/$PACKNAME"
	chmod a+x "$OUTDIR$PREFIX/bin/$PACKNAME"

	mkdir -p "$OUTDIR$PREFIX/share/man/man1"
	layout_common_man >"$OUTDIR$PREFIX/share/man/man1/$PACKNAME.1"
	gzip "$OUTDIR$PREFIX/share/man/man1/$PACKNAME.1"

	mkdir -p "$OUTDIR$PREFIX/share/applications"
	layout_common_desktop >"$OUTDIR$PREFIX/share/applications/$PACKNAME.desktop"

	echo $PACKNAME >"$METADIR/package-name"

	if [ -z "$widget_id_revised" ];
	then
		echo "0" >"$METADIR/version"
	else
		echo "$widget_id_revised" >"$METADIR/version"
	fi

	echo all >"$METADIR/architecture"
	# Will change to depend on opera-widget-runtime instead.
	echo opera >"$METADIR/depends"
	echo "$widget_author_link" >"$METADIR/homepage"
	echo "$widget_author_name" >"$METADIR/author"
	echo "$widget_author_email" >"$METADIR/contact"
	echo "$widget_widgetname" >"$METADIR/description-short"
	echo "$widget_description" >"$METADIR/description-long"

	mkdir -p "$METADIR/configure"
	layout_common_configure >"$METADIR/configure/common"

	mkdir -p "$METADIR/deconfigure"
	layout_common_deconfigure >"$METADIR/deconfigure/common"
}

layout_common_wrapper()
{
	cat <<EOF
#!/bin/sh
skipnext=false
for arg; do
	if \$skipnext; then
		skipnext=false
		continue
	fi
	case "\$arg" in
		-help|--help|-'?')
			cat >&2 <<END
Usage: $PACKNAME [options]

 -geometry <geometry>           set geometry of toplevel window
 -display <display name>        set the X display
 -visual TrueColor              use TrueColor visual on an 8-bit display
 -cmap                          use private color map on an 8-bit display
 -postfix <name>                append name to WM_CLASS and WM_WINDOW_ROLE
 -pd <path>                     location of alternative Opera preferences folder
 -version                       show version data
 -help                          displays command line help
 -?                             displays command line help
END
			exit
			;;
		-version|--version)
			cat >&2 <<END
$widget_widgetname $widget_id_revised
END
			exit
			;;
		-geometry|-display|-visual|-postfix|-pd|-personaldir)
			skipnext=true
			;;
		-cmap)
			;;
		*)
			echo "Unrecognized option: \$arg" >&2
			exit 1
			;;
	esac
done
if \$skipnext; then
	echo "Missing argument to \$arg" >&2
	exit 1
fi
exec opera -pd \$HOME/.$PACKNAME "\$@" -widget $PREFIX/share/$PACKNAME/config.xml
EOF
# For now replaced:
#	opera-widget-runtime -pd \$HOME/.$PACKNAME "\$@" $PREFIX/share/$PACKNAME/config.xml
# with:
# 	opera -pd \$HOME/.$PACKNAME "\$@" -widget $PREFIX/share/$PACKNAME/config.xml
# because otherwise it doesn't work for now.
}

layout_common_man()
{
	cat <<EOF
.TH $PACKNAME 1
.SH NAME
$PACKNAME \- $widget_widgetname
.SH SYNOPSIS
.B $PACKNAME
.RI [ options ]
.SH DESCRIPTION
$widget_description
.SH "COMMAND LINE OPTIONS"
.PP
These support both double and single dash as prefix.
Several other options are also supported, notably including many
generic X Toolkit options; see
.B \-\^\-help
output for details.
.TP
.BI \-\^\-personaldir " path"
.TP
.BI \-\^\-pd " path"
Use
.I path
as personal configuration directory (ignore default location).
.TP
.B \-\^\-version
Display version information and exit.
.TP
.BR \-h " \fR,\fP " "\-\^\-help"
Print option summary and exit.
.SH "FILES AND DIRECTORIES"
.TP
.I $PREFIX/bin/opera-widget-runtime
.TP
The runtime for Opera Widgets.
.I $PREFIX/share/$PACKNAME
Installation path for the widget files.
.TP
.I ~/.$PACKNAME/
The default personal configuration directory.
.SH AUTHOR
$widget_author_name
.B $widget_author_email.
.TP
$widget_author_organization
.B $widget_author_link.
.SH "SEE ALSO"
.BR opera (1)
EOF
}

layout_common_desktop()
{
	cat <<EOF
[Desktop Entry]
Version=1.0
TryExec=$PACKNAME
Encoding=UTF-8
Name=$widget_widgetname
GenericName=Opera Widget
Exec=$PACKNAME
Terminal=false
Icon=$PREFIX/share/$PACKNAME/$widget_icon
Comment=$widget_description
Type=Application
EOF
}

layout_common_configure()
{
	cat <<EOF
if which update-desktop-database >/dev/null 2>&1; then
	update-desktop-database -q
fi
EOF
}

layout_common_deconfigure()
{
	cat <<EOF
if which update-desktop-database >/dev/null 2>&1; then
	update-desktop-database -q
fi
EOF
}
