#!/bin/bash
#
# This script joins several screenshots into a large image.
#
# This script uses "nip2" tool, which uses "libvips" library.
#
# "libvips" is an image processing library with low memory needs.
# It can handle 20000x20000 (or larger) images without using too much RAM.
#
# "nip2" is a GUI that includes its own Haskell-like scripting language. It is
# a great way to efficiently work with several images, or large images.
#
# nip2 scripting language follows the functional paradigm. Here is a quick
# summary for people who are not familiar with this language:
#  * Statements can be defined in any order.
#  * Evaluation is lazy.
#  * Function call does not require parenthesis.
#  * Variables/values are immutable.
#  * Computation is done by returning modified versions of the input data.
#  * Strings are lists of characters.
#  * Lists can be indexed using the question mark.
#      foo = [0, 1, 2];
#      // foo?0 is the first element.
#  * As in Lisp and Haskell, the head/tail of the list is widely used:
#      foo = [0, 1, 2];
#      h : t = foo;
#      // h is 0        i.e. the first element
#      // t is [1, 2]   i.e. a list with the remaining elements
#  * Functions can be defined as:
#      foo_function
#        = value_if_first_condition, first_condition
#        = value_if_second_condition, second_condition
#        = default_value
#      {
#        statement;
#        statement;
#      }
#  * List comprehensions can be defined as:
#      foo_new_list = [ element_expression :: input_element <- input_list ];
#      // Or using | instead of "", depending on the version.
#      foo_new_list = [ element_expression | input_element <- input_list ];
#
# Due to nip2 limitations, I decided to write the file list to an external
# instead of writing it inline in the script itself. See:
# https://github.com/jcupitt/nip2/issues/54

generate_file_list() {
	tab=$'\t'
	for f in 'google_map_x='*'_y'=*'.tif' ; do
		x="$(echo "${f}" | sed 's/.*_x=\([0-9]\+\)_.*/\1/')"
		y="$(echo "${f}" | sed 's/.*_y=\([0-9]\+\)\..*/\1/')"

		# x TAB y TAB filename NEWLINE
		echo -E "$(( x ))${tab}$(( y ))${tab}${f}"
	done
}

nip2_script() {
cat << EOF
////////////////////////////////////////////////////////////
// String utils.

is_blank c
	= true, c == ' '
	= true, c == '\t'
	= true, c == '\n'
	= true, c == '\r'
	= false;

is_newline c
	= true, c == '\n'
	= true, c == '\r'
	= false;

is_tab c
	= true, c == '\t'
	= false;

//lstrip s
//	= lstrip (tl s), is_blank (s?0)
//	= s;

lstrip s
	= dropwhile is_blank s;

rstrip s
	= reverse (lstrip (reverse s));

strip s
	= reverse (lstrip (reverse (lstrip s)));

// Based on "split" from _list.def.
// See split_newline for an example.
split_once fn s
	= [], s == []
	= head : tail'
{
	head = takewhile (not @ fn) s;
	tail = dropwhile (not @ fn) s;
	tail'
		= [], tail == []
		= tl tail;
}

split_all fn s
	= [], s == []
	= head : split_all fn tail
{
	head : tail = split_once fn s;
}

// first : rest = split_newline "foo\nbar\nmore"
// first -> "foo"
// rest -> "bar\nmore"
//
// first : rest = split_newline "foo"
// first -> "foo"
// rest -> ""
//
// first : rest = split_newline "\nfoo"
// first -> ""
// rest -> "foo"
split_newline s
	= split_once is_newline s;

// foo = split_newline "\nfoo\nbar\n\nmore\n"
// foo = ["", "foo", "bar", "", "more"]
split_newlines s
	= split_all is_newline s;


////////////////////////////////////////////////////////////
// Alpha channel on images.

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

// Adds an alpha channel (a 4th band) to a 3-band image.
// If the image is 1-band, convert to a 4-band image.
// Otherwise, leaves unchanged.
// Only supports images with pixel range 0..255.
// https://github.com/jcupitt/libvips/issues/325#issuecomment-136981134
add_alpha img
	= img, !is_image img
	= img ++ img ++ img ++ alpha, (get_bands img) == 1
	= img ++ alpha, (get_bands img) == 3
	= img, (get_bands img) == 4
	= img
{
	// image_new is defined at _generate.def.
	// image_new <width> <height> <bands> <format> <coding> <type> <pixel> <x_offset> <y_offset>
	// format: 0 = 8-bit unsigned int - UCHAR
	// coding: 0 = none
	// type: 0 = multiband; 1 = B_W
	// pixel: 255 = fully opaque
	//alpha = image_new (get_width img) (get_height img) 1 0 0 0 255 0 0;

	alpha = alternative_image_new (get_width img) (get_height img) 1 255;
}

// Drops the 4th band, returning a 3-band image.
remove_alpha img
	= img, !is_image img
	= im_extract_bands img 0 3, (get_bands img) == 4
	= img;

// Returns the 4th band of an image.
get_alpha img
	= im_extract_bands (add_alpha img) 3 1;

// alpha_blend <img1> <img2> <x> <y> <alpha>
// Puts <img2> on <img1> at <x>,<y>.
// Respects RGBA alpha values from both images.
// Preserves <img1> dimensions.
// <alpha> is a multiplier for <img2> alpha channel.
//         Useful values are between 0.0 and 1.0.
//         It can be used to blend a opaque image in semi-transparent way.
// Only supports RGB (3 bands) and RGBA (4 bands) images with pixels in range 0..255.
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

	// range is defined in _stdenv.def.
	// range min value max = min_pair max (max_pair min value)

	base_alpha    =  (cast_float (get_alpha base   )) / 255;
	overlay_alpha = ((cast_float (get_alpha overlay)) / 255) * (range 0.0 alpha 1.0);

	base_rgb    = (cast_float (remove_alpha base   )) / 255;
	overlay_rgb = (cast_float (remove_alpha overlay)) / 255;

	// https://en.wikipedia.org/wiki/Alpha_compositing#Alpha_blending
	out_alpha = overlay_alpha + (base_alpha * (1 - overlay_alpha));
	out_rgb = ((overlay_rgb * overlay_alpha) + (base_rgb * base_alpha * (1 - overlay_alpha))) / out_alpha;

	out = (cast_unsigned_char (out_rgb * 255)) ++ (cast_unsigned_char (out_alpha * 255));
}


////////////////////////////////////////////////////////////
// File-handling.

read_file f
	= out
{
	lines_from_file = split_newlines (read f);

	split_fields line
		= [(vips_image filename), (parse_int x), (parse_int y)]
	{
		x : rest = split_once is_tab line;
		y : filename = split_once is_tab rest;
	}

	out = [
		(split_fields line) :: line <- lines_from_file
	];
}

////////////////////////////////////////////////////////////
// Misc.

black_rgb = im_black 1 1 3;
black_rgba = im_black 1 1 4;

// Margin order is the same as in CSS.
// (But it is more like padding than margin.)
crop_margins top right bottom left img
	= im_extract_area img x y w h
{
	x = left;
	y = top;
	w = (get_width img) - (left + right);
	h = (get_height img) - (top + bottom);
}

// Getting width:
// im_header_int "width" img
// get_width img

// Usage: join_at_xy <img> [ <img>, <x>, <y> ]
// If the second <img> is just a zero, then return the first <img> unchanged.
join_at_xy img meta
	= img, !is_list meta
	= im_insert img meta?0 meta?1 meta?2;

// Same as join_at_xy, but with reversed parameter order.
join_at_xy_r meta img
	= join_at_xy img meta;

get_list_of_dimensions metalist
	= [ [((get_width img) + x), ((get_height img) + y)] :: [img, x, y] <- metalist];

// Input: [ [20, 10], [10, 20] ]
// Output: [20, 20]
max_dimensions list
	= [1, 1], list == []
	= [ (max_pair head?0 answer?0), (max_pair head?1 answer?1) ]
{
	head : tail = list;
	answer = max_dimensions tail;
}


// RGB or RGBA?
// Processing the list left-to-right or right-to-left?
// Choose one:

// main = large_rgb;
// large_rgb  = foldl join_at_xy black_rgb  tiles_rgb;

// main = large_rgba;
// large_rgba = foldl join_at_xy black_rgba tiles_rgba;

main = large_rgb_r;
large_rgb_r  = foldr join_at_xy_r black_rgb  tiles_rgb;

// main = large_rgba_r;
// large_rgba_r = foldr join_at_xy_r black_rgba tiles_rgba;


// Trying to work around nip2 hard-coded stack limit by splitting the large
// list into smaller ones.
// main = foldr alpha_blend_at_zero_zero canvas grouped_imgs;
// alpha_blend_at_zero_zero base overlay = alpha_blend_at_zero_zero base overlay 0 0 1.0;
// canvas = alternative_image_new max_width max_height 4 0;
// //[max_width, max_height] = max_dimensions [ max_dimensions (get_list_of_dimensions g) :: g <- groups ];
// [max_width, max_height] = max_dimensions [ [(get_width img), (get_height img)] :: img <- grouped_imgs ];
// grouped_imgs = [ foldr join_at_xy_r black_rgba group :: group <- groups ];
// groups = split_lines 1024 tiles_rgba;


tiles_rgb  = [ (remove_alpha h) : t :: h:t <- cropped_tiles];
// tiles_rgba = [ (add_alpha    h) : t :: h:t <- cropped_tiles];

cropped_tiles = [ (crop_margins 160 70 60 120 img):t :: img:t <- tiles ];
tiles = read_file argv?1;

EOF
}

# For debugging purposes:
#nip2_script | cat -n

tmpfile="$(mktemp)" || {
	echo "Failed to create a temporary file (using mktemp)."
	exit 1
}
trap 'rm -f "${tmpfile}"' EXIT

generate_file_list > "${tmpfile}"

nip2_script | nip2 --verbose -s /dev/stdin -o output.tif "${tmpfile}" \
	&& vips im_copy output.tif output.png
