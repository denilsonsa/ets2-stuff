Random collection of ETS2-related stuff
=======================================

This repository is a collection of assorted stuff related to Euro Truck Simulator 2 game.

Related links
-------------

* [ets2-mobile-route-advisor: Investigate mini-map](https://github.com/mkoch227/ets2-mobile-route-advisor/issues/2)
* [Full printable map for ETS2](http://forum.scssoft.com/viewtopic.php?f=41&t=169132), by Funbit
* [Full A0 printable high-resolution map for ETS2](http://forum.scssoft.com/viewtopic.php?f=41&t=186779), by Funbit

Descriptions
------------

### `slice_and_resize.sh`

Converts one huge image into several small tiles, for use in a pan-and-zoom map-style interface.

Originally, I intended to write code to slice the image and save each tile individually, but then I found [vips](http://libvips.blogspot.com/), which already [has it implemented into an easy-to-use command](http://libvips.blogspot.com/2013/03/making-deepzoom-zoomify-and-google-maps.html). In addition, it supports very large images while maintaining a low memory footprint.

After generating the tiles, it is possible to use [zopflipng](https://github.com/google/zopfli/tree/master/src/zopflipng/) (with [zopflipng_in_place](https://bitbucket.org/denilsonsa/small_scripts/src/default/zopflipng_in_place) helper script) to further compress the PNG files. This may take several hours, but will most likely reduce the file size.

### `join_tiles_vips.sh`

Tries to join several tiles back into one large image, using `vips` tool.

I wrote this version before learning how to use [nip2](http://www.vips.ecs.soton.ac.uk/index.php?title=Nip2).

Although it may work, it was too slow, and I have deprecated this script (use the `nip2` version instead).

### `join_tiles_nip2.sh`

Tries to join several tiles back into one large image, using [`nip2`](http://www.vips.ecs.soton.ac.uk/index.php?title=Nip2)..

`nip2` is GUI on top of *libvips*, implementing a functional language to describe the image operations.

This script generates a list of all files and their coordinates, and then calls `nip2` passing both the filelist and the code to join the images. [If the input files are in a format that do not support random pixel access, `nip2` will generate gigabytes of temporary files](https://github.com/jcupitt/nip2/issues/54#issuecomment-137151009). Still, RAM usage will be relatively low (specially when compared to the size of the intermediate and final images).

This `nip2` script works fairly well, but hits some [hard-coded limitations](https://github.com/jcupitt/nip2/issues/54#issuecomment-137199467) when the number of input files is too large.

### `join_screenshots_nip2.sh`

Tries to joins several screenshots into one large image. Also crops each screenshot before joining (by removing a set amount of pixels from each side, essentially grabbing an inner rectangle from each screenshot).

This script is very similar to `join_tiles_nip2.sh`, and in fact was copied from it.

### `take_screenshots_of_gmaps.py`

Tries to grab a bunch of screenshots by controlling the mouse and click-dragging a movable area. This version looks for a Google Chrome window with Google Maps open, then repeatedly takes screenshots and moves the map around.

This script is a bit rough around the edges, but works (or worked) on my Linux system. As it is, it won't work on Mac OS X (because that system requires a `drag` event, and this script is using `move`). It won't work on Windows either, unless some changes are made.

It is somewhat inspired by [Funbit's method of grabbing ETS2 map screenshots](http://forum.scssoft.com/viewtopic.php?p=405122#p405122), although using different tools and without looking and that code.

This script was supposed to be a prototype, a proof-of-concept, before writing another script to grab screenshots from ETS2 map. In the end, this second script was not written, mostly because [Funbit's ETS2 map graphics mod](http://forum.scssoft.com/viewtopic.php?p=430273#p430273) is crashing the latest versions of ETS2.