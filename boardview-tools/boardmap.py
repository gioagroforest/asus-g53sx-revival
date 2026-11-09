"""Draw a labelled pad map of the G53SX rev 2.0 mainboard (docs/board-map.svg) from an eM-Test ASC boardview export.

Usage:  python -I boardmap.py pins.ASC parts.ASC board-map.svg

The ASC files are ASUS property and are not in this repo; bring your own export. Only pad positions and the part
labels in KEY are drawn: no nets or wiring. Side B is mirrored so each half is shown as seen from that side.
"""
import sys, re, html
pins_path, parts_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
parts = {}
for line in open(parts_path, encoding='ascii', errors='replace'):
    m = re.match(r'^(\S+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+[\d.]+\s+\S+\s+\((T|B)\)', line)
    if m: parts[m.group(1)] = (float(m.group(2)), float(m.group(3)), m.group(4))
pins = []  # (part, x, y, side)
cur = None
for line in open(pins_path, encoding='ascii', errors='replace'):
    m = re.match(r'^Part (\S+)\s+\((T|B)\)', line)
    if m: cur = (m.group(1), m.group(2)); continue
    f = line.split()
    if cur and len(f) >= 6 and re.match(r'^-?[\d.]+$', f[2]) and re.match(r'^-?[\d.]+$', f[3]):
        pins.append((cur[0], float(f[2]), float(f[3]), cur[1]))
KEY = {
 'U0301':'CPU socket','U2001':'Chipset (PCH)','U3001':'Keyboard/power controller (EC)','J7001':'GPU card slot (MXM)',
 'J4501':'Screen connector','PL8100':'3.3V coil','PL8101':'5V coil','PL8200':'CPU VTT 1.05V coil','PL8300':'RAM 1.5V coil',
 'PL8001':'CPU core coil','PL8002':'CPU core coil','PL8003':'CPU core coil','PL8400':'1.8V coil','PL8700':'0.8V coil',
 'PL8800':'Charger coil','Q4502':'Screen 3.3V switch','Q4570':'Backlight 19V switch','JP7001':'GPU 19V jumper',
 'JP7002':'GPU 5V jumper','JP7004':'GPU 3.3V jumper','U2801':'BIOS chip','J2802':'BIOS header','JDEBUG1':'Debug port (LPC)',
 'JRST2001':'CMOS clear','JRST2002':'ME clear','J1401':'RAM slot','J1501':'RAM slot','J1601':'RAM slot','J1701':'RAM slot'}
COL = {'coil':'#e8590c','CPU':'#1971c2','Chip':'#1971c2','GPU':'#2f9e44','Scre':'#9c36b5','RAM ':'#868e96','Back':'#9c36b5'}
def col(lbl):
    for k,v in COL.items():
        if k in lbl: return v
    return '#c92a2a'
W,H,SC,PAD = 11.68, 7.45, 90, 40
def view(side, mirror, title, oy):
    s = [f'<text x="{PAD}" y="{oy+22}" font-size="20" font-weight="bold">{html.escape(title)}</text>']
    bx, by = PAD, oy+35
    s.append(f'<rect x="{bx}" y="{by}" width="{W*SC}" height="{H*SC}" fill="#f8f9fa" stroke="#333"/>')
    def tx(x): return bx + ((-x if mirror else x) + W/2)*SC
    def ty(y): return by + (H/2 - y)*SC
    for p,x,y,sd in pins:
        if sd != side: continue
        c = '#adb5bd' if p not in KEY else col(KEY[p])
        r = 0.9 if p not in KEY else 1.6
        s.append(f'<circle cx="{tx(x):.1f}" cy="{ty(y):.1f}" r="{r}" fill="{c}"/>')
    placed = []
    items = sorted([(p,l) for p,l in KEY.items() if p in parts and parts[p][2]==side], key=lambda t: ty(parts[t[0]][1]))
    for p,lbl in items:
        x,y,_ = parts[p]
        cx, cy = tx(x), ty(y)
        w = 7.5*len(p+' '+lbl)
        lx, ly = cx+7, cy-6
        for _ in range(40):
            if all(not (lx < ax+aw and ax < lx+w and abs(ly-ay) < 15) for ax,ay,aw in placed): break
            ly += 15
        placed.append((lx,ly,w))
        s.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="5" fill="none" stroke="{col(lbl)}" stroke-width="2"/>')
        if ly != cy-6: s.append(f'<line x1="{cx:.1f}" y1="{cy:.1f}" x2="{lx:.1f}" y2="{ly-4:.1f}" stroke="{col(lbl)}" stroke-width="1"/>')
        s.append(f'<text x="{lx:.1f}" y="{ly:.1f}" font-size="13" fill="{col(lbl)}" font-weight="bold" stroke="#fff" stroke-width="3" paint-order="stroke">{p} {html.escape(lbl)}</text>')
    return s, by + H*SC + 30
body, y = view('T', False, 'Side T ("top" in the file), seen from that side', 0)
b2, y2 = view('B', True, 'Side B ("bottom" in the file), seen from that side (mirrored)', y)
svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W*SC+2*PAD}" height="{y2}" font-family="Arial">', '<rect width="100%" height="100%" fill="#fff"/>'] + body + b2 + ['</svg>']
open(out,'w',encoding='utf-8').write('\n'.join(svg))
print('pins', len(pins), 'parts', len(parts))
