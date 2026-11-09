"""List and extract BIOS zips into separate folders, then scan images for recovery-name strings.
Usage: python -I inspect_bios.py <download_dir> <extract_root>"""
import os, re, sys, zipfile, hashlib
dl, root = sys.argv[1], sys.argv[2]
for z in sorted(os.listdir(dl)):
    if not z.endswith('.zip'): continue
    zp = os.path.join(dl, z)
    out = os.path.join(root, z[:-4])
    os.makedirs(out, exist_ok=True)
    with zipfile.ZipFile(zp) as zf:
        for info in zf.infolist():
            name = os.path.basename(info.filename)
            if not name or '..' in info.filename: continue
            data = zf.read(info)
            with open(os.path.join(out, name), 'wb') as w: w.write(data)
            print(f"{z}: {info.filename}  {info.file_size} bytes  sha256 {hashlib.sha256(data).hexdigest()}")
            # ASCII strings that look like file names
            hits = set(m.group().decode() for m in re.finditer(rb'[A-Za-z0-9_\-]{3,8}(?: {0,5})\.?(?:BIN|ROM|CAP|bin|rom|cap)\b', data))
            print("   filename-like ASCII:", sorted(hits)[:40])
            # FAT 8.3 padded form e.g. 'G53SX   BIN'
            fat = set(m.group().decode() for m in re.finditer(rb'[A-Z0-9_]{1,8} {0,7}(?:BIN|ROM|CAP)(?=[\x00\x20])', data) if len(m.group())==11)
            print("   FAT-8.3-like:", sorted(fat)[:40])
            # UTF-16LE names
            u16 = set()
            for m in re.finditer(rb'(?:[A-Za-z0-9_\-]\x00){3,8}\.\x00(?:B\x00I\x00N\x00|R\x00O\x00M\x00|C\x00A\x00P\x00|b\x00i\x00n\x00|r\x00o\x00m\x00)', data):
                u16.add(m.group().decode('utf-16le'))
            print("   UTF-16 filename-like:", sorted(u16)[:40])
            for sig in (b'$FID', b'_FVH', b'AMIBIOS', b'Aptio', b'InsydeH2O', b'Phoenix', b'$AMIBIOSE', b'G53S', b'Recovery', b'RECOVERY', b'AMIBOOT'):
                c = data.count(sig)
                if c: print(f"   {sig.decode()!r} x{c}")
