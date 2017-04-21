# -*- mode: sh -*-

package_deb()
{
	local package_folder control_file postinst_file postrm_file arch output_file \
			version

	package_folder="$TEMPAREA/$PACKNAME"
	control_file="$package_folder/DEBIAN/control"
	postinst_file="$package_folder/DEBIAN/postinst"
	postrm_file="$package_folder/DEBIAN/postrm"
	arch="$(cat $METADIR/architecture)"
	version="$(cat $METADIR/version)"

	if [ -n "$OVERRIDENAME" ];
	then
		output_file="$DESTDIR/$OVERRIDENAME.deb"
	else
		output_file="$DESTDIR/${PACKNAME}_${version}_${arch}.deb"
	fi

	mkdir -p "$package_folder/DEBIAN"

	package_deb_generate_control > $control_file
	package_deb_generate_postinst > $postinst_file
	chmod 0755 $postinst_file
	package_deb_generate_postrm > $postrm_file
	chmod 0755 $postrm_file

	cp -r $OUTDIR/* $package_folder
	dpkg-deb -b $package_folder "$output_file" 1>/dev/null
	echo -n "$output_file"
}

package_deb_generate_control()
{
	cat <<-EOF
	Package: $PACKNAME
	Version: $(cat $METADIR/version)
	Architecture: $(cat $METADIR/architecture)
	Maintainer: $(cat $METADIR/author)
	Depends: $(cat $METADIR/depends)
	Homepage: $(cat $METADIR/homepage)
	Description: $(cat $METADIR/package-name)
	EOF
}

package_deb_generate_postrm()
{
	local common
	common=$(cat $METADIR/deconfigure/common)

	cat <<-EOF
	#!/bin/sh
	# postrm script for $PACKNAME

	set -e

	if [ -x "\`which update-menus 2>/dev/null\`" ]; then 
	    update-menus ; 
	fi

	$common

	exit 0
	EOF
}

package_deb_generate_postinst()
{
	local common
	common=$(cat $METADIR/configure/common)

	cat <<-EOF
	#!/bin/sh
	# postinst script for $PACKNAME

	set -e

	case "\$1" in
	configure)

	if [ -x "\`which update-menus 2>/dev/null\`" ]; then
	    update-menus
	fi

	$common

	;;
	abort-upgrade|abort-remove|abort-deconfigure)
	;;
	*) echo "postinst called with unknown argument \$1" >&2
	    exit 0
	;;
	esac

	exit 0
	EOF
}
