# -*- mode: sh -*-

package_tar()
{
	local package_dir output_file_name output_file_path

	package_dir="$TEMPAREA/$PACKNAME"

	if [ -n "$OVERRIDENAME" ];
	then
		output_file_name="${OVERRIDENAME}.tar.gz"
		output_file_path="$DESTDIR/$OVERRIDENAME.tar.gz"
	else
		output_file_name="${PACKNAME}.tar.gz"
		output_file_path="$DESTDIR/${PACKNAME}.tar.gz"
	fi

	cp -R $OUTDIR $package_dir
	package_tar_generate_manifest_md5 >$package_dir/Manifest.md5
	package_tar_generate_install >$package_dir/install.sh
	chmod 755 $package_dir/install.sh

	(cd $TEMPAREA; tar czf "$output_file_name" "$PACKNAME")
	mv "$TEMPAREA/$output_file_name" "$output_file_path"
	echo -n "$output_file_path"
}

package_tar_generate_manifest_md5()
{
	case $os in
		AnyBSD)
			(cd $OUTDIR; find usr/ -name '*' -type f -exec md5 -r '{}' \;)
		;;
		*)
			(cd $OUTDIR; find usr/ -name '*' -type f -exec md5sum '{}' \;)
		;;
	esac
}

package_tar_generate_install()
{
	cat<< SEP
#!/bin/sh

debug_level='0'			# From 0 to 2

# Everything else should look after itself:
str_progname="install.sh"
str_defaultprefix="/usr"
OPERADESTDIR=''

unset CDPATH

warn ()
{
    echo "\$@" >&2
}

debug_msg()
{
    # This function outputs a stylish debug message if debug is enabled
    # \$1 = debuglevel
    # \$2 = message

    if test "\$debug_level" -gt "\$1"; then echo " \$str_progname: debug: \$2"; fi
}

error()
{
    # This function displays a error message and exits abnormally.
    # Arg_1 = Error Type
    # Arg_2 = Error Message

    debug_msg 0 'in error()'

    case \$1 in

	missing)
	    echo " \$str_progname: missing parameter(s)"
	    echo
	    usage
	    ;;

	invalid)
	    echo " \$str_progname: invalid parameter(s)"
	    echo
	    usage
	    ;;

	abort)
	    echo " \$str_progname: installation aborted by user"
	    ;;

	conflict)
	    echo " \$str_progname: conflicting parameters"
	    echo
	    usage
	    ;;

	access)
	    echo " \$str_progname: You do not have write access to \$2, please change to appropriate user."
	    ;;

        uname)
	    echo " \$str_progname: OS cannot be determined without the program \"uname\", aborting..."
	    ;;

	umask)
	    echo " \$str_progname: your umask," \`umask\`, "would create a broken installation."
	    echo " Run umask 022 to change it, then try again."
	    ;;

	sed)
	    echo " \$str_progname: Install script will not work without the program \"sed\", aborting..."
	    ;;
	os)
	    echo " \$str_progname: Unrecognizeed platform (\$machine) and OS (\$os), aborting..."
	    echo " \$str_progname: Please send output of uname -a to packager\@opera.com"
	    echo " mentioning Opera version \$opera_version"
	    ;;

	*)
	    debug_msg 0 "Error message \$1 not defined, aborting..."
	    ;;
    esac >&2
    exit 1
}

guess_os()
{
    # This function tries to guess which OS the install Machine is running.
    # other ideas are \$OSTYPE, arch
    # Return = \$os

    os=\`uname -s\` || error uname
    case \$os in
	FreeBSD|NetBSD|DragonFly) os=AnyBSD;;
    esac
    case \$os in AnyBSD|OpenBSD) str_defaultprefix="/usr/local";; esac

    machine=\`uname -m\`
    case \$machine in
	# Canonicalize architecture names with aliases:
	amd64) machine=x86_64;;
	i[3456]86|i86pc|x86pc) machine=x86;;
    esac
}

check_prefixes()
{
    # This function checks system enviroment for install prefix locations
    # and sets prefixed installation paths.

    export prefix wrapperdir docdir sharedir man_dir operadir

    debug_msg 0 "in check_prefixes()"
    debug_msg 1 "enviroment = \$prefix \$wrapperdir \$docdir \$sharedir \$man_dir \$operadir"

    verbose="0"

    guess_os

    # Solaris's /bin/sh's built-in umask doesn't fail when invoked
    # with -S but doesn't honour -S, either; while GNU/Linux has no
    # /usr/bin/umask so we must rely on its built-in, which *does*
    # support -S.
    case \`ls -1 /usr/bin/umask 2>/dev/null\` in /usr/bin/umask) /usr/bin/umask -S ;; *) umask -S ;; esac \
	| tr , \'\012\' | grep 'o=rw*x' >/dev/null 2>&1 || error umask
    if test "\$#" -ne 0; then parse_input "\$@"; fi
}

set_prefix()
{
    # Arg 1 = new prefix
    prefix="\$1"

    test "\${prefix}" || prefix="\${str_defaultprefix}"

    share_dir="\${prefix}/share/$PACKNAME"
    case "\$os" in
	AnyBSD|OpenBSD)
	    man_dir="\$prefix/man"
	    ;;
	*)
	    man_dir="\$prefix/share/man"
	    ;;
    esac
    doc_dir="\${prefix}/share/doc/$PACKNAME"
    wrapper_dir="\${prefix}/bin"
}

set_destdir()
{
    test "\$1" || return 1
    OPERADESTDIR="\$1"
    wrapper_dir="\${OPERADESTDIR}\${wrapper_dir}"
    doc_dir="\${OPERADESTDIR}\${doc_dir}"
    man_dir="\${OPERADESTDIR}\${man_dir}"
    share_dir="\${OPERADESTDIR}\${share_dir}"
}

usage()
{
    # This function displays the help information.

    debug_msg 0 "in usage()"

    echo "Usage: \$str_progname -s"
    echo "  or:  \$str_progname -f DEST"
    if test "\$1"
    then
	 echo "  or:  \$str_progname -f WRAPPER_DEST DOC_DEST SHARE_DEST MAN_DEST"
	 echo "  or:  \$str_progname --prefix=DEST [--wrapperdir=] [--docdir=] [--sharedir=] [--mandir=] [--operadir=]"
    else echo "  or:  \$str_progname --prefix=DEST"
    fi
    echo "  or:  \$str_progname --wrapperdir=WRAPPER_DEST --docdir=DOC_DEST --mandir=MAN_DEST --sharedir=SHARE_DEST"
    if test "\$1"
    then
	echo
	echo ' or by enviroment variables:'
	echo "  or:  prefix=DEST \${str_progname}"
	echo "  or:  export prefix=DEST; \${str_progname}"
    fi
    echo
    echo 'Install Opera files to standard or user defined locations.'
    echo
    echo '  -i, --interactive            interactive mode, default'
	echo
    echo '  -s, --standard               install to standard locations'
    echo '  -f, --force                  install to user defined location(s)'
    echo
    test "\$1" && echo '      \$prefix'
    echo '      --prefix=                install all files to directory'
    echo
    test "\$1" && echo '      \$wrapperdir'
    echo '      --wrapperdir=            install widget wrapper script to directory'
    test "\$1" && echo '      \$docdir'
    echo '      --docdir=                install widget documentation to directory'
    test "\$1" && echo '      \$man_dir'
    echo '      --mandir=                install widget manual page to directory'
    test "\$1" && echo '      \$sharedir'
    echo '      --sharedir=              install widget shared files to directory'
    echo
    test "\$1" && echo '      \$operadir'
    echo '      --operadir=              directory with opera local installation'
    echo
    echo '  -v, --verbose                output which files are copied'
    echo '  -vv                          output info on each executed command'
    echo
    echo '  -V, --version                output version information and exit'
    echo '  -h, --help                   display this help and exit'
    echo
    echo 'If you choose to do a standard locations install, files will be put into'
    echo '/usr/bin, /usr/share/doc and /usr/share.'
    echo
    echo 'However, if you choose to install to user defined locations, you must either'
    echo '  specify one directory (all files will be put in this directory), or'
    echo '  specify four directories (you may enter the same directory several times).'
}

parse_input()
{
    # This function parses trough command line parameters
    # and sets install flags and selected installation paths.

    debug_msg 0 "in parse_input()"
    debug_msg 1 "args = \$*"


while test ! -z "\$1"
do
case \$1 in

    -h|--help) usage; exit 0 ;;

    -V|--version) version; exit 0 ;;

    -v|--verbose)
	verbose='1'
	shift
	;;

    -vv)
	verbose='2'
	shift
	;;

    -i|--interactive)
	if test -z "\$flag_mode"
	then
	    flag_mode='--interactive'
	    shift
	else error conflict
	fi
	;;

    -s|--standard)
	if test -z "\$flag_mode"
	then
	    flag_mode='--standard'
	    shift
	else error conflict
	fi
	;;

    -f|--force)
	if test -z "\$flag_mode"
	then
	    flag_mode='--force'
	    shift
	    if test -z "\$1"
	    then error missing
	    elif test -z "\$2"
	    then
		str_paramprefix=\`echo "\$1" | sed -e 's/--prefix=//'\`
		warn "Only one destination parameter found, all files will be installed to \${str_paramprefix}"
		warn \'Do you want to continue [y/n]?\'
		read continue
		if test "\${continue}" != 'y' && test "\${continue}" != 'Y'
		then error abort
		else shift
		fi
	    elif test -z "\$4"
	    then error missing
	    else
		str_paramwrapper="\$1"
		str_paramdoc="\$2"
		str_paramshare="\$3"
		str_paramman="\$4"
		shift 4
	    fi
	else error conflict
	fi
	;;

    DESTDIR=*)
	    param=\`echo "\$1" | sed -e 's/DESTDIR=//'\`
	    shift
	    test "\${param}" && str_paramdestdir="\$param"
	    ;;

    --DESTDIR=*)
	    param=\`echo "\$1" | sed -e 's/--DESTDIR=//'\`
	    shift
	    test "\${param}" && str_paramdestdir="\$param"
	    ;;

    --prefix=*)
	    param=\`echo "\$1" | sed -e 's/--prefix=//'\`
	    shift
	    if test "\${param}"
	    then
		if test "\$flag_mode" = '--prefix=' ||  test -z "\$flag_mode"
		then
		    flag_mode='--prefix='
		    str_paramprefix="\${param}"
		else error conflict
		fi
	    fi
	    ;;

    --wrapperdir=*)
	    param=\`echo "\$1" | sed -e 's/--wrapperdir=//'\`
	    shift
	    if test "\${param}"
	    then
		if test "\$flag_mode" = '--prefix=' || test -z "\$flag_mode"
		then
		    flag_mode='--prefix='
		    str_paramwrapper="\${param}"
		else error conflict
		fi
	    fi
	    ;;

    --mandir=*)
	    param=\`echo "\$1" | sed -e 's/--mandir=//'\`
	    shift
	    if test "\${param}"
	    then
		if test "\$flag_mode" = '--prefix=' || test -z "\$flag_mode"
		then
		    flag_mode='--prefix='
		    str_paramman="\${param}"
		else error conflict
		fi
	    fi
	    ;;

    --docdir=*)
	    param=\`echo "\$1" | sed -e 's/--docdir=//'\`
	    shift
	    if test "\${param}"
	    then
		if test "\$flag_mode" = '--prefix=' || test -z "\$flag_mode"
		then
		    flag_mode='--prefix='
		    str_paramdoc="\${param}"
		else error conflict
		fi
	    fi
	    ;;

    --operadir=*)
	    param=\`echo "\$1" | sed -e 's/--operadir=//'\`
	    shift
	    test "\${param}" && str_paramopera="\${param}"
	    ;;
 
    --sharedir=*)
	    param=\`echo "\$1" | sed -e 's/--sharedir=//'\`
	    shift
	    if test "\${param}"
	    then
		if test "\$flag_mode" = '--prefix=' || test -z "\$flag_mode"
		then
		    flag_mode='--prefix='
		    str_paramshare="\${param}"
		else error conflict
		fi
	    fi
	    ;;

     *) error invalid;;
esac
done
    debug_msg 1 "flag_mode = \$flag_mode"
}

set_os_spesific()
{
    # This function determines which commands and parameters will work on a given platform.

    case "\$os" in
	AnyBSD)
		cpf='-f'
		if test "\$verbose" -gt '1'
		then
		    chmodv='-v'
		    mkdirv='-v'
		fi
		if test "\$verbose" -gt '0'
		then
		    mvv='-v'
		    cpv='-v'
		fi
	;;

	OpenBSD)
	    cpf='-f'
	    mkdirv=''
	    chmodv=''
	    cpv=''
	    mvv=''
	;;

	Linux)
		cpf='-f'
		if test "\$verbose" -gt "1"
		then
		    chmodv='-v'
		    mkdirv='--verbose'
		else # in case of csh
		    chmodv=''
		    mkdirv=''
		fi
		if test "\$verbose" -gt "0"
		then
		    mvv='-v'
		    cpv='-v'
		else # in case of csh
		    mvv=''
		    cpv=''
		fi
	;;

	*) error os;;
    esac
    debug_msg 1 "cpf = \$cpf"
    debug_msg 1 "cpv = \$cpv"
    debug_msg 1 "chmodv = \$chmodv"
    debug_msg 1 "mkdirv = \$mkdirv"

    # Common
    mkdirp='-p -m 755'
    cpp='-p'
    cpR='-R'
    lns='-s'
}

version()
{
    # This function displays the version information.

    debug_msg 0 'in version()'

    echo "\${str_progname} (Opera Software ASA) 3.98"
    echo 'Maintained by Opera packaging team <packager@opera.com>'
    echo
    echo 'Copyright (C) 2001-2007 Opera Software ASA.'
    echo 'This is free software; there is NO warranty; not even'
    echo 'for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.'
}

con_firm()
{
    str_options="[ y,n | yes,no ]"
    test "\$2" && str_options="[ y,n,c | yes,no,cancel ]"
    echo "\$1 \${str_options} ?"
    while true
    do
      read str_answer
      case "\${str_answer}" in

	    ''|[yY]|[yY][eE][sS])
		return 0
		;;

	    [nN]|[nN][oO])
		return 1
		;;

	    [aAcCqQ]|[aA][bB][oO][rR][tT]|[cC][aA][nN][cC][eE][lL]|[qQ][uU][iI][tT])
		if test "\$2"
		then error abort
		else warn 'Invalid answer, try again:'
		fi
		;;

	    *)
		warn 'Invalid answer, try again:'
		;;

      esac
    done
}

ver_bose()
{
    if test "\${verbose}" = "0"; then return 1; fi
}

select_installation_type()
{
	echo "select_installation_type"

    # This function parses installation flags and sets final installation paths.

    debug_msg 0 'in select_installation_type()'
    debug_msg 1 "flag_mode = \${flag_mode}"

    if test -z "\${flag_mode}"
    then
	if test "\${str_paramdestdir}"
	then flag_mode='--prefix='
	else flag_mode='--interactive'
	fi
    fi

    test "\${operadir}" && opera_dir="\${operadir}"
    test "\${str_paramopera}" && opera_dir="\${str_paramopera}"

    set_prefix "\${prefix}"
    test "\${wrapperdir}"  && wrapper_dir="\${wrapperdir}"
    test "\${docdir}"      && doc_dir="\${docdir}"
    test "\${sharedir}"    && share_dir="\${sharedir}"

    case \$flag_mode in

	--interactive)
	    if ver_bose; then echo 'Running interactive installation...'; fi
	    interactive_install
	    ;;

	--standard)
	    if ver_bose; then echo 'Running standard installation...'; fi
	    set_prefix "\${str_defaultprefix}"
	    set_destdir "\${str_paramdestdir}"
	    ;;

	--force)
	    if ver_bose; then echo 'Running forced installation...'; fi
	    set_prefix "\${str_paramprefix}"
	    set_destdir "\${str_paramdestdir}"
	    ;;

	--prefix=)
	    if ver_bose; then echo 'Running prefixed installation...'; fi
	    set_prefix "\${str_paramprefix}"
	    test "\${str_paramwrapper}"  && wrapper_dir="\${str_paramwrapper}"
	    test "\${str_paramdoc}"      && doc_dir="\${str_paramdoc}"
	    test "\${str_paramman}"      && man_dir="\${str_paramman}"
	    test "\${str_paramshare}"    && share_dir="\${str_paramshare}"
	    set_destdir "\${str_paramdestdir}"
	    ;;
    esac
}

can_write_to()
{
    # This function checks write access on paths
    # Returns (0 true writeable) or (1 false unwriteable)

    # Arg1 = directory to test

    debug_msg 0 'in can_write_to()'
    for arg # implicitly in "\$@"
    do
	debug_msg 1 " \$arg"
	test_folder="\$arg"

	# If directory doesn't exist go up once and test again
	while test ! -d "\${test_folder}"
	do
	    temp_folder=\`echo \${test_folder} | sed -e 's:/[^/]*\$::'\`
	    # If nothing removed, avoid infinite loop
	    if test "\${temp_folder}" = "\${test_folder}"; then break; fi
	    test_folder="\${temp_folder}"
	    debug_msg 1 " \${test_folder}"
	done

	if test -w "\${test_folder}"
	then
	    debug_msg 1 "User "\${USERNAME}" has write access to [\${test_folder}]"
	else
	    debug_msg 1 "User "\${USERNAME}" can't write to [\${test_folder}]"
	    return 1
	fi
    done
}

confirm_paths()
{
	opera_exec='opera'
	test "\${opera_dir}" && opera_exec="\${opera_dir}/\${opera_exec}"

    while true
    do
      echo
      echo "Files shall be installed as follows:"
      echo "-----------------------------------------------------------"
      echo " Wrapper Script : \${wrapper_dir}"
      echo " Shared files   : \${share_dir}"
      echo " Documentation  : \${doc_dir}"
      echo " Manual page    : \${man_dir}"
	  echo
      echo " Opera executable used by Wrapper Script:"
	  echo "    \${opera_exec}"
      echo "-----------------------------------------------------------"
      if con_firm "Is this correct" "cancel"
      then return 0
      else change_paths
      fi
    done
}

csh_set()
{
    # This funtion enables csh syntax for the set command.
    # Read more at http://zsh.sunsite.dk/Intro/intro_12.html
    eval "\$1\$2\$3"
}

chop()
{
    str_toremove="\$1"
    str_varname="\$2"
    eval str_from=\\$"\${str_varname}"
    str_removed=""

    while test "\$str_toremove"
    do
	str_toremove=\`echo "\${str_toremove}"|sed -e 's/.//'\`
	str_removed="\${str_removed}\`echo "\${str_from}"|sed -e 's/\(.\).*/\1/'\`"
	str_from=\`echo "\${str_from}"|sed -e 's/.//'\`
    done

    test "\${str_removed}" = "\$1" && eval \${str_varname}="\${str_from}"
}

prompt_path()
{
    # This function suggests a path and test new if user changes
    # Arg 1 = type of files
    # Arg 2 = path to test
    # Arg 3 = variable to modify

    if test "\$1" = 'prefix'
    then echo "Enter installation prefix [\${prefix}]"
    else echo "Enter path for the widget \$1 [\$2]"
    fi

    read a_path

    test "\${a_path}" || a_path="\$2"
    while ! can_write_to "\${a_path}"
    do
	echo "User "\${USERNAME}" does not have write access to [\${a_path}]."
	if test "\$1" = 'prefix'
	then echo "Enter installation prefix [\$2]"
	else echo "Enter path for the widget \$1 [\$2]"
	fi
	read a_path
	if test -z "\${a_path}"; then return; fi
    done
    if test "\$1" = 'prefix'
    then set_prefix "\${a_path}"
    else csh_set  "\$3"="\${a_path}"
    fi
}

change_paths()
{
    prompt_path "prefix" "\${prefix}" 'prefix'
    prompt_path "wrapper script" "\${wrapper_dir}" "wrapper_dir"
    prompt_path "shared files" "\${share_dir}" "share_dir"
    prompt_path "documentation" "\${doc_dir}" "doc_dir"
    prompt_path "manual page" "\${man_dir}" "man_dir"
}

interactive_install()
{
    # This function starts of checking if you have access to
    # prefix location
    # default locations (/usr)
    # \${HOME}

    # Test current prefixed locations.
    if test -n "\${prefix}"
    then
	if can_write_to "\${wrapper_dir}" "\${doc_dir}" "\${share_dir}" "\${man_dir}"
	then
	  # Prefix location success -> Recommend prefix install
	    if ver_bose; then echo "User "\${USERNAME}" has write access to current prefixed locations."; fi
	    confirm_paths
	    return
	else
	  # Prefix location failed -> Try default
	    if ver_bose
	    then
		warn "User "\${USERNAME}" does not have write access to current prefixed locations."
		echo "Trying default locations, prefix [\$str_defaultprefix]..."
	    fi
	fi
    fi # prefix

    set_prefix "\${str_defaultprefix}"

    if can_write_to "\${wrapper_dir}" "\${doc_dir}" "\${share_dir}" "\${man_dir}"
    then
	    # Default location success -> Recommend standard install
	if ver_bose; then echo "User "\${USERNAME}" has write access to default locations. Prefix [\${prefix}]"; fi
    else
	    # Default location failed -> Try other prefixes
	if ver_bose; then warn "User "\${USERNAME}" does not have write access to default locations. Prefix [\${prefix}]"; fi
	if test -z "\${HOME}"
	then
	    warn " \$str_progname: Enviroment variable "\${HOME}" not set, user "\${USERNAME}" has no homefolder?"
	    warn "Not trying locations with prefix [~/.]"
	else
	    if ver_bose; then warn "Trying prefix [\${HOME}]..."; fi
	    set_prefix "\${HOME}"

	    if can_write_to "\${wrapper_dir}" "\${doc_dir}" "\${share_dir}" "\${man_dir}"
	    then
		# Prefix [~/.] success -> Recommend home install
		if ver_bose; then echo "User "\${USERNAME}" has write access to locations with prefix [\${prefix}]."; fi
	    fi
	fi
    fi
    confirm_paths
}


generate_wrapper()
{
    # This function generates the wrapper script with correct opera path

    debug_msg 0 "in generate_wrapper()"

	if test "\$opera_dir"
	then
		CMD='(cd '\$opera_dir'; exec "\$@" ./opera -pd "\$HOME/.$PACKNAME" -widget "'\$share_dir'/config.xml")'
	else
		CMD='exec opera "\$@" -pd "\$HOME/.$PACKNAME" -widget "'\$share_dir'/config.xml"'
	fi

	cat << STOP
#!/bin/sh
skipnext=false
for arg; do
	if \\\$skipnext; then
		skipnext=false
		continue
	fi
	case "\\\$arg" in
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
			echo "Unrecognized option: \\\$arg" >&2
			exit 1
			;;
	esac
done
if \\\$skipnext; then
	echo "Missing argument to \\\$arg" >&2
	exit 1
fi
\$CMD
STOP
}

manifest_path ()
{
    grep "\$1"'$' Manifest.md5 | sed -e 's/[^ ]*  *//' -e "s:/\$1"'$::'
}

manifest_select ()
{
    grep " \$1/" Manifest.md5 | sed -e "s! \$1/! !"
}

part_install()
{
    debug_msg 1 \$3
    manifest_select "\$1" | while read md5 file
    do
      if test -f "\$1/\$file"
      then rm -f "\$2/\$file"
      else warn "Missing file \$f"
      fi
    done
    mkdir \$mkdirv \$mkdirp "\$2"
    files="\`manifest_select \$1 | while read md5 file; do echo \$file; done\`"
    export files
    if [ "\$files" ]
    then ( cd "\$1"; tar cf - \$files ) | ( cd "\$2"; tar xof - )
    else warn "No files to copy from \$1 to \$2"; grep "\$1" Manifest.md5 >&2
    fi
}

if type md5sum >/dev/null 2>&1
then md5check () { md5sum -c "\$@"; }
elif type md5 >/dev/null 2>&1
then md5check () {
	cat "\$@" | while read md5 file
	do got=\`md5 -q \$file\`
	  if [ "\$got" != "\$md5" ]
	  then warn "\$file FAILED md5 check: \$got != \$md5"
	  fi
	done
}
else md5check () { warn "No md5sum or md5 available with which to check manifest"; }
fi

run_install()
{
    # This function copies files to selected locations and

    debug_msg 0 "in run_install()"

    can_write_to \${wrapper_dir} || error access \${wrapper_dir}
    can_write_to \${doc_dir} || error access \${doc_dir}
    can_write_to \${man_dir} || error access \${man_dir}
    can_write_to \${share_dir} || error access \${share_dir}

	# Check md5 sums

	md5check Manifest.md5

	# Manual pages

	part_install "\`manifest_path man1/$PACKNAME.1.gz\`" "\$man_dir" "Manual page"

	# Shared resources

	share_src="\`manifest_path 'index.html'\`"
	part_install "\$share_src" "\$share_dir" "Shared resources"

	# Wrapper script

    debug_msg 1 "Wrapper"
    mkdir \$mkdirv \$mkdirp \$wrapper_dir/
    generate_wrapper > \$wrapper_dir/$PACKNAME
    chmod \$chmodv 755 \$wrapper_dir/$PACKNAME

    if ver_bose
    then
	echo
	echo 'Installation completed. Enjoy !'
	if test "\$flag_mode" = "--prefix="
	then
	    echo
	    echo "You've completed a prefixed installation."
	    echo
	else
	    if test "\$flag_mode" = "--force"
	    then
		echo
		echo "You\'ve completed a forced installation."
		echo
	    fi
	fi
	warn "Be sure to include \$wrapper_dir in your PATH or invoke it as"
	warn "\$wrapper_dir/$PACKNAME or ./$PACKNAME; and include \$man_path in your MANPATH"
	warn "to make 'man $PACKNAME' work, or invoke 'man -M \$man_path $PACKNAME'"
    fi # ver_bose
}

echo test | sed -n -e 's/test//' || error sed

# AnyBSD systems don't have \$USERNAME by default
if test -z "\${USERNAME}" && test "\${USER}"
then
    USERNAME="\${USER}"
    debug_msg 0 "setting USERNAME to \${USER}"
fi

check_prefixes "\$@"
select_installation_type
set_os_spesific
run_install
exit 0
SEP
}
