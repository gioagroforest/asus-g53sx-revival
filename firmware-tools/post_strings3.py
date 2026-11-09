import sys, re, runpy, io, contextlib
img = sys.argv[1]
sys.argv = ['ffs.py', img]
with contextlib.redirect_stdout(io.StringIO()):
    g = runpy.run_path('ffs.py')
big = max((b for o, k, c, b in g['found_blobs'] if k == 'lzma'), key=len)
print('decompressed main firmware:', len(big), 'bytes')
keys = re.compile(r'(press\s*<?f\d|press\s*<?(del|esc|enter|any)|\bF1\b|cmos|checksum|keyboard\s*(error|not)|no\s*keyboard|fan\s*(error|fail)|thermal|overheat|memory\s*(error|size|fail|changed)|dimm|battery|halt|default\s*setting|load(ed)?\s*default|post\s*error|not\s*detected|over\s*clock|clock\s*fail)', re.I)
out = []
for m in re.finditer(rb'(?:[\x20-\x7e]\x00){5,}', big):
    s = m.group().decode('utf-16le').strip()
    if keys.search(s) and s not in out: out.append(s)
for m in re.finditer(rb'[\x20-\x7e]{8,}', big):
    s = m.group().decode().strip()
    if keys.search(s) and s not in out and not s.startswith('#C'): out.append(s)
for s in out:
    if re.search(r'(AMT|Intel\(R\) ME|MEBx|Remote|Provision|TS-on-DIMM|DIMM\d Temp|Channel \d DIMM)', s): continue
    print('  ', s[:150])
