"""Compare partition-table regions (first MiB) of several disk headers.
Usage: python -I diff_headers.py <reference_iso> <saved_first_mib> [<other_first_mib>...]"""
import sys, struct, uuid, zlib
def mbr(b):
    out = [f"  MBR disk signature 0x{struct.unpack_from('<I', b, 0x1B8)[0]:08x}, boot sig {b[510:512].hex()}"]
    for i in range(4):
        e = b[0x1BE + 16*i: 0x1BE + 16*(i+1)]
        if any(e):
            out.append(f"  MBR[{i}] boot=0x{e[0]:02x} type=0x{e[4]:02x} start={struct.unpack_from('<I', e, 8)[0]} sectors={struct.unpack_from('<I', e, 12)[0]}")
    return out
def gpt(b):
    h = b[512:1024]
    if h[:8] != b'EFI PART': return ['  (no GPT header at LBA 1)']
    rev, hsz, crc, _, cur, alt, first, last = struct.unpack_from('<IIIIQQQQ', h, 8)
    dguid = uuid.UUID(bytes_le=bytes(h[56:72])); ent_lba, n, esz, ecrc = struct.unpack_from('<QIII', h, 72)
    hh = bytearray(h[:hsz]); hh[16:20] = b'\0\0\0\0'
    out = [f"  GPT cur={cur} alt={alt} usable={first}..{last} diskGUID={dguid} entries@{ent_lba} n={n} size={esz}",
           f"      headerCRC ok={zlib.crc32(bytes(hh)) == crc}  entriesCRC=0x{ecrc:08x}"]
    for i in range(n):
        off = ent_lba*512 + i*esz
        e = b[off:off+esz]
        if len(e) < esz or not any(e[:16]): continue
        t = uuid.UUID(bytes_le=bytes(e[:16])); pg = uuid.UUID(bytes_le=bytes(e[16:32]))
        s, en, attr = struct.unpack_from('<QQQ', e, 32)
        name = e[56:128].decode('utf-16le', 'replace').rstrip('\x00')
        out.append(f"   part{i+1}: type={t} {s}..{en} attr=0x{attr:x} name={name!r} guid={pg}")
    return out
ref = open(sys.argv[1], 'rb').read(1048576)
for path in sys.argv[2:]:
    b = open(path, 'rb').read(1048576)
    print(f"===== {path}")
    diffs = [i for i in range(len(ref)) if ref[i] != b[i]]
    print(f"  bytes differing from ISO: {len(diffs)}")
    if diffs:
        runs = []; start = prev = diffs[0]
        for d in diffs[1:]:
            if d != prev + 1:
                runs.append((start, prev)); start = d
            prev = d
        runs.append((start, prev))
        for s, e in runs[:40]:
            print(f"    0x{s:05x}-0x{e:05x} (sector {s//512}, {e-s+1} bytes): iso={ref[s:e+1][:24].hex()} now={b[s:e+1][:24].hex()}")
        if len(runs) > 40: print(f"    ... {len(runs)} runs in total")
    for line in mbr(b) + gpt(b): print(line)
print("===== reference ISO")
for line in mbr(ref) + gpt(ref): print(line)
