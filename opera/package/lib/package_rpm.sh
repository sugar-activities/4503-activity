# -*- mode: sh -*-

# TODO use $(( )) instead of $[ ] whenever possible; don't forget about spaces around operators

rpm_lead_section() 
{
	printf "\355\253\356\333"	# magic
	binprint_i8 3				# major
	binprint_i8 0				# minor
	binprint_i16be 0			# type
	binprint_i16be 1 			# arch
	binprint_sz_const "$1" 66	# name
	binprint_i16be 1 			# osnum
	binprint_i16be 5			# signature type
	binprint_sz_const '' 16		# reserved
}


rpm_header_record()
{
	# first parameter is number of index records following this header
	# second parameter is size (bytes) of the storage area for data pointed
	# by index records
	printf "\216\255\350\001"	# magic
	printf "\000\000\000\000"	# reserved
	binprint_i32be $1			# nindex
	binprint_i32be $2			# hsize
}


rpm_type()
{
	case $1 in
		CHAR)			binprint_i32be 1 ;;
		INT8)			binprint_i32be 2 ;;
		INT16)			binprint_i32be 3 ;;
		INT32)			binprint_i32be 4 ;;
		INT64)			binprint_i32be 5 ;;
		STRING)			binprint_i32be 6 ;;
		BIN)			binprint_i32be 7 ;;
		STRING_ARRAY)	binprint_i32be 8 ;;
		I18NSTRING)		binprint_i32be 9 ;;
	esac
}


rpm_dep_attr()
{
	local t r=0x0
	for t; do
		case $t in
			LESS)			r=$(($r+0x02)) ;;
			GREATER)		r=$(($r+0x04)) ;;
			EQUAL)			r=$(($r+0x08)) ;;
			PREREQ)			r=$(($r+0x40)) ;;
			INTERP)			r=$(($r+0x100)) ;;
			SCRIPT_PRE)		r=$(($r+0x200)) ;;
			SCRIPT_POST)	r=$(($r+0x400)) ;;
			SCRIPT_PREUN)	r=$(($r+0x800)) ;;
			SCRIPT_POSTUN)	r=$(($r+0x1000)) ;;
			UNKNOWN)		r=$(($r+0x4000)) ;; # TODO: comment this one; this value was taken from generated rpm
			RPMLIB)			r=$(($r+0x1000000)) ;;
		esac
	done
	printf "$r "
}


rpm_store_padding()
{
	local type=$1 offset=$2
	case $type in
		# looks like values of type INT32 have additional padding to 4th byte
		# (looking at file offset, not relative payload one)
		INT32)
			padding=$((4-$offset%8))
			#binprint_sz_const '' $padding
			;;
	esac
}


rpm_store()
{
	local type=$1 store=$2
	case $type in
		CHAR)
			printf "%c" '$store' ;;
		INT8)
			binprint_i8 $store ;;
		INT16)
			binprint_i16be $store ;;
		INT32)
			binprint_i32be $store ;;
		# INT64)
		# TODO: fail here? spec says: not supported yet
		#	binprint_i32be $store ;;
		STRING)
			binprint_sz "$store" ;;
		BIN)
			binprint_hex $store ;;
		STRING_ARRAY)
			# FIXME string_array expects different type of input than every other type, fix it
			cat $store ;;
		I18NSTRING)
			binprint_sz "$store" ;;
	esac
}


rpm_print_ir()
{
	binprint_i32be $1	# tag
	rpm_type $2			# type
	binprint_i32be $3	# offset
	binprint_i32be $4	# count
}


rpm_print_irh()
{
	# count offset
	# FIXME: update offset instead of recounting it each time
	local offset=$(du -b -s $hd_store | cut -f1)
	rpm_store_padding $1 $offset	>> $hd_store

	# offset needs recounting - in case if padding added additional bytes #FIXME - remove recounting for future use
	local offset=$(du -b -s $hd_store | cut -f1) 
	rpm_print_ir $1 $2 $offset $4	>> $hd_index
	rpm_store $2 "$3"				>> $hd_store

	rpm_tags_count=$(($rpm_tags_count+1))
}


# TODO: this has different parameters than rpm_index_record, FIXME (there)
rpm_index_hdrecord()
{
	local tag=$1 store=$2 count=$3

	case $tag in
		RPMTAG_HEADERI18NTABLE)
			rpm_print_irh 100 STRING_ARRAY "$store" "$count" #
			;;

		# package info tag values
		RPMTAG_NAME)
			rpm_print_irh 1000 STRING "$store" 1 # Required
			;;
		RPMTAG_VERSION)
			rpm_print_irh 1001 STRING "$store" 1 # Required
			;;
		RPMTAG_RELEASE)
			rpm_print_irh 1002 STRING "$store" 1 # Required
			;;
		RPMTAG_SUMMARY)
			rpm_print_irh 1004 I18NSTRING "$store" 1 # Required
			;;
		RPMTAG_DESCRIPTION)
			rpm_print_irh 1005 I18NSTRING "$store" 1 # Required
			;;
		RPMTAG_BUILDTIME)
			rpm_print_irh 1006 INT32 "$store" 1 # Informational 
			;;
		RPMTAG_SIZE)
			rpm_print_irh 1009 INT32 "$store" 1 # Required
			;;
		RPMTAG_DISTRIBUTION)
			rpm_print_irh 1010 STRING "$store" 1 # Informational
			;;
		RPMTAG_VENDOR)
			rpm_print_irh 1011 STRING "$store" 1 # Informational
			;;
		RPMTAG_LICENSE)
			rpm_print_irh 1014 STRING "$store" 1 # Required
			;;
		RPMTAG_PACKAGER)
			rpm_print_irh 1015 STRING "$store" 1 # Informational
			;;
		RPMTAG_GROUP)
			rpm_print_irh 1016 I18NSTRING "$store" 1 # Required
			;;
		RPMTAG_URL)
			rpm_print_irh 1020 STRING "$store" 1 # Informational
			;;
		RPMTAG_OS)
			rpm_print_irh 1021 STRING "$store" 1 # Required
			;;
		RPMTAG_ARCH)
			rpm_print_irh 1022 STRING "$store" 1 # Required
			;;
		RPMTAG_SOURCERPM)
			rpm_print_irh 1044 STRING "$store" 1 # Informational
			;;
		RPMTAG_ARCHIVESIZE)
			rpm_print_irh 1046 INT32 "$store" 1 # Optional
			;;
		RPMTAG_RPMVERSION)
			rpm_print_irh 1064 STRING "$store" 1 # Informational
			;;
		RPMTAG_COOKIE)
			rpm_print_irh 1094 STRING "$store" 1 # Optional
			;;
		RPMTAG_DISTURL)
			rpm_print_irh 1123 STRING "$store" 1 # Informational
			;;
		RPMTAG_PAYLOADFORMAT)
			rpm_print_irh 1124 STRING "$store" 1 # Required
			;;
		RPMTAG_PAYLOADCOMPRESSOR)
			rpm_print_irh 1125 STRING "$store" 1 # Required
			;;
		RPMTAG_PAYLOADFLAGS)
			rpm_print_irh 1126 STRING "$store" 1 # Required
			;;

		# installation Tag Values
		RPMTAG_PREIN)
			rpm_print_irh 1023	STRING	"$store" 1 # Optional
			;;
		RPMTAG_POSTIN)
			rpm_print_irh 1024	STRING	"$store" 1 # Optional
			;;
		RPMTAG_PREUN)
			rpm_print_irh 1025	STRING	"$store" 1 # Optional
			;;
		RPMTAG_POSTUN)
			rpm_print_irh 1026	STRING	"$store" 1 # Optional
			;;
		RPMTAG_PREINPROG)
			rpm_print_irh 1085	STRING	"$store" 1 # Optional
			;;
		RPMTAG_POSTINPROG)
			rpm_print_irh 1086	STRING	"$store" 1 # Optional
			;;
		RPMTAG_PREUNPROG)
			rpm_print_irh 1087	STRING	"$store" 1 # Optional
			;;
		RPMTAG_POSTUNPROG)
		 rpm_print_irh 1088	STRING	"$store" 1 # Optional
			;;

		# File Info Tag Values
		# count field for these are actually number of files in payload
		RPMTAG_OLDFILENAMES)
			rpm_print_irh 1027 STRING_ARRAY "$store" "$count" # Optional
			;;
		RPMTAG_FILESIZES)
			rpm_print_irh 1028 INT32 "$store" "$count" # Required
			;;
		RPMTAG_FILEMODES)
			rpm_print_irh 1030 INT16 "$store" "$count" # Required
			;;
		RPMTAG_FILERDEVS)
			rpm_print_irh 1033 INT16 "$store" "$count" # Required
			;;
		RPMTAG_FILEMTIMES)
			rpm_print_irh 1034 INT32 "$store" "$count" # Required
			;;
		RPMTAG_FILEMD5S)
			rpm_print_irh 1035 STRING_ARRAY "$store" "$count" # Required
			;;
		RPMTAG_FILELINKTOS)
			rpm_print_irh 1036 STRING_ARRAY "$store" "$count" # Required
			;;
		RPMTAG_FILEFLAGS)
			rpm_print_irh 1037 INT32 "$store" "$count" # Required
			;;
		RPMTAG_FILEUSERNAME)
			rpm_print_irh 1039 STRING_ARRAY "$store" "$count" # Required
			;;
		RPMTAG_FILEGROUPNAME)
			rpm_print_irh 1040 STRING_ARRAY "$store" "$count" # Required
			;;
		RPMTAG_FILEDEVICES)
			rpm_print_irh 1095 INT32 "$store" "$count" # Required
			;;
		RPMTAG_FILEINODES)
			rpm_print_irh 1096 INT32 "$store" "$count" # Required
			;;
		RPMTAG_FILELANGS)
			rpm_print_irh 1097 STRING_ARRAY "$store" "$count" # Required
			;;
		RPMTAG_DIRINDEXES)
			rpm_print_irh 1116 INT32 "$store" "$count" # Optional
			;;
		RPMTAG_BASENAMES)
			rpm_print_irh 1117 STRING_ARRAY "$store" "$count" # Optional
			;;
		RPMTAG_DIRNAMES)
			rpm_print_irh 1118 STRING_ARRAY "$store" "$count" # Optional
			;;

		# Package Dependency Tag Values 
		RPMTAG_FILEVERIFYFLAGS)
			rpm_print_irh 1045 INT32 "$store" "$count"  # ?
			;;
		RPMTAG_PROVIDENAME)
			rpm_print_irh 1047 STRING_ARRAY "$store" 1 # Required
			;;
		RPMTAG_REQUIREFLAGS)
			rpm_print_irh 1048 INT32 "$store" "$count" # Required
			;;
		RPMTAG_REQUIRENAME)
			rpm_print_irh 1049 STRING_ARRAY "$store" "$count" # Required
			;;
		RPMTAG_REQUIREVERSION)
			rpm_print_irh 1050 STRING_ARRAY "$store" "$count" # Required
			;;
		RPMTAG_CONFLICTFLAGS)
			rpm_print_irh 1053 INT32 "$store" "$count" # Optional
			;;
		RPMTAG_CONFLICTNAME)
			rpm_print_irh 1054 STRING_ARRAY "$store" "$count" # Optional
			;;
		RPMTAG_CONFLICTVERSION)
			rpm_print_irh 1055 STRING_ARRAY "$store" "$count" # Optional
			;;
		RPMTAG_OBSOLETENAME)
			rpm_print_irh 1090 STRING_ARRAY "$store" "$count" # Optional
			;;
		RPMTAG_PROVIDEFLAGS)
			rpm_print_irh 1112 INT32 "$store" "$count" # Required
			;;
		RPMTAG_PROVIDEVERSION)
			rpm_print_irh 1113 STRING_ARRAY "$store" "$count" # Required
			;;
		RPMTAG_OBSOLETEFLAGS)
			rpm_print_irh 1114 INT32 "$store" 1
			;;
		RPMTAG_OBSOLETEVERSION)
			rpm_print_irh 1115 STRING_ARRAY "$store" "$count" # Optional
			;;

	esac
}


# this function prints values that has to be somehow specially printed
rpm_index_hdrecord_special ()
{
	local tag=$1
	case $tag in
		# Other Tag Values
		RPMTAG_BUILDHOST)
			# minimum string length of 8 bytes (including following zero)
			rpm_print_irh 1007 STRING "0123456" 1 # FIXME: print correct hostname here
			;;
	esac
}


rpm_index_record()
{
	local tag=$1 offset=$2 count=$3

	case $tag in

		# header private tag values
		RPMTAG_HEADERSIGNATURES)
			rpm_print_ir 62 BIN $offset 16
			;;
		RPMTAG_HEADERIMMUTABLE)
			rpm_print_ir 63 BIN $offset 16
			;;

		# signature tag values
		RPMSIGTAG_SIZE)
			rpm_print_ir 1000 INT32 $offset 1
			;;
		RPMSIGTAG_PAYLOADSIZE)
			rpm_print_ir 1007 INT32 $offset 1
			;;

		# signature digest tag values
		RPMSIGTAG_SHA1)
			rpm_print_ir 269 STRING $offset 1
			;;
		RPMSIGTAG_MD5)
			rpm_print_ir 1004 BIN $offset 16
			;;
	esac
}


# TODO merge mybinprint and md5_bin functions
mybinprint()
{
	local tmp=$1
	while [ -n "$tmp" ]; do
		suffix=${tmp#??}
		printf "\x${tmp%$suffix}"
		#printf "\xff"
		tmp=$suffix
	done
}


md5_bin()
{
	local out=$(md5sum $1)
	local hex=${out%%\ *}
	mybinprint $hex
}

padding()
{
	local offset=$(wc -c $1 | awk '{ print $1 }')
	seek=$(( 8 - ($offset % 8) ))
	binprint_sz_const '' $seek
}

rpm_signature_section()
{
	# index array:
	rpm_header_record 5 84
	rpm_index_record RPMTAG_HEADERSIGNATURES 68
	rpm_index_record RPMSIGTAG_SHA1 0
	rpm_index_record RPMSIGTAG_SIZE 44
	rpm_index_record RPMSIGTAG_MD5 48
	rpm_index_record RPMSIGTAG_PAYLOADSIZE 64

	# store:
	binprint_sz_const "$2" 44
	
 	# uncompressed size of the payload archive
	binprint_i32be $(du -b -s $TEMPAREA/tree.cpio | cut -f1)

	# 16 bytes - 128-bit MD5 checksum of the combined
	# Header and Archive sections.
	md5_bin "$1"

	# size of the combined Header and Archive sections.
	binprint_i32be $(du -b -s "$1" | cut -f1)

	# headersignatures
	printf "\x00\x00\x00\x3e\x00\x00\x00\x07\xff\xff\xff\xb0\x00\x00\x00\x10"
}


# this tag has to be appended to beginning of header section 
# and to end of payload section
rpm_generate_headerimmutable_tag ()
{
	local offset=$(du -b -s $hd_store | cut -f1)
	rpm_index_record RPMTAG_HEADERIMMUTABLE $offset > $hd_immutable
	rpm_tags_count=$(($rpm_tags_count+1))
	# rpm_index_record RPMTAG_HEADERIMMUTABLE 0 >> $hd_store # -944 actually means something here - for widgets containing very few files this value is larger
	printf "\x00\x00\x00\x3f\x00\x00\x00\x07\xff\xff\xfc\x50\x00\x00\x00\x10" >> $hd_store
}


rpm_header_section()
{
	# index is file con
	local hd_immutable=$TEMPAREA/hd_immutable
	local hd_index=$TEMPAREA/hd_index 
	local hd_store=$TEMPAREA/hd_store
	local rpm_tags_count=0

	touch $hd_immutable
	touch $hd_index
	touch $hd_store

	# HEADERIMMUTABLE
	printf "C\0" >> $METADIR/i18ntable
	rpm_index_hdrecord RPMTAG_HEADERI18NTABLE	$METADIR/i18ntable 1

	rpm_index_hdrecord RPMTAG_NAME				"$(cat $METADIR/package-name)"
	rpm_index_hdrecord RPMTAG_VERSION			"$(cat $METADIR/version)"
	rpm_index_hdrecord RPMTAG_RELEASE   		"0"
	rpm_index_hdrecord RPMTAG_SUMMARY			"$(cat $METADIR/description-short)"
	rpm_index_hdrecord RPMTAG_DESCRIPTION		"$(cat $METADIR/description-long)"
	rpm_index_hdrecord RPMTAG_BUILDTIME			"$(date +%s)"
	rpm_index_hdrecord_special RPMTAG_BUILDHOST
    rpm_index_hdrecord RPMTAG_SIZE				"$(cat $METADIR/filessize)" # $(du -b -s $OUTDIR | cut -f1) #FIXME why wrong value?
	# rpm_index_hdrecord RPMTAG_VENDOR			"Opera Widget" # not required

	# ======= fixed tags order ===========

	# FIXME this license description is temporary and probably should be changed
	# to something different; to get list of licenses preferred by rpm:
	# change this value and run rpmlint on generated package
	rpm_index_hdrecord RPMTAG_LICENSE			"Freely redistributable without restriction"

	# prepare index and store values
	rpm_index_hdrecord RPMTAG_GROUP				"Amusements/Graphics" # FIXME
	rpm_index_hdrecord RPMTAG_URL				"$(cat $METADIR/homepage)"

	rpm_index_hdrecord RPMTAG_OS				"linux"
	rpm_index_hdrecord RPMTAG_ARCH				"noarch"

	rpm_index_hdrecord RPMTAG_PREIN				"exit 0"
	rpm_index_hdrecord RPMTAG_POSTIN			"exit 0"
	rpm_index_hdrecord RPMTAG_PREUN				"exit 0"
	rpm_index_hdrecord RPMTAG_POSTUN			"exit 0"

	#printf "\0\0\0" >> $hd_store # TODO: investigate bugfix; rpm appends 3 bytes \0 while generating from specfile

	local nofiles=$(cat $METADIR/nofiles) nodirs=$(cat $METADIR/nodirs)
	rpm_index_hdrecord RPMTAG_FILESIZES			"$(cat $METADIR/sizes)"		$nofiles
	rpm_index_hdrecord RPMTAG_FILEMODES			"$(cat $METADIR/filemodes)" $nofiles
	rpm_index_hdrecord RPMTAG_FILERDEVS			"$(cat $METADIR/rdevs)"		$nofiles # does it work?
	rpm_index_hdrecord RPMTAG_FILEMTIMES		"$(cat $METADIR/mtimes)"	$nofiles
	rpm_index_hdrecord RPMTAG_FILEMD5S			$METADIR/md5s				$nofiles
	rpm_index_hdrecord RPMTAG_FILELINKTOS		$METADIR/linktos			$nofiles

	#printf "\0\0" >> $hd_store # TODO: investigate bugfix;

	rpm_index_hdrecord RPMTAG_FILEFLAGS			"$(cat $METADIR/fileflags)" $nofiles #FIXME this should not be constant # really?
	rpm_index_hdrecord RPMTAG_FILEUSERNAME		$METADIR/usernames $nofiles
	rpm_index_hdrecord RPMTAG_FILEGROUPNAME		$METADIR/groupnames $nofiles

	#rpm_index_hdrecord RPMTAG_FILEVERIFYFLAGS	"" 2 # "$(cat $METADIR/verifyflags)" $nofiles
	# this prints -1: printf "\xff\xff\xff\xff" >> $hd_store

	printf "%s\0" $(cat $METADIR/package-name) > $METADIR/package-name-z
	rpm_index_hdrecord RPMTAG_PROVIDENAME		"$METADIR/package-name-z"

	#printf "\0\0" >> $hd_store # TODO: investigate bugfix; rpm appends 2 bytes \0 while generating from specfile

	# dependencies info:
	printf "/bin/sh\0"						>> $METADIR/requirements
	rpm_dep_attr INTERP SCRIPT_PRE			>> $METADIR/reqflags
	printf "\0"								>> $METADIR/requirever

	printf "/bin/sh\0"						>> $METADIR/requirements
	rpm_dep_attr INTERP SCRIPT_POST			>> $METADIR/reqflags
	printf "\0"								>> $METADIR/requirever

	printf "/bin/sh\0"						>> $METADIR/requirements
	rpm_dep_attr INTERP SCRIPT_PREUN		>> $METADIR/reqflags
	printf "\0"								>> $METADIR/requirever

	printf "/bin/sh\0"						>> $METADIR/requirements
	rpm_dep_attr INTERP SCRIPT_POSTUN		>> $METADIR/reqflags
	printf "\0"								>> $METADIR/requirever

	printf "/bin/sh\0"						>> $METADIR/requirements
	rpm_dep_attr UNKNOWN					>> $METADIR/reqflags
	printf "\0"								>> $METADIR/requirever

	printf "opera\0"						>> $METADIR/requirements # FIXME should be opera-widget-runtime
	rpm_dep_attr							>> $METADIR/reqflags 
	printf "\0"								>> $METADIR/requirever

	printf "rpmlib(CompressedFileNames)\0"		>> $METADIR/requirements
	rpm_dep_attr RPMLIB EQUAL LESS				>> $METADIR/reqflags
	printf "3.0.4-1\0"							>> $METADIR/requirever

	printf "rpmlib(FileDigests)\0"				>> $METADIR/requirements
	rpm_dep_attr RPMLIB EQUAL LESS				>> $METADIR/reqflags
	printf "4.6.0-1\0"							>> $METADIR/requirever

	printf "rpmlib(PayloadFilesHavePrefix)\0"	>> $METADIR/requirements
	rpm_dep_attr RPMLIB EQUAL LESS				>> $METADIR/reqflags
	printf "4.0-1\0"							>> $METADIR/requirever

	rpm_index_hdrecord RPMTAG_REQUIREFLAGS		"$(cat $METADIR/reqflags)"	9
	rpm_index_hdrecord RPMTAG_REQUIRENAME		$METADIR/requirements		9
	rpm_index_hdrecord RPMTAG_REQUIREVERSION	$METADIR/requirever			9

	rpm_index_hdrecord RPMTAG_PREINPROG			"/bin/sh"
	rpm_index_hdrecord RPMTAG_POSTINPROG		"/bin/sh"
	rpm_index_hdrecord RPMTAG_PREUNPROG			"/bin/sh"
	rpm_index_hdrecord RPMTAG_POSTUNPROG		"/bin/sh"

	printf "\0" >> $hd_store # TODO: investigate bugfix; rpm appends some bytes here, invalidating following tag
	rpm_index_hdrecord RPMTAG_FILEDEVICES		"$(cat $METADIR/devices)"	$nofiles

	rpm_index_hdrecord RPMTAG_FILEINODES		"$(cat $METADIR/inodes)"	$nofiles
	rpm_index_hdrecord RPMTAG_FILELANGS			$METADIR/filelangs			$nofiles
	rpm_index_hdrecord RPMTAG_PROVIDEFLAGS		"$(rpm_dep_attr EQUAL)"		1

	printf "%s-0\0" $(cat $METADIR/version) > $METADIR/version-z
	rpm_index_hdrecord RPMTAG_PROVIDEVERSION	"$METADIR/version-z" 1
	printf "\0\0" >> $hd_store # TODO: investigate bugfix; rpm appends some bytes here, invalidating following tag

	rpm_index_hdrecord RPMTAG_DIRINDEXES		"$(cat $METADIR/dirindexes)" $nofiles
	rpm_index_hdrecord RPMTAG_BASENAMES			$METADIR/basenames			$nofiles
	rpm_index_hdrecord RPMTAG_DIRNAMES			$METADIR/dirnames			$nodirs

	rpm_index_hdrecord RPMTAG_PAYLOADFORMAT		"cpio"
	rpm_index_hdrecord RPMTAG_PAYLOADCOMPRESSOR	"gzip"
	rpm_index_hdrecord RPMTAG_PAYLOADFLAGS		"9"

	#rpm_generate_headerimmutable_tag

	# count offset
	# FIXME: update offset instead of recounting it each time
	local offset=$(du -b -s $hd_store | cut -f1)

	# offset is size of whole store now
	rpm_header_record $rpm_tags_count $offset
	cat $hd_immutable $hd_index $hd_store
}


rpm_payload_section()
{
	cd $OUTDIR # we want relative paths inside of archive
	##cat $METADIR/cpiocontent | cpio -o --format=newc > tree.cpio
	find ./usr -depth -print | cpio -o --format=newc > $TEMPAREA/tree.cpio
	gzip -c $TEMPAREA/tree.cpio --fast
	# files, that are not supposed to be in package shouldn't stay in outdir
	cd $TEMPAREA
}


# required function
layout_rpm()
{
	cd $OUTDIR # we want relative paths inside of archive
	local tmp
	cd $TEMPAREA
}


rpm_content_tags()
{
	cd $OUTDIR
	local dirs=$(find -type d -printf "%p/ ")
	local d
	local i=0 # number of directories
	local j=0 # number of files
    local size=0

	save_file_stat()
	{
		# 1 - basename
		# 2 - inode
		# 3 - device
		# 4 - size in bytes
		# 5 - modification time in seconds since epoch
		# 6 - filemodes
		# 7 - dir index in dir table
		# 8 - md5 of file
		# username - root
		# groupname - root
		# filerdevs - 0
		# linktos - null
		# fileflags - 0 # this value describes things like licence, doc, etc
		# verifyflags - -1 # this flag controls verification after installation. what does -1 mean?
		# filelangs - null (atm)

		#printf "$d$1\n"	>> $METADIR/cpiocontent
		printf "$1\0"	>> $METADIR/basenames
		printf "$2 "	>> $METADIR/inodes
		printf "$3 "	>> $METADIR/devices
		printf "$4 "	>> $METADIR/sizes
		printf "$5 "	>> $METADIR/mtimes
		printf "$7 "	>> $METADIR/dirindexes
		printf "$8\0"	>> $METADIR/md5s
		printf "root\0"	>> $METADIR/usernames
		printf "root\0"	>> $METADIR/groupnames
		printf "\0"		>> $METADIR/linktos
		printf "0 "		>> $METADIR/rdevs
		printf "0 "		>> $METADIR/fileflags
		printf "\0"		>> $METADIR/filelangs
		printf "%d " 0x$6 >> $METADIR/filemodes
		printf "%d " -1	>> $METADIR/verifyflags #FIXME
        size=$((size+$4))
	}

	# for every directory inside tree
	# list all files in given directory
	# and prepare required rpm tags for each file
	for d in $dirs; do
		ldirs=$(find $d -maxdepth 1 -mindepth 1 -type d -printf "%f ")
		for f in $ldirs; do
			save_file_stat $f $(stat --printf "%i %d %s %Y %f" $TEMPAREA/tree/${d#??}) $i ''
			j=$((j+1))
        done
		files=$(find $d -maxdepth 1 -type f -printf "%f ") # -type f ?
		for f in $files; do
			md5=$(md5sum $d$f | cut -f1)
			save_file_stat $f $(stat --printf "%i %d %s %Y %f" $d$f) $i $md5
			j=$((j+1))
		done
		printf "${d#?}\0" >> $METADIR/dirnames
		i=$((i+1))
	done
    printf $size > $METADIR/filessize
	printf $i > $METADIR/nodirs
	printf $j > $METADIR/nofiles

	cd $TEMPAREA
}


rpm_prepare_specfile()
{
	cat <<- EOF
        %define _topdir $TEMPAREA/rpm

		Name:		$(cat $METADIR/package-name)
		Version:	$(cat $METADIR/version | sed 's/\-/\./g')
		Release:	0
		Summary:	$(cat $METADIR/description-short)
		Group:		Amusements/Graphics
		License:    Freely redistributable without restriction
		URL:		$(cat $METADIR/homepage)
		Requires:	opera
		%description
		$(cat $METADIR/description-long)

		%pre 
		exit 0
		%post 
		exit 0
		%preun 
		exit 0
		%postun 
		exit 0
		%files
		%defattr(-,root,root,-)
		/usr
	EOF
}


# generate package using specfile and rpmbuild
run_rpmbuild()
{
    # check if rpmbuild dir hierarchy already exists (rpmbuild will create it even if we don't
    # use it, so we will have to clean in case it will be generated)
    local cleanup=false
    if [ ! -e $HOME/rpmbuild ]
    then
        cleanup=true
    fi
    mkdir -p $TEMPAREA/rpm/RPMS/noarch

    # generate package
	outpackname=$(cat $METADIR/package-name)-$(cat $METADIR/version | sed 's/\-/\./g')-0.noarch.rpm
	local specfilename="$TEMPAREA/$(cat $METADIR/package-name).spec"
	rpm_prepare_specfile > $specfilename
	rpmbuild -bb --buildroot $TEMPAREA/tree --target=noarch $specfilename > /dev/null

    mv $TEMPAREA/rpm/RPMS/noarch/$outpackname $DESTDIR
	echo -n $DESTDIR/$outpackname

    if $cleanup; then
        rm -r $HOME/rpmbuild
    fi
}


# generate package without rpmbuild
run_shbuild()
{
    unlink $TEMPAREA/tree/usr/share/pixmaps/*
    rmdir $TEMPAREA/tree/usr/share/pixmaps
	rm -r $TEMPAREA/tree/usr/share/man

	# FIXME non-coherent-filename
	# The file which contains the package should be named
	# <NAME>-<VERSION>-<RELEASE>.<ARCH>.rpm # release is shortcut of distribution, eg fc11
	local packagename="$(cat $METADIR/package-name).noarch"
	cd $TEMPAREA

	rpm_lead_section $packagename > $packagename.rpm
	rpm_content_tags # prepares files information in $METADIR
	rpm_header_section	> content
	sha1=$(sha1sum content | cut -f1)
	rpm_payload_section	>> content

	rpm_signature_section content $sha1	>> $packagename.rpm
	padding $packagename.rpm			>> $packagename.rpm
	cat content 						>> $packagename.rpm

	mv $TEMPAREA/$packagename.rpm $DESTDIR
	echo -n "$DESTDIR/$packagename.rpm"
}


# required function
package_rpm()
{
	# rpm specfiles require version to be in dot separated format
	version=$(cat $METADIR/version | sed 's/\-/\./g')
	echo $version > $METADIR/version

    if which rpmbuild > /dev/null ; then
        run_rpmbuild
    else
        run_shbuild
        exit 1
    fi
}

