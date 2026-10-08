#!/usr/bin/env python3
"""Rasterize original SWF timelines; requires Java, FFDec 26.2.1 and Pillow.

Usage: python3 Support/extract-penguin-actions.py penguin.swf ffdec-cli.jar work-dir
The input SHA is pinned. Intermediate files stay in work-dir; atlases are written
to Sources/WaddleOn/Resources/Penguin. No source checkout is modified.
"""
import copy
import hashlib
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET
from PIL import Image

source, jar, work = map(Path, sys.argv[1:])
assert hashlib.sha256(source.read_bytes()).hexdigest() == 'f089b4c1fc17d7f6a53e352cee199dc4b30128b3bca909a03dac3505e8366b7e'
work.mkdir(parents=True, exist_ok=True)
def ffdec(*args):
    subprocess.run(['java', '-jar', str(jar), *map(str, args)], check=True)

ffdec('-swf2xml', source, work / 'original.xml')
root = ET.parse(work / 'original.xml').getroot()
tags = root.find('tags')
definitions = [copy.deepcopy(n) for n in tags if n.get('type').startswith('Define')]
# Resolve inherited display-list entries, including frame 29's matrix-only
# changes to the preceding throw's two components. Each exported action starts
# all component clocks at zero rather than inheriting an earlier action's clock.
states = {}
display = {}
frame = 1
for n in tags:
    kind = n.get('type')
    if kind.startswith('RemoveObject'):
        display.pop(n.get('depth'), None)
    elif kind.startswith('PlaceObject'):
        depth = n.get('depth')
        if n.get('placeFlagMove') == 'true' and depth in display:
            placed = copy.deepcopy(display[depth])
            for key, value in n.attrib.items():
                if key.startswith('placeFlagHas') and value == 'false':
                    continue
                placed.set(key, value)
            for child in n:
                old = placed.find(child.tag)
                if old is not None:
                    placed.remove(old)
                placed.append(copy.deepcopy(child))
        else:
            placed = copy.deepcopy(n)
        placed.set('placeFlagMove', 'false')
        display[depth] = placed
    elif kind == 'ShowFrameTag':
        states[frame] = copy.deepcopy(display)
        frame += 1

sequences = [('dance', 26, 193)] + [(f'throw-{i}', 27+i, 28) for i in range(4)]
all_frames = {}
for name, source_frame, count in sequences:
    out = copy.deepcopy(root)
    out.set('frameCount', str(count))
    out.find('displayRect').attrib.update(Xmin='-800', Xmax='800', Ymin='-1400', Ymax='700')
    target = out.find('tags')
    target.clear()
    target.extend(copy.deepcopy(definitions))
    target.extend(states[source_frame][d] for d in sorted(states[source_frame], key=int))
    for _ in range(count):
        ET.SubElement(target, 'item', type='ShowFrameTag')
    ET.ElementTree(out).write(work / f'{name}.xml', encoding='utf-8', xml_declaration=True)
    ffdec('-xml2swf', work / f'{name}.xml', work / f'{name}.swf')
    ffdec('-zoom', '3', '-ignorebackground', '-export', 'frame', work / name, work / f'{name}.swf')
    files = sorted((work / name).rglob('*.png'), key=lambda p: int(p.stem))
    assert len(files) == count, (name, len(files))
    images = [Image.open(p).convert('RGBA') for p in files]
    assert all(im.size == (240,315) for im in images)
    bounds = [im.getbbox() for im in images]
    union = (min(b[0] for b in bounds), min(b[1] for b in bounds), max(b[2] for b in bounds), max(b[3] for b in bounds))
    assert union[0] > 0 and union[1] > 0 and union[2] < 240 and union[3] < 315, union
    print(name, 'frames', count, 'distinct', len({im.tobytes() for im in images}), 'bounds', union)
    all_frames[name] = images

# Shared crop contains the complete union with padding and keeps the original
# raster coordinates. Relative to the base crop (57,115,184,257), this adds
# 51px left, 48px right, 50px top and 21px bottom; no recentering/scaling.
crop = (6, 65, 232, 278)
destination = Path(__file__).resolve().parents[1] / 'Sources/WaddleOn/Resources/Penguin'
for name, images in [('dance', all_frames['dance']), ('throw', sum((all_frames[f'throw-{i}'] for i in range(4)), []))]:
    columns = 16 if name == 'dance' else 28
    rows = (len(images) + columns - 1) // columns
    atlas = Image.new('RGBA', (226*columns,213*rows))
    for i, image in enumerate(images):
        b=image.getbbox()
        assert b[0]>=crop[0] and b[1]>=crop[1] and b[2]<=crop[2] and b[3]<=crop[3], (name,i,b)
        atlas.paste(image.crop(crop),(i%columns*226,i//columns*213))
    path=destination / f'penguin-{name}-atlas.png'
    atlas.save(path, optimize=True)
    print(path, atlas.size, hashlib.sha256(path.read_bytes()).hexdigest())
