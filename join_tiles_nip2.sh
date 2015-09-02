#!/bin/bash

tilename() {
	col="$1"
	row="$2"
	# Customize regarding your need.
	echo "../../ets2/tiles/dark_google/6/${row}/${col}.png"
}

echo_run() {
	echo -E "$@"
	"$@"
}

nip2_script() {
	# <<- requires using Tab as indentation.
	cat <<- EOF
	black_rgb = im_black 1 1 3;
	black_rgba = im_black 1 1 4;

	// Getting width:
	// im_header_int "width" img
	// get_width img

	// range is defined in _stdenv.def.
	// range min value max = min_pair max (max_pair min value)

	// Alternative implementation of image_new,
	// if for some reason _generate.def is not available.
	alternative_image_new width height bands pixel
		= out
	{
		// 1x1 black pixel, uchar
		black = im_black 1 1 bands;
		// 1x1 black-or-gray-or-white pixel, float
		white_float = black + pixel;
		// 1x1 black-or-gray-or-white pixel, uchar
		// white = im_clip2fmt white_float 0;
		white = cast_unsigned_char white_float;
		// im_embed <img> <type> <x_offset> <y_offset> <width> <height>
		// type: 1 = extend  http://www.vips.ecs.soton.ac.uk/supported/current/doc/html/libvips/libvips-conversion.html#VipsExtend
		out = im_embed white 1 0 0 width height;
	}

	// https://github.com/jcupitt/libvips/issues/325#issuecomment-136981134
	add_alpha img
		= img, !is_image img
		= img, (get_bands img) == 4
		= out
	{
		// image_new is defined at _generate.def.
		// image_new <width> <height> <bands> <format> <coding> <type> <pixel> <x_offset> <y_offset>
		// format: 0 = 8-bit unsigned int - UCHAR
		// coding: 0 = none
		// type: 0 = multiband; 1 = B_W
		// pixel: 255 = fully opaque
		//alpha = image_new (get_width img) (get_height img) 1 0 0 0 255 0 0;

		alpha = alternative_image_new (get_width img) (get_height img) 1 255;
		out = img ++ alpha;
	}

	remove_alpha img
		= img, !is_image img
		= img, (get_bands img) <= 3
		= im_extract_bands img 0 3;

	get_alpha img
		= im_extract_bands (add_alpha img) 3 1;

	// alpha_blend <img1> <img2> <x> <y> <alpha>
	// Puts <img2> on <img1> at <x>,<y>.
	// Respects RGBA alpha values from both images.
	// Preserves <img1> dimensions.
	// <alpha> is a multiplier for <img2> alpha channel.
	//         Useful values are between 0.0 and 1.0.
	//         It can be used to blend a opaque image in semi-transparent way.
	alpha_blend base stamp x y alpha
		= base, x >= (get_width base)
		= base, y >= (get_height base)
		= base, (x + (get_width stamp)) <= 0
		= base, (y + (get_height stamp)) <= 0
		= out
	{
		// overlay is a transparent image with the same dimensions as the base,
		// with the stamp placed at the desired position. If the stamp does not
		// fit within the bounds, it will be cropped.
		overlay = im_embed stamp 0 x y (get_width base) (get_height base);

		base_alpha    =  (cast_float (get_alpha base   )) / 255;
		overlay_alpha = ((cast_float (get_alpha overlay)) / 255) * (range 0.0 alpha 1.0);

		base_rgb    = (cast_float (remove_alpha base   )) / 255;
		overlay_rgb = (cast_float (remove_alpha overlay)) / 255;

		// https://en.wikipedia.org/wiki/Alpha_compositing#Alpha_blending
		out_alpha = overlay_alpha + (base_alpha * (1 - overlay_alpha));
		out_rgb = ((overlay_rgb * overlay_alpha) + (base_rgb * base_alpha * (1 - overlay_alpha))) / out_alpha;

		out = (cast_unsigned_char (out_rgb * 255)) ++ (cast_unsigned_char (out_alpha * 255));
	}

	// Usage: join_at_xy <img> [ <img> <x> <y> ]
	// If the second <img> is just a zero, then return the first <img> unchanged.
	join_at_xy img meta
		= img, !is_list meta
		= im_insert img meta?0 meta?1 meta?2;

	// Same as join_at_xy, but with reversed parameter order.
	join_at_xy_r meta img
		= join_at_xy img meta;

	// Choose one:
	//main = large_rgb;
	//main = large_rgba;
	main = large_rgb_r;
	//main = large_rgba_r;

	large_rgb  = foldl join_at_xy black_rgb  tiles_rgb;
	large_rgba = foldl join_at_xy black_rgba tiles_rgba;

	large_rgb_r  = foldr join_at_xy_r black_rgb  tiles_rgb;
	large_rgba_r = foldr join_at_xy_r black_rgba tiles_rgba;

	// hd is the list head, just the first element.
	// tl is the list tail, the remaining of the list.
	tiles_rgb  = [ [remove_alpha (hd t)] ++ tl t :: t <- tiles];
	tiles_rgba = [ [add_alpha    (hd t)] ++ tl t :: t <- tiles];

	tiles = init [
	EOF

	for (( row = 0 ; row < 9999 ; ++row )) ; do
		first_tile=`tilename 0 ${row}`
		[ -f "${first_tile}" ] || break

		for (( col = 0 ; col < 9999 ; ++col )) ; do
			next_tile=`tilename ${col} ${row}`
			[ -f "${next_tile}" ] || break

			echo "  [ (vips_image \"${next_tile}\") , $(( col * 256 )) , $(( row * 256 )) ],"
		done
	done
	echo "  \"This element will be ignored and has been added just because the last element cannot be followed by a comma.\" "
	echo "];"
}

# For debugging purposes:
nip2_script | cat -n

# https://github.com/jcupitt/nip2/issues/53
#nip2_script | nip2 --verbose -d -b -o output.png
nip2_script | nip2 --verbose -s /dev/stdin -o output.tif
