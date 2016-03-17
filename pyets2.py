# TODO: Try changing most open() calls with mmap.mmap()

import csv
import functools
import glob
import itertools
import math
import mmap
import os.path
import re
import struct
import sys
from collections import namedtuple, OrderedDict
from enum import IntEnum

IS_PYTHON_3_5 = sys.version_info >= (3, 5)

if sys.version_info < (3, 4):
    import warnings
    # The "enum" module is new to 3.4, but the user may be able to download a backported module for earlier versions.
    warnings.warn('This code has been tested with Python 3.4; it may or may not work on older versions.')


############################################################
# Configuration.
# TODO: Avoid using hard-coded strings.

BASE_SCS_DIR = os.path.expanduser('~/ets2/data/base_scs')
DEF_SCS_DIR = os.path.expanduser('~/ets2/data/def_scs')
ETS2MAP_LUT_DIR = os.path.expanduser('~/ets2/ets2-map/LUT')


############################################################
# Convenience classes/structs/functions.

Int32 = struct.Struct('<i')
Int32_unpack_from = lambda *args: Int32.unpack_from(*args)[0]

Float = struct.Struct('<f')
Float_unpack_from = lambda *args: Float.unpack_from(*args)[0]

class Vector3(namedtuple('Vector3', 'x y z')):
    # 3 single-precision 32-bit floats, little-endian.
    StructFloats = struct.Struct('<3f');

    @classmethod
    def unpack_from(cls, buffer, offset=0):
        return cls(*cls.StructFloats.unpack_from(buffer, offset))


############################################################
# Parser for *.sii text files.

class SiiReadingException(Exception):
    pass


class SiiDefinition:
    def __init__(self, type, name):
        self.type = type
        self.name = name
        self.items = OrderedDict()

    def __repr__(self):
        return '<SiiDefinition {self.type}:{self.name} at {0}>'.format(hex(id(self)), self=self)
        #return '<SiiDefinition {self.type}:{self.name} at {0}: {self.items!r}>'.format(hex(id(self)), self=self)


def sii_file_reader(f):
    '''Given a file (opened as text), returns a generator for items in the .sii file.

    Sample code:

    with open(os.path.join(pyets2.DEF_SCS_DIR, 'def/world/road_look.sii')) as f:
        for x in pyets2.sii_file_reader(f):
            print(x.type)  # Should print: road_look
            print(x.name)  # Should print: road.look0
            print(x.items['name'])  # Should print: "Road 1 lane double"
            print(x.items['road_size_left'])  # Should print: 4.5
            print(x.items['lanes_right[]'])  # Should print: ['traffic_lane.road.local']
            print('-' * 50)
    '''
    header_found = False
    footer_found = False
    brace_depth = 0
    current_block = None
    block_start_re = re.compile('^([^ \t]+)[ \t]*:[ \t]*([^ \t]+)[ \t]*{$')
    block_item_re = re.compile('^([^ \t]+)[ \t]*:[ \t]*([^ \t]+|"[^"]*")$')

    for lineno, line in enumerate(f, start=1):
        line = line.strip()

        if line == '':
            continue
        if line.startswith('#'):
            continue
        if line.startswith('//'):
            continue

        if not header_found:
            if line == 'SiiNunit':
                header_found = True
                continue
            else:
                raise SiiReadingException('Header "SiiNunit" not found at line {0}'.format(lineno))

        if brace_depth == 0:
            if footer_found:
                raise SiiReadingException('Extra data "{1}" after final "}" at line {0}'.format(lineno, line))

            if line == '{':
                brace_depth += 1
                continue
            else:
                raise SiiReadingException('Expected "{{" but found "{1}" at line {0}'.format(lineno, line))

        if brace_depth == 1:
            match = block_start_re.match(line)
            if match:
                current_block = SiiDefinition(match.group(1), match.group(2))
                brace_depth += 1
                continue
            elif line == '}':
                brace_depth -= 1
                footer_found = True
                continue
            else:
                raise SiiReadingException('Expected "foo : bar {{" but found "{1}" at line {0}'.format(lineno, line))

        if brace_depth == 2:
            match = block_item_re.match(line)
            if match:
                key = match.group(1)
                value = match.group(2)
                if key.endswith('[]'):
                    if key not in current_block.items:
                        current_block.items[key] = [value]
                    else:
                        current_block.items[key].append(value)
                else:
                    current_block.items[key] = value
                continue
            elif line == '}':
                brace_depth -= 1
                yield current_block
                current_block = None
                continue
            else:
                raise SiiReadingException('Expected "foo : bar" but found "{1}" at line {0}'.format(lineno, line))

        raise SiiReadingException('This should not have happened! line {0}'.format(lineno))


############################################################
# ETS2 objects.

class Ets2PrefabCurve:
    _attrs = 'index start end length start_rotation end_rotation start_yaw end_yaw next prev next_curve prev_curve'.split()
    # Types:
    # index: int
    # start, end, start_rotation, end_rotation: Vector3
    # length, start_yaw, end_yaw: float
    # next, prev: list of int
    # next_curve, prev_curve: list of Ets2PrefabCurve

    def __init__(self, **kwargs):
        for attr in self._attrs:
            setattr(self, attr, kwargs.pop(attr, None))
        assert len(kwargs) == 0

    def __str__(self):
        return (
            'Ets2PrefabCurve(\n\t' +
            ',\n\t'.join(a + '=' + repr(getattr(self, a)) for a in self._attrs) +
            ')'
        )

    def __repr__(self):
        return '<Ets2PrefabCurve index={0!r} at {1}>'.format(self.index, hex(id(self)))


class Ets2PrefabNode:
    _attrs = 'node coord rotation yaw input_curve output_curve'.split()
    # Types:
    # node: int
    # coord, rotation: Vector3
    # yaw: float
    # input_curve, output_curve: List of Ets2PrefabCurve

    def __init__(self, **kwargs):
        for attr in self._attrs:
            setattr(self, attr, kwargs.pop(attr, None))
        assert len(kwargs) == 0

    def __str__(self):
        return (
            'Ets2PrefabNode(\n\t' +
            ',\n\t'.join(a + '=' + repr(getattr(self, a)) for a in self._attrs) +
            ')'
        )

    def __repr__(self):
        return '<Ets2PrefabNode node={0!r} at {1}>'.format(self.node, hex(id(self)))


class Ets2Prefab:
    # 15x signed 32-bit integers, little-endian.
    StructHeader = struct.Struct('<15i')

    def __init__(self, filename):
        self.filename = filename
        self.curves = []
        self.nodes = []
        self.idx = 0
        self.idsii = ''
        self.company = None  # Ets2Company object
        self.parse()

    def __str__(self):
        return (
            'Ets2Prefab<\n\t' +
            ',\n\t'.join(a + '=' + repr(getattr(self, a)) for a in 'filename idx idsii company curves nodes'.split()) +
            '>'
        )

    def __repr__(self):
        return '<Ets2Prefab idx={0!r} idsii={1!r} filename={2!r} at {3}>'.format(
            self.idx, self.idsii, self.filename, hex(id(self)))

    def is_file(self, filename):
        return(
            os.path.splitext(os.path.basename(self.filename))[0]
            ==
            os.path.splitext(os.path.basename(filename))[0]
        )

    def parse(self):
        with open(self.filename, 'rb') as f:
            with mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as m:
                (
                    version,    # offset=0
                    nodes,      # offset=4
                    navCurves,  # offset=8
                    terrain,    # offset=12
                    signs,      # offset=16
                    spawns,     # offset=20
                    semaphores, # offset=24
                    mappoints,  # offset=28
                    triggers,   # offset=32
                    intersections, # offset=36
                    unknown1,   # offset=40
                    nodeOffset, # offset=44
                    off2,       # offset=48
                    off3,       # offset=52
                    off4,       # offset=56
                ) = self.StructHeader.unpack_from(m, 0)

                assert version == 21

                for navCurve in range(navCurves):
                    curveOff = off2 + navCurve * 128
                    nextCurve = [
                        Int32_unpack_from(m, 76 + k * 4 + curveOff)
                        for k in range(4)
                    ]
                    prevCurve = [
                        Int32_unpack_from(m, 92 + k * 4 + curveOff)
                        for k in range(4)
                    ]
                    curve = Ets2PrefabCurve(
                        index = navCurve,
                        start          = Vector3.unpack_from(m, 16 + curveOff),
                        end            = Vector3.unpack_from(m, 28 + curveOff),
                        start_rotation = Vector3.unpack_from(m, 40 + curveOff),
                        end_rotation   = Vector3.unpack_from(m, 52 + curveOff),
                        start_yaw = math.atan2(
                            Float_unpack_from(m, 48 + curveOff),
                            Float_unpack_from(m, 40 + curveOff),
                        ),
                        end_yaw = math.atan2(
                            Float_unpack_from(m, 60 + curveOff),
                            Float_unpack_from(m, 52 + curveOff),
                        ),
                        length = Float_unpack_from(m, 72 + curveOff),
                        next = [i for i in nextCurve if i != -1],
                        prev = [i for i in prevCurve if i != -1],
                    )
                    self.curves.append(curve)

                for curve in self.curves:
                    curve.next_curve = [self.curves[i] for i in curve.next]
                    curve.prev_curve = [self.curves[i] for i in curve.prev]

                for node in range(nodes):
                    nodeOff = nodeOffset + 104 * node
                    inputLanes = [
                        Int32_unpack_from(m, 40 + k * 4 + nodeOff)
                        for k in range(4)
                    ]
                    outputLanes = [
                        Int32_unpack_from(m, 40 + k * 4 + nodeOff)
                        for k in range(4)
                    ]
                    prefabNode = Ets2PrefabNode(
                        node = node,
                        coord    = Vector3.unpack_from(m, 16 + nodeOff),
                        rotation = Vector3.unpack_from(m, 28 + nodeOff),
                        input_curve  = [self.curves[x] for x in inputLanes if x != -1],
                        output_curve = [self.curves[x] for x in outputLanes if x != -1],
                        yaw = math.pi - math.atan2(
                            Float_unpack_from(m, 36 + nodeOff),
                            Float_unpack_from(m, 28 + nodeOff),
                        ),
                    )
                    self.nodes.append(prefabNode)

    def iterate_curves(self):
        raise NotImplementedError('Look at Ets2Prefab.cs:153')

    def get_route_options(self):
        raise NotImplementedError('Look at Ets2Prefab.cs:181')

    def get_all_routes(self):
        raise NotImplementedError('Look at Ets2Prefab.cs:195')

    def find_exit_node(self):
        raise NotImplementedError('Look at Ets2Prefab.cs:200')

    def find_start_node(self):
        raise NotImplementedError('Look at Ets2Prefab.cs:205')

    def get_route(self):
        raise NotImplementedError('Look at Ets2Prefab.cs:210')

    def get_polygon_for_route(self):
        raise NotImplementedError('Look at Ets2Prefab.cs:220')

    def generate_polygon_curves(self):
        raise NotImplementedError('Look at Ets2Prefab.cs:265')


class Ets2Company:
    def __init__(self):
        self.prefab = None
        self.prefab_id = ''
        self.min_x = 0
        self.min_y = 0
        self.max_x = 0
        self.max_y = 0

    @classmethod
    def from_csv_line(cls, cells, prefabs_list):
        '''Alternative constructor that allows initialization.'''
        instance = cls()
        instance.prefab_id = cells[0]
        instance.min_x = int(cells[1])
        instance.min_y = int(cells[2])
        instance.max_x = int(cells[3])
        instance.max_y = int(cells[4])

        prefabs = [x for x in prefabs_list if x.idsii == instance.prefab_id]
        assert len(prefabs) < 2
        if len(prefabs) == 1:
            instance.prefab = prefabs[0]
            instance.prefab.company = instance

        return instance

    def __str__(self):
        return (
            'Ets2Company<\n\t' +
            ',\n\t'.join(a + '=' + repr(getattr(self, a)) for a in 'prefab_id prefab min_x min_y max_x max_y'.split()) +
            '>'
        )

    def __repr__(self):
        return (
            'Ets2Company.from_csv_line([' +
            ', '.join(repr(getattr(self, a)) for a in 'prefab_id min_x min_y max_x max_y'.split()) +
            '], None)'
        )


class Ets2RoadLook:
    _attrs = 'look_id is_highway is_local is_express offset size_left size_right shoulder_left shoulder_right lanes_left lanes_right'.split()
    # Types:
    # look_id: str
    # is_highway, is_local, is_express: bool
    # offset, size_left, size_right, shoulder_left, shoulder_right: float
    # lanes_left, lanes_right: int

    def __init__(self, **kwargs):
        for attr in self._attrs:
            setattr(self, attr, kwargs.pop(attr, None))
        assert len(kwargs) == 0

    def __str__(self):
        return (
            'Ets2RoadLook(\n\t' +
            ',\n\t'.join(a + '=' + repr(getattr(self, a)) for a in self._attrs) +
            ')'
        )

    def __repr__(self):
        return '<Ets2RoadLook look_id={0!r} at {1}>'.format(self.look_id, hex(id(self)))

    def get_total_width(self):
        return self.offset + 4.5 * (self.lanes_left + self.lanes_right)


class Ets2ItemType(IntEnum)
        Building = 0x01
        Road = 0x02
        Prefab = 0x03
        Model = 0x04
        Company = 0x05
        Service = 0x06
        CutPlane = 0x07
        Dunno = 0x08
        City = 0x0B
        MapOverlay = 0x11
        Ferry = 0x12
        Garage = 0x15
        Trigger = 0x21
        FuelPump = 0x22
        Sign = 0x23
        BusStop = 0x24
        TrafficRule = 0x25


# TODO: Ets2Sector, which requires Ets2Node and Ets2Item.


############################################################
# The main class.

class Ets2Mapper:
    def __init__(self):
        if IS_PYTHON_3_5:
            self.prefab_files = glob.glob(
                os.path.join(BASE_SCS_DIR, 'prefab/**/*.ppd'),
                recursive=True)
        else:
            self.prefab_files = list(itertools.chain(
                glob.glob(os.path.join(BASE_SCS_DIR, 'prefab/*.ppd')),
                glob.glob(os.path.join(BASE_SCS_DIR, 'prefab/*/*.ppd')),
                glob.glob(os.path.join(BASE_SCS_DIR, 'prefab/*/*/*/*.ppd')),
                glob.glob(os.path.join(BASE_SCS_DIR, 'prefab/*/*/*/*/*.ppd')),
            ))

        self.sector_files = glob.glob(os.path.join(BASE_SCS_DIR, 'map/europe/sec*.base'))

        self.prefabs = []  # List of Ets2Prefab
        self.sectors = []  # List of Ets2Sector

        self._companies_lookup = []  # List of Ets2Company
        self._prefab_lookup = {}  # Dict of int (Ets2Prefab.idx) : Ets2Prefab
        self._cities_lookup = {}  # Dict of int : str
        self._road_lookup = {}  # Dict of int : Ets2RoadLook
        self.item_search_requests

        self.roadlook_by_id = {}  # Dict of str (Ets2RoadLook.look_id) : Ets2RoadLook

        self.parse()

    def loadLUT(self):
        idx2prefab = {}
        prefab2file = {}

        with open(os.path.join(ETS2MAP_LUT_DIR, 'LUT1.19-prefab.csv'), newline='') as f:
            reader = csv.reader(f)
            for row in reader:
                try:
                    idx = int(row[2], base=16)
                except ValueError:
                    pass
                else:
                    if idx in idx2prefab:
                        print('UNEXPECTED! idx={0} already in idx2prefab.'.format(idx))
                        print('row:', row)
                        print('idx2prefab[idx]:', idx2prefab[idx])
                    idx2prefab[idx] = row[1]

        with open(os.path.join(DEF_SCS_DIR, 'def/world/prefab.sii')) as f:
            for block in sii_file_reader(f):
                assert block.type == 'prefab_model'
                assert block.name not in prefab2file
                prefab2file[block.name] = block.items['prefab_desc']

        for key, value in idx2prefab.items():
            if value in prefab2file:
                filename = prefab2file[value]
                objs = [x for x in self.prefabs if x.is_file(filename)]
                if len(objs) > 1:
                    print('UNEXPECTED! Expected only a single object, found:', objs)
                elif len(objs) == 1:
                    obj = objs[0]
                    obj.idx = key
                    obj.idsii = value
                    assert key not in self._prefab_lookup
                    self._prefab_lookup[key] = obj

        with open(os.path.join(ETS2MAP_LUT_DIR, 'LUT1.19-companies.csv'), newline='') as f:
            reader = csv.reader(f)
            self._companies_lookup = [Ets2Company.from_csv_line(x, self.prefabs) for x in reader]

        with open(os.path.join(ETS2MAP_LUT_DIR, 'LUT1.19-cities.csv'), newline='') as f:
            reader = csv.reader(f)
            self._cities_lookup = {int(row[0], base=16): row[1] for row in f}

        with open(os.path.join(DEF_SCS_DIR, 'def/world/road_look.sii')) as f:
            for block in sii_file_reader(f):
                assert block.type == 'road_look'
                assert block.name not in self.roadlook_by_id
                lanes_left = block.items.get('lanes_left[]', [])
                lanes_right = block.items.get('lanes_right[]', [])
                lanes_types = set(lanes_left + lanes_right)
                self.roadlook_by_id[block.name] = Ets2RoadLook(
                    look_id = block.name,
                    is_local = ('traffic_lane.road.local' in lanes_types),
                    is_highway = ('traffic_lane.road.motorway' in lanes_types),
                    is_express = ('traffic_lane.road.expressway' in lanes_types),
                    offset = float(block.items.get('road_offset', 0.0)),
                    size_left = float(block.items.get('road_size_left', 0.0)),
                    size_right = float(block.items.get('road_size_right', 0.0)),
                    shoulder_left = float(block.items.get('shoulder_size_left', 0.0)),
                    shoulder_right = float(block.items.get('shoulder_size_right', 0.0)),
                    lanes_left = len(lanes_left),
                    lanes_right = len(lanes_right),
                )

        with open(os.path.join(ETS2MAP_LUT_DIR, 'LUT1.19-roads.csv'), newline='') as f:
            reader = csv.reader(f)
            self._road_lookup = {int(row[0], base=16): self.roadlook_by_id[row[1]] for row in reader}

    def parse(self):
        # TODO: "skip multi sectors" parameter
        self.prefabs = [Ets2Prefab(f) for f in self.prefab_files]
        self.loadLUT()

        # self.item_search_requests = []
        self.sectors = [Ets2Sector(f) for f in self.sector_files]

        # TODO: everything else, Ets2Mapper.cs:231

