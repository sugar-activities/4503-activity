# -*- mode: sh -*-

layout_deb()
{
	local menu_dir

	menu_dir=$OUTDIR/$PREFIX/share/menu

	mkdir -p $menu_dir

	layout_deb_generate_menu > $menu_dir/$PACKNAME
}

layout_deb_generate_menu()
{
	cat <<-EOF
	?package():
	    needs="X11"
	    section="Applications/Network"
	    icon="$PREFIX/share/$PACKNAME/$widget_icon"
	    command="$PREFIX/bin/$PACKNAME"
	EOF
}
