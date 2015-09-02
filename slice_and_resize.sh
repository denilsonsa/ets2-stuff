#!/bin/bash


if [ -f "$1" ] ; then
	input="$1"
	base="$2"

	# Based on http://www.imagemagick.org/Usage/crop/#crop_tile
	# -monitor monitors the progress.
	# +gravity disables any gravity setting (avoiding interactions with -crop).
	# -crop with dimensions but not position will generated multiple tiles.
	# +repage removes/resets the virtual canvas metadata.
	# +adjoin forces each image to be written to separate files.
	#
	#convert "$input" \
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
else
	echo "Usage: ./slice_and_resize.sh  very-large-image.png  basename"
fi

# Google layout:
# https://code.google.com/p/virtualmicroscope/wiki/SlideTiler
# return "{{path to the slide directory}}/" + b + "/" + a.y + "/" + a.x + ".png"
# --background if smaller tiles don't fit the entire image (format: 'R G B A', space/tab/semicolon separated).
# --tile-size is 256 by default
vips dzsave \
	map-medium-dark-final.png \
	dark_google \
	--layout google \
	--suffix .png[compression=9] \
	--background '0 0 0 0' \
	--vips-progress
