Random collection of ETS2-related stuff
=======================================

This repository is a collection of assorted stuff related to Euro Truck Simulator 2 game.

Descriptions
------------

### `leaflet.html`, `openlayers.html`, `openlayers-koenvh1.html`

Demonstrations of viewing [Funbit's ET2 map](http://forum.scssoft.com/viewtopic.php?f=41&t=186779) and [Koenvh1's ProMods + RusMap map](https://github.com/mike-koch/ets2-mobile-route-advisor/issues/77#issuecomment-192935162) using a map UI in the browser. Written as a proof-of-concept before [being incorporated into ets2-mobile-route-advisor](https://github.com/mkoch227/ets2-mobile-route-advisor/issues/2#issuecomment-130100760).

One version uses [Leaflet](http://leafletjs.com/), another uses [OpenLayers](http://openlayers.org/). Both versions implement a custom projection (i.e. custom coordinates). Sometimes the result is a bit buggy.

The map images are loaded from `funbit-map-medium-dark-final/`. [The tiles were generated](https://github.com/mkoch227/ets2-mobile-route-advisor/issues/2#issuecomment-129958811) using `vips` tool, and then losslessly compressed using `zopflipng`. Read the description of `slice_and_resize.sh` (in this README file) for details.

You can also view them online: [leaflet.html](http://denilsonsa.github.io/ets2-stuff/leaflet.html) and [openlayers.html](http://denilsonsa.github.io/ets2-stuff/openlayers.html) and [openlayers-koenvh1.html](http://denilsonsa.github.io/ets2-stuff/openlayers-koenvh1.html).

### `cities-promods-rusmap.js`

Read [mike-koch/ets2-mobile-route-advisor/pull/85](https://github.com/mike-koch/ets2-mobile-route-advisor/pull/85) and [mike-koch/ets2-mobile-route-advisor/issues/90](https://github.com/mike-koch/ets2-mobile-route-advisor/issues/90).

### `coords.html`

Quick way to experiment with coordinate conversions, useful to debug the formulas. Also available online: [coords.html](http://denilsonsa.github.io/ets2-stuff/coords.html)

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

### `gfx.svg`

SVG graphics/icons related to Euro Truck Simulator 2, American Truck Simulator and [ets2-mobile-route-advisor](https://github.com/mkoch227/ets2-mobile-route-advisor).

### `pyets2.py` and `pyets2_experiment.ipynb`

This is an incomplete rewrite of [ets2-map](https://github.com/nlhans/ets2-map). I started rewriting that C# code in Python because I wanted to have a quicker and easier environment to explore and experiment with ETS2 data. I wrote some code, but never managed to finish it (due to lack of time and higher real-life priorities). I wrote it using Python 3.4 and [Jupyter](http://jupyter.org/).

External links
-------------

* [`scs_extractor` tool to extract files from `base.scs`](http://www.eurotrucksimulator2.com/mod_tools.php)
* [ets2-mobile-route-advisor: Investigate mini-map](https://github.com/mkoch227/ets2-mobile-route-advisor/issues/2)
* [Full printable map for ETS2](http://forum.scssoft.com/viewtopic.php?f=41&t=169132), by Funbit
* [Full A0 printable high-resolution map for ETS2](http://forum.scssoft.com/viewtopic.php?f=41&t=186779), by Funbit
* [Pull request #85: ProMods + RusMap version](https://github.com/mike-koch/ets2-mobile-route-advisor/pull/85),  <https://github.com/Koenvh1/ETS2-City-Coordinate-Retriever>

Other maps:

* <https://map.krashnz.com/> - <https://forum.truckersmp.com/index.php?/topic/21376-ets2-map/>
* <http://ets2map.com/>
