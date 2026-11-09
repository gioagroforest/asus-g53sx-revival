import sys, re, runpy, io, contextlib
img = sys.argv[1]
sys.argv = ['ffs.py', img]
with contextlib.redirect_stdout(io.StringIO()):
    g = runpy.run_path('ffs.py')
want = {'AMITSE','CSMCORE','CmosManagerSmm','OEMDXE','ASUSBS','ASUSRT','BIOSLD','Setup','EcPs2Kbd','SBRun','MemoryInit',
        'NBPEI','SBPEI','ASUSPei','PlatformInfoPei','CORE_DXE','ASUSFAKESMI','PowerManagementDxe','Dppm','RefVer','OEMPEI',
        'CpuPei','CpuPeiBeforeMem','SaInitPeim','PchInitPeim','CsmVideo','BIOSBLKIO','AHCI','UHCD','USBRT','ASUSHDDPW','IdeSecurity'}
keys = re.compile(r'(press|f1|f2|del\b|cmos|checksum|keyboard|fan|thermal|overheat|memory|dimm|halt|error|fail|vga|video|boot\s*device|reboot|default|warning|insert|select|bad|not\s*found|no\s)', re.I)
for owner, kind, ctype, blob in g['found_blobs']:
    name = owner.get('ui', '?')
    if name not in want or kind not in ('pe32', 'te', 'raw'): continue
    strs = [m.group().decode('utf-16le') for m in re.finditer(rb'(?:[\x20-\x7e]\x00){5,}', blob)]
    strs += [m.group().decode() for m in re.finditer(rb'[\x20-\x7e]{8,}', blob)]
    hits = []
    for s in strs:
        s = s.strip()
        if keys.search(s) and not s.startswith(('EFI_', 'PXE-')) and sum(c.isalpha() for c in s) >= 6 and s not in hits:
            hits.append(s)
    if hits:
        print(f"===== {name} [{kind}] ({len(hits)})")
        for s in hits[:45]: print("   ", s[:140])
