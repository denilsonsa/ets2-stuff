#!/bin/bash

tilename() {
	col="$1"
	row="$2"
	# Customize regarding your need.
	echo "5/${row}/${col}.png"
}

echo_run() {
	echo -E "$@"
	"$@"
}

nip2_script() {
	# <<- requires using Tab as indentation.
	cat <<- EOF
	// TODO: use 4 bands instead of 3.
	black = im_black 1 1 3;

	// Usage: joinwithxy <img> [ <img> <x> <y> ]
	// If the second <img> is just a zero, then return the first <img> unchanged.
	joinwithxy img meta
		= img , meta?0 == 0
		= im_insert img meta?0 meta?1 meta?2;

	main = foldl joinwithxy black [
	EOF
	for (( row = 0 ; row < 17 ; ++row )) ; do
		first_tile=`tilename 0 ${row}`
		[ -f "${first_tile}" ] || break

		echo "  [ foldl joinwithxy black ["
		for (( col = 0 ; col < 17 ; ++col )) ; do
			next_tile=`tilename ${col} ${row}`
			[ -f "${next_tile}" ] || break

			echo "    [ (vips_image \"${next_tile}\") , $(( col * 256 )) , 0 ],"
		done

		echo "    [0, 0, 0]"
		echo "  ], 0 , $(( row * 256 )) ],"
	done
	echo "  [0, 0, 0]"
	echo "];"
}

nip2_script | cat -n

#nip2_script | nip2 --verbose -s /dev/stdin -o output.png
