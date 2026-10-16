#!/usr/bin/env python3
"""Crops the real macOS icons that the "unsigned app" walkthrough (gatekeeper.js) draws, out of a screen recording of the flow
on a Mac running macOS 26. The recording itself is not part of the repository.

    python3 promo/video/extract-gk-assets.py "<recording.mov>"      -> promo/video/assets/gk/*.png

Each icon is cut at the pixel position where it appears in the recording (3024x1964); coordinates were found with detect().
"""
import os, subprocess, sys, tempfile, zlib, struct

src = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, 'assets', 'gk')
os.makedirs(out, exist_ok=True)
tmp = tempfile.mkdtemp()

def ffmpeg(*args):
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', *args], check=True)

def frame(t, x0, y0, w, h, name):
    path = os.path.join(tmp, name + '.png')
    ffmpeg('-ss', str(t), '-i', src, '-frames:v', '1', '-vf', f'crop={w}:{h}:{x0}:{y0}', path)
    return path

def read_png(path):
    d = open(path, 'rb').read(); i = 8; idat = b''; w = h = 0; ct = 0
    while i < len(d):
        n, = struct.unpack('>I', d[i:i + 4]); typ = d[i + 4:i + 8]; data = d[i + 8:i + 8 + n]; i += 12 + n
        if typ == b'IHDR': w, h, _, ct = struct.unpack('>IIBB', data[:10])
        elif typ == b'IDAT': idat += data
    bpp = 3 if ct == 2 else 4
    raw = zlib.decompress(idat); stride = w * bpp; rows = []; prev = bytearray(stride); p = 0
    for y in range(h):
        f = raw[p]; line = bytearray(raw[p + 1:p + 1 + stride]); p += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0; b = prev[x]; c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif f == 4:
                pa = abs(b - c); pb = abs(a - c); pc = abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        rows.append(line); prev = line
    return w, h, bpp, rows

def colorful(px):
    r, g, b = px
    return max(r, g, b) - min(r, g, b) > 40 or (r + g + b) / 3 > 110

def xbounds(rows, bpp, y, xa, xb):
    """Left and right edge of the icon on row y: the longest run of 'not background' pixels in [xa, xb)."""
    best = (0, 0); start = None
    for x in range(xa, xb + 1):
        on = x < xb and colorful(tuple(rows[y][x * bpp:x * bpp + 3]))
        if on and start is None: start = x
        if not on and start is not None:
            if x - start > best[1] - best[0]: best = (start, x)
            start = None
    return best

def sheet(frame_path, items, region_x, size=42):
    """items: (name, y centre); the icon's x extent is measured on the row, then cut as a square."""
    w, h, bpp, rows = read_png(frame_path)
    for name, yc in items:
        a, b = xbounds(rows, bpp, yc, region_x[0], region_x[1])
        cx = (a + b) // 2 if b > a else (region_x[0] + region_x[1]) // 2
        crop(frame_path, name, cx - size // 2, yc - size // 2, size, size)

def crop(frame_path, name, x, y, w, h, key=None):
    target = os.path.join(out, name + '.png')
    vf = f'crop={w}:{h}:{x}:{y}'
    if key: vf += f',format=rgba,colorkey={key}:0.10:0.12'
    ffmpeg('-i', frame_path, '-vf', vf, target)

# System Settings: the sidebar (x 760.., 2x pixels)
f = frame(13.2, 760, 240, 480, 1400, 'side-a')
sheet(f, [('wifi', 599), ('bluetooth', 663), ('network', 727), ('vpn', 791), ('battery', 855), ('accessibility', 1009), ('siri', 1073), ('spotlight', 1137), ('displays', 1201)], (40, 110))
crop(f, 'general', 70 - 18, 945 - 18, 36, 36)  # the row is selected there: a smaller cut keeps the blue highlight out
f = frame(13.2, 760, 240, 480, 1400, 'side-a2')
sheet(f, [('desktopdock', 1265)], (40, 110))
f = frame(15.5, 760, 240, 480, 1400, 'side-b')
sheet(f, [('menubar', 271), ('appearance', 335), ('wallpaper', 399), ('notifications', 489), ('sound', 553), ('focus', 617), ('screentime', 681), ('lockscreen', 771), ('privacy', 835), ('touchid', 899), ('users', 963), ('gamecenter', 1053), ('icloud', 1117), ('internetaccounts', 1181), ('wallet', 1245)], (40, 110))
# the Privacy & Security pane
f = frame(17.3, 1230, 240, 760, 1400, 'pane-a')
sheet(f, [('p-location', 386), ('p-passkeys', 500), ('p-calendar', 606), ('p-files', 712), ('p-disk', 818), ('p-home', 924), ('p-media', 1030), ('p-reminders', 1136), ('p-photos', 1242)], (40, 140))
crop(f, 'p-hand', 66, 243 - 26, 52, 52)
f = frame(18.6, 1230, 240, 760, 1400, 'pane-b')
sheet(f, [('p-bluetooth', 196), ('p-remote', 282), ('p-appmgmt', 368), ('p-automation', 454), ('p-camera', 540), ('p-devices', 626), ('p-devtools', 712), ('p-mic', 798), ('p-motion', 884), ('p-localnet', 970), ('p-speech', 1056), ('p-screenrec', 1142), ('p-focus', 1228)], (40, 140))
f = frame(20.9, 1230, 240, 760, 1400, 'pane-c')
sheet(f, [('p-blocked', 237), ('p-analytics', 341), ('p-ads', 427), ('p-ai', 531), ('p-filevault', 1045), ('p-accessory', 1131), ('p-bgsec', 1217)], (40, 140))
# Finder's sidebar (blue and grey outline symbols, keyed out of the dark background)
f = frame(6.4, 560, 240, 1000, 900, 'finder')
for name, yc in [('f-recents', 181), ('f-shared', 243), ('f-apps', 372), ('f-desktop', 436), ('f-docs', 500), ('f-downloads', 565), ('f-icloud', 692), ('f-home', 757), ('f-disk', 821), ('f-airdrop', 885)]:
    crop(f, name, 90 - 24, yc - 24, 48, 48, key='0x2b2b2d')
# the warning and the Touch ID prompt
f = frame(23.2, 1180, 300, 300, 300, 'gate')
crop(f, 'gatekeeper', 118, 66, 126, 120, key='0x3a3a3c')
f = frame(24.7, 1180, 300, 300, 300, 'touch')
crop(f, 'touchid-prompt', 112, 90, 124, 108, key='0x3a3a3c')
print(f'{len(os.listdir(out))} icons -> {out}')
