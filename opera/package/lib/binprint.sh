# -*- mode: sh -*-

binprint_i8()
{
	local v
	for v; do
		printf "$(printf \\%o $v)"
	done
}

binprint_i16be()
{
	local v
	for v; do
		set $(($v / 256)) $(($v % 256))
		printf "$(printf \\%o\\%o $*)"
	done
}

binprint_i32be()
{
	local v
	for v; do
		set $(($v / 65536)) $(($v % 65536))
		set $(($1 / 256)) $(($1 % 256)) $(($2 / 256)) $(($2 % 256))
		printf "$(printf \\%o\\%o\\%o\\%o $*)"
	done
}

binprint_sz()
{
	printf '%s\0' "$@"
}

# second parameter is max length of string
binprint_sz_const()
{
	binprint_sz $1
	idx=0
	upper=`expr $2 - ${#1} - 1`
	while [ "$idx" -lt "$upper" ]
	do
		printf '\0'
		idx=`expr $idx + 1`
	done
}

binprint_hex()
{
	local v t t2 fmt data
	fmt=''
	data=''
	for v; do
		t=$v
		while [ -n "$t" ]; do
			t2=${t#??}
			fmt=$fmt'\%o'
			data=$data' '0x${t%$t2}
			t=$t2
		done
	done
	printf "$(printf $fmt $data)"
}
