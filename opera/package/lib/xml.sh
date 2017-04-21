# -*- mode: sh -*-

xml_parse()
{
	local state line char content ent tagname nesting haschildren
	state=outside
	line=''
	content=''
	nesting=''
	haschildren=false
	while true; do
		if [ -z "$line" ]; then
			char="
"
		else
			char=$(printf '%s\n' "$line" | cut -c 1)
		fi
		case "$state:$char" in
			outside:'<')
				state=intag
				;;
			outside:'&')
				state=ent
				ent=''
				;;
			outside:*)
				content=$content$char
				;;
			ent:[a-z])
				ent=$ent$char
				;;
			ent:';')
				content=$content$(xml_expandent "$ent")
				state=outside
				;;
			ent:*)
				content=$content'&'$ent
				state=outside
				;;
			intag:'?')
				state=tagskip
				;;
			intag:'!')
				state=comment1
				;;
			intag:[a-zA-Z])
				tagname=$char
				state=tagname
				;;
			intag:/)
				if ! $haschildren; then
					eval $nesting='$content'
				fi
				nesting=${nesting%_*}
				haschildren=true
				state=tagskip
				;;
			intag:*)
				;;
			tagname:[_a-zA-Z0-9])
				tagname=$tagname$char
				;;
			tagname:-)
				;;
			tagname:/)
				nesting=$nesting${nesting:+_}$tagname
				eval $nesting=
				nesting=${nesting%_*}
				haschildren=true
				state=tagskip
				;;
			tagname:'>')
				nesting=$nesting${nesting:+_}$tagname
				haschildren=false
				content=''
				state=outside				
				;;
			tagname:*)
				nesting=$nesting${nesting:+_}$tagname
				haschildren=false
				state=tagskip
				;;
			tagskip:/)
				eval $nesting=
				nesting=${nesting%_*}
				haschildren=true
				;;
			tagskip:'>')
				content=''
				state=outside
				;;
			tagskip:*)
				;;
			comment1:-)
				state=comment2
				;;
			comment2:-)
				state=comment3
				;;
			comment3:-)
				state=comment4
				;;
			comment4:-)
				state=comment5
				;;
			comment4:*)
				state=comment3
				;;
			comment5:-)
				state=comment2
				;;
			comment5:'>')
				state=outside
				;;
		esac
		if [ -z "$line" ]; then
			if ! read -r line; then
				break
			fi
		else
			line=$(printf '%s\n' "$line" | cut -c 2-)
		fi
	done
}

xml_expandent()
{
	case $1 in
		lt)
			echo '<'
			;;
		gt)
			echo '>'
			;;
		amp)
			echo '&'
			;;
		quot)
			echo '"'
			;;
		*)
			echo "&$1;"
			;;
	esac
}
