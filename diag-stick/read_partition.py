"""Copy one partition's raw bytes from a physical disk to a file. Opens the disk read-only.

Usage: python -I read_partition.py <disk_number> <offset> <length> <output_file>
"""
import hashlib
import os
import sys
import time

CHUNK = 1024 * 1024


def log(msg):
    print(f"{time.strftime('%H:%M:%S')} {msg}", flush=True)


def main():
    disk, offset, length, out = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    device = rf"\\.\PhysicalDrive{disk}"
    log(f"reading {length} bytes at offset {offset} from {device}")
    digest = hashlib.sha256()
    fd = os.open(device, os.O_RDONLY | os.O_BINARY)
    try:
        os.lseek(fd, offset, os.SEEK_SET)
        with open(out, "wb") as w:
            remaining = length
            done = 0
            next_report = 256 * CHUNK
            while remaining > 0:
                block = os.read(fd, min(CHUNK, remaining))
                if not block:
                    raise RuntimeError(f"short read with {remaining} bytes left")
                w.write(block)
                digest.update(block)
                remaining -= len(block)
                done += len(block)
                if done >= next_report:
                    log(f"read {done // CHUNK} / {length // CHUNK} MiB")
                    next_report += 256 * CHUNK
    finally:
        os.close(fd)
    log(f"sha256 {digest.hexdigest()}")
    log("RESULT: OK")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        log(f"RESULT: FAILED, {type(exc).__name__}: {exc}")
        sys.exit(1)
