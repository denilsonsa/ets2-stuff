#!/usr/bin/env python3
#
# Overview:
#
#   When capturing maps for ets2-mobile-route-advisor, these are the steps:
#
#   1. Take a lot of screenshots from ETS2 game.
#   2. Stitch those screenshots together into a very large image.
#   3. Slice this very large image into tiles, for use in openlayers or leaflet.
#       - Look at slice_and_resize.sh for the command-line on how to do this step.
#   4. Optimize the generated PNG images, to save space. (optional)
#       - Use *this* script here!
#
#   This script optimizes the PNG images, and should be executed in the step 4
#   of the overall process.
#
#
# Motivation:
#
#   My previous solution to optimize all files was:
#
#       find "${base}" -name '*.png' -exec zopflipng_in_place -P 3 {} +
#
#   But this solution is too slow, because it ignores the fact that most tiles
#   are identical. From around 18500 files, 15000 of them were identical (81%
#   of them). This means the same input will be re-encoded and re-optimized
#   over and over.
#
#   Then I wrote this Python script, which aims to reduce duplicate work by
#   identifying identical files.
#
#   The implementation is very straightforward, because it assumes all files
#   are very small (not more than a few kilobytes):
#
#   1. Find all *.png files.
#   2. Read the file contents, and store it as the "key" of a dict. The "value"
#      is a list of all files with the exact same contents.
#   3. Iterate over the dict, running zopflipng on the first file and copying
#      it over to the other files. Do it in parallel.
#
#
# Requirements:
#   - Python 3.4
#   - zopflipng

import argparse
import concurrent.futures
import os
import os.path
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from tempfile import mkstemp


def parse_args():
    parser = argparse.ArgumentParser(
        description='Optimize PNG tiles (using zopflipng).',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        '-P',
        action='store',
        default=0,
        type=int,
        dest='parallel_tasks',
        help='Number of parallel tasks'
    )
    parser.add_argument(
        'tile_dir',
        action='store',
        type=str,
        help='Base directory of the PNG tiles'
    )
    options = parser.parse_args()

    if not os.path.isdir(options.tile_dir):
        parser.exit(u'Directory "{0}" not found'.format(options.tile_dir))

    return options


def prompt(question, default=None):
    yes = set(['yes', 'y', True])
    no = set(['no', 'n', False])

    suffix = '[y/n]'
    empty_return = None
    if default in yes:
        suffix = '[Y/n]'
        empty_return = True
    elif default in no:
        suffix = '[y/N]'
        empty_return = False

    while True:
        answer = input(question + ' ' + suffix).strip().lower()
        if answer in yes:
            return True
        elif answer in no:
            return False
        elif answer == '' and empty_return is not None:
            return empty_return
        else:
            print('Invalid response: ' + answer)


def find_files(base_dir):
    path = Path(base_dir)
    yield from path.glob('**/*.png')


def overwrite(src, dst):
    with open(src, 'rb') as input:
        with open(dst, 'wb') as output:
            output.write(input.read())


def optimize_file(filename):
    tmp = mkstemp()  # Returns (fd, filename)
    try:
        # Closing the temporary file.
        os.close(tmp[0])

        # Executing zopflipng, overwriting the temporary file.
        ret = subprocess.call(['zopflipng', '-y', str(filename), tmp[1]])

        # Error checking.
        if ret != 0:
            print('ERROR when optimizing file "{0}": zopflipng returned non-zero code: {0}'.format(filename, ret))
        elif os.stat(tmp[1]).st_size == 0:
            print('ERROR when optimizing file "{0}": output from zopflipng was empty'.format(filename))
        else:
            # Everything is fine, let's overwrite the original file.
            overwrite(tmp[1], str(filename))
    finally:
        # Removing the temporary file.
        os.unlink(tmp[1])


def process_similar_files(files):
    optimize_file(str(files[0]))
    for f in files[1:]:
        print('Copying {0} to {1}'.format(files[0], f))
        overwrite(str(files[0]), str(f))


def main():
    options = parse_args()

    filelist = list(find_files(options.tile_dir))

    # The code will store the the file contents in memory.
    # A little safety check before running and using too much memory.
    total_size = sum(p.stat().st_size for p in filelist)
    if total_size > 64 * 1024 * 1024:
        if not prompt('This might require about {0}MB of RAM. Continue?'.format(round(total_size / 1024 / 1024))):
            sys.exit(1)

    # Finding all files with equal contents.
    bytes_to_file = defaultdict(list)
    for p in filelist:
        with p.open('rb') as f:
            b = f.read()
            bytes_to_file[b].append(p)

    # Optimizing/processing everything.
    workers = options.parallel_tasks
    if workers <= 0:
        workers = None
    #with concurrent.futures.ProcessPoolExecutor(max_workers=workers) as executor:
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        for x in executor.map(process_similar_files, bytes_to_file.values()):
            pass

    print('Finished!')

if __name__ == '__main__':
    main()
