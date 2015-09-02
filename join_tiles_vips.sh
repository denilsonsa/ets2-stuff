#!/bin/bash

cat << EOF

Although this script kinda works, it is not very fast.

Prefer using the nip2 version.

EOF

exit 1

tilename() {
	col="$1"
	row="$2"
	# Customize regarding your need.
	echo "4/${row}/${col}.png"
}

echo_run() {
	echo -E "$@"
	"$@"
}

output_transparent_pixel() {
	# 1x1 transparent PNG image, 70 bytes total.
	echo -ne '\x89\x50\x4e\x47\x0d\x0a\x1a\x0a\x00\x00\x00\x0d\x49\x48'
	echo -ne '\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00'
	echo -ne '\x00\x1f\x15\xc4\x89\x00\x00\x00\x0d\x49\x44\x41\x54\x08'
	echo -ne '\xd7\x63\x60\x60\x60\x60\x00\x00\x00\x05\x00\x01\x5e\xf3'
	echo -ne '\x2a\x3a\x00\x00\x00\x00\x49\x45\x4e\x44\xae\x42\x60\x82'
}

tmp1_file="tmp1.png"
tmp2_file="tmp2.png"

output_final="output.png"
#output_transparent_pixel > "${output_final}"
vips im_black "${output_final}" 1 1 4

for (( row = 0 ; row < 200 ; ++row )) ; do
	first_tile=`tilename 0 ${row}`
	[ -f "${first_tile}" ] || break

	output_row="row_${row}.png"
	#output_transparent_pixel > "${output_row}"
	vips im_black "${output_row}" 1 1 4

	for (( col = 0 ; col < 200 ; ++col )) ; do
		next_tile=`tilename ${col} ${row}`
		[ -f "${next_tile}" ] || break

		# https://stackoverflow.com/questions/32337500/
		#vips insert "${output_row}" "${next_tile}" "${output_row}" $(( col * 256 )) 0 --expand --background '0 0 0'

		# Converting to RGBA.
		convert "${next_tile}" "png32:${tmp1_file}"

		# Temporary file because vips can't read and write from/to the same file.
		cp -a "${output_row}" "${tmp2_file}"
		vips insert "${tmp2_file}" "${tmp1_file}" "${output_row}" $(( col * 256 )) 0 --expand --background '0 0 0 0'
	done

	cp -a "${output_final}" "${tmp2_file}"
	vips insert "${tmp2_file}" "${output_row}" "${output_final}" 0 $(( row * 256 )) --expand --background '0 0 0 0'
done
