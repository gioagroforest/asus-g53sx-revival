"""Search all decompressed BIOS modules for POST warning/halt messages.
Usage: python -I post_strings.py <bios_image>"""
import sys, re, runpy, io, contextlib
img = sys.argv[1]
sys.argv = ['ffs.py', img]
with contextlib.redirect_stdout(io.StringIO()):
    g = runpy.run_path('ffs.py')
keys = re.compile(r'(press\s*f\d|press\s*(any|del|enter)|cmos|checksum|keyboard|fan|thermal|overheat|temperature|memory|dimm|battery|halt|error|fail|vga|no\s*boot|boot\s*device|reboot|default|password|warning)', re.I)
seen = {}
for owner, kind, ctype, blob in g['found_blobs']:
    if kind not in ('pe32', 'te', 'raw'): continue
    name = owner.get('ui', '?')
    strs = [m.group().decode('utf-16le') for m in re.finditer(rb'(?:[\x20-\x7e]\x00){6,}', blob)]
    strs += [m.group().decode() for m in re.finditer(rb'[\x20-\x7e]{10,}', blob)]
    for s in strs:
        s = s.strip()
        if keys.search(s) and not s.startswith(('EFI_', 'PXE-')) and sum(c.isalpha() for c in s) >= 8:
            seen.setdefault(s, set()).add(name)
for s, mods in sorted(seen.items(), key=lambda kv: (sorted(kv[1])[0], kv[0])):
    print(f"[{','.join(sorted(mods))[:40]}] {s[:150]}")
