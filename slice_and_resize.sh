#!/bin/bash


if [ -f "$1" ] ; then
	input="$1"
	base="$2"

	############################################################
	# The commented code here tries to use ImageMagick to manually create tiles
	# in a specific dimension. This code has been abandoned in favor of libvips
	# because ImageMagick uses too much memory for extremely large images. The
	# code is still left here because it may be useful in other cases.

	# Based on http://www.imagemagick.org/Usage/crop/#crop_tile
	# -monitor monitors the progress.
	# +gravity disables any gravity setting (avoiding interactions with -crop).
	# -crop with dimensions but not position will generated multiple tiles.
	# +repage removes/resets the virtual canvas metadata.
	# +adjoin forces each image to be written to separate files.
	#
	# convert "$input" \
	#	-monitor \
	#	+gravity \
	#	-crop 256x256 \
	#	-set filename:tile "%[fx:page.x/256]_%[fx:page.y/256]" \
	#	+repage +adjoin \
	#	"${base}_%[filename:tile].png"

	# ImageMagick uses too much memory.
	# https://stackoverflow.com/questions/6835363/large-image-processing-with-imagemagick-convert-need-more-throughput
	# I'm using VIPS instead:
	# https://stackoverflow.com/questions/10542246/imagemagick-crop-huge-image
	# http://libvips.blogspot.com.br/2013/03/making-deepzoom-zoomify-and-google-maps.html
	# http://www.vips.ecs.soton.ac.uk/supported/current/doc/html/libvips/VipsForeignSave.html#vips-dzsave
	# https://github.com/jcupitt/libvips/blob/master/libvips/foreign/dzsave.c
	# https://github.com/jcupitt/libvips/blob/master/libvips/iofuncs/enumtypes.c
	############################################################

	############################################################
	# Using libvips

	# Google layout:
	# https://code.google.com/p/virtualmicroscope/wiki/SlideTiler
	# return "{{path to the directory}}/" + zoom + "/" + a.y + "/" + a.x + ".png"
	# --background if smaller tiles don't fit the entire image (format: 'R G B A', space/tab/semicolon separated).
	# --tile-size is 256 by default
	vips dzsave \
		"${input}" \
		"${base}" \
		--layout google \
		--suffix .png \
		--background '0 0 0 0' \
		--vips-progress

	# If this command fails, maybe the input image has only 3 channels (RGB) instead of 4 (RGBA).
	# You can convert it from RGB to RGB using:
	#   vips bandjoin_const "${input}" very_large_multi_gigabyte_file.v "255"
	# http://stackoverflow.com/a/39431357/
	#
	# If it still fails, maybe there is some deadlock or racing condition on vips binary.
	# Try again passing --vips-concurrency=1

	# If you want to further compress all the PNG files, execute:
	#   find "${base}" -name '*.png' -exec zopflipng_in_place -P 3 {} +
	# Where 3 is the number of parallel processes.
	#
	# This step is highly recommended, but might take several hours.
	# It takes too long because it re-encodes equal files multiple times.
	# It should be possible to write a tool that caches the results, which would speed up the process.
	# https://bitbucket.org/denilsonsa/small_scripts/src/default/zopflipng_in_place
	# https://github.com/google/zopfli/tree/master/src/zopflipng/
else
	echo "Usage: ./slice_and_resize.sh  very-large-image.png  basedir"
fi
