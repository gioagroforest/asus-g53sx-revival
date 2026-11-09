"""Dump UTF-16 and ASCII strings of named modules from a BIOS image, using ffs.py's walker.
Usage: python -I dump_module.py <bios_image> <ModuleName> [<ModuleName>...]"""
import sys, re, runpy
sys_argv = sys.argv[:]
sys.argv = ['ffs.py', sys_argv[1]]
import io, contextlib
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    g = runpy.run_path('ffs.py')
blobs = g['found_blobs']
for want in sys_argv[2:]:
    for owner, kind, ctype, blob in blobs:
        if owner.get('ui') == want and kind in ('pe32', 'te', 'raw'):
            u = [m.group().decode('utf-16le') for m in re.finditer(rb'(?:[\x20-\x7e]\x00){5,}', blob)]
            a = [m.group().decode() for m in re.finditer(rb'[\x20-\x7e]{8,}', blob) if sum(c.isalpha() for c in m.group().decode()) >= 6]
            print(f'===== {want} [{kind}] {len(blob)} bytes')
            print('UTF-16:', u)
            print('ASCII:', a[:80])
