"""Minimal UEFI firmware-volume walker: lists modules (UI names) and section/compression types,
decompresses LZMA GUID-defined sections with Python's lzma, and searches all data for recovery names.
Usage: python -I ffs.py <bios_image>"""
import sys, struct, uuid, lzma, re
data = open(sys.argv[1], 'rb').read()
LZMA_GUID = uuid.UUID('EE4E5898-3914-4259-9D6E-DC7BD79403CF')
found_blobs = []

def lzma_raw(buf):
    props = buf[0]; dsz = struct.unpack('<I', buf[1:5])[0]; ulen = struct.unpack('<Q', buf[5:13])[0]
    lc = props % 9; lp = (props // 9) % 5; pb = props // 45
    filt = [{'id': lzma.FILTER_LZMA1, 'lc': lc, 'lp': lp, 'pb': pb, 'dict_size': dsz}]
    out = lzma.LZMADecompressor(format=lzma.FORMAT_RAW, filters=filt).decompress(bytes(buf[13:]), max_length=ulen)
    return out[:ulen]
def walk_sections(buf, depth, owner):
    off = 0
    while off + 4 <= len(buf):
        size = int.from_bytes(buf[off:off+3], 'little'); typ = buf[off+3]
        if size < 4 or off + size > len(buf): break
        body = buf[off+4:off+size]
        if typ == 0x15:
            owner['ui'] = body.decode('utf-16le', 'replace').rstrip('\x00')
        elif typ == 0x01:
            ulen, ctype = struct.unpack_from('<IB', body)
            owner.setdefault('notes', []).append(f'COMPRESSED(type={ctype}, {ulen}B)')
            payload = bytes(body[5:])
            if ctype == 2:
                try:
                    dec = lzma_raw(payload)
                    owner['notes'].append(f'LZMA->{len(dec)}B')
                    found_blobs.append((owner, 'lzma', 2, dec))
                    walk_sections(dec, depth+1, owner)
                except Exception as e:
                    owner['notes'].append(f'LZMA-FAIL {e}')
                    found_blobs.append((owner, 'compressed', ctype, payload))
            elif ctype == 0:
                walk_sections(payload, depth+1, owner)
            else:
                found_blobs.append((owner, 'compressed', ctype, payload))
        elif typ == 0x02:
            g = uuid.UUID(bytes_le=bytes(body[:16])); doff, attr = struct.unpack_from('<HH', body, 16)
            inner = buf[off+doff:off+size]
            if g == LZMA_GUID:
                try:
                    dec = lzma_raw(bytes(inner))
                    owner.setdefault('notes', []).append(f'LZMA->{len(dec)}B')
                    found_blobs.append((owner, 'lzma', 0, dec))
                    walk_sections(dec, depth+1, owner)
                except Exception as e:
                    owner.setdefault('notes', []).append(f'LZMA-FAIL {e}')
            else:
                owner.setdefault('notes', []).append(f'GUIDED {g}')
                walk_sections(inner, depth+1, owner)
        elif typ == 0x17:
            owner.setdefault('notes', []).append('FV-IMAGE')
            walk_fv(body, depth+1)
        elif typ in (0x10, 0x12, 0x19):
            found_blobs.append((owner, {0x10:'pe32',0x12:'te',0x19:'raw'}[typ], 0, body))
        off += size; off = (off + 3) & ~3
def walk_fv(fv, depth):
    if fv[40:44] != b'_FVH': return
    fvlen = struct.unpack_from('<Q', fv, 32)[0]; hlen = struct.unpack_from('<H', fv, 48)[0]
    ext = struct.unpack_from('<H', fv, 52)[0]
    off = hlen
    if ext:
        extsize = struct.unpack_from('<I', fv, ext+16)[0]; off = ext + extsize
    off = (off + 7) & ~7
    print('  '*depth + f'FV len=0x{fvlen:x}')
    while off + 24 <= min(len(fv), fvlen):
        name = fv[off:off+16]
        if name == b'\xff'*16: break
        ftype = fv[off+18]; fsize = int.from_bytes(fv[off+20:off+23], 'little')
        if fsize < 24: break
        owner = {'guid': str(uuid.UUID(bytes_le=bytes(name))), 'type': ftype}
        if ftype not in (0xf0, 0x01):  # skip pad and raw files' sections
            walk_sections(fv[off+24:off+fsize], depth+1, owner)
        print('  '*(depth+1) + f"type=0x{ftype:02x} {owner.get('ui','?'):28s} {owner['guid']} {' '.join(owner.get('notes', []))}")
        off += fsize; off = (off + 7) & ~7
for m in re.finditer(rb'_FVH', data):
    base = m.start() - 40
    if base >= 0 and struct.unpack_from('<Q', data, base+32)[0] <= len(data) - base:
        print(f'== FV at 0x{base:06x}')
        walk_fv(data[base:], 0)
print('\n== Searching every module (decompressed where possible) for recovery-name strings')
pat = re.compile(rb'[A-Z0-9_]{2,8}(?:\.| {1,6})(?:BIN|ROM|CAP)|AMIBOOT|[A-Z0-9_]{2,8}\x00?\.\x00?B\x00?I\x00?N', re.I)
for owner, kind, ctype, blob in found_blobs:
    for mm in pat.finditer(blob):
        s = max(0, mm.start()-40)
        ctx = ''.join(chr(b) if 32 <= b < 127 else '.' for b in blob[s:mm.end()+40])
        print(f"  {owner.get('ui','?')} [{kind}]: {mm.group()!r}  ctx: {ctx}")
