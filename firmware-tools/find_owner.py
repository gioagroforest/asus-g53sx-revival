import sys, re, runpy, io, contextlib
img = sys.argv[1]; needles = sys.argv[2:]
sys.argv = ['ffs.py', img]
with contextlib.redirect_stdout(io.StringIO()):
    g = runpy.run_path('ffs.py')
for n in needles:
    for enc in ('utf-16le', 'ascii'):
        pat = n.encode(enc)
        for owner, kind, ctype, blob in g['found_blobs']:
            if kind == 'lzma': continue
            i = blob.find(pat)
            if i < 0: continue
            # neighbouring strings in the same encoding
            win = blob[max(0, i-600): i+900]
            if enc == 'utf-16le':
                near = [m.group().decode('utf-16le') for m in re.finditer(rb'(?:[\x20-\x7e]\x00){4,}', win)]
            else:
                near = [m.group().decode() for m in re.finditer(rb'[\x20-\x7e]{4,}', win)]
            print(f"'{n}' ({enc}) in module {owner.get('ui','?')} [{kind}] guid {owner['guid']}")
            print('   nearby:', near[:30])
