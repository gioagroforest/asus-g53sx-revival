"""Write a disk image to a physical disk and verify it by reading it back.

Usage: python -I write_image.py <image> <disk_number>
The caller must have already validated the disk and cleared its partitions.
The first 1 MiB, which holds the partition table, is written last, so Windows
does not try to mount a half-written disk.
"""
import hashlib
import os
import sys
import time

CHUNK = 1024 * 1024
SECTOR = 512


def log(msg):
    print(f"{time.strftime('%H:%M:%S')} {msg}", flush=True)


def pad(block):
    extra = len(block) % SECTOR
    return block + b"\0" * (SECTOR - extra) if extra else block


def main():
    image_path, disk_number = sys.argv[1], int(sys.argv[2])
    device = rf"\\.\PhysicalDrive{disk_number}"
    size = os.path.getsize(image_path)
    log(f"source {image_path} ({size} bytes), target {device}")

    source_hash = hashlib.sha256()
    fd = os.open(device, os.O_RDWR | os.O_BINARY)
    try:
        with open(image_path, "rb") as image:
            first = image.read(CHUNK)
            source_hash.update(first)
            os.lseek(fd, len(first), os.SEEK_SET)
            written = len(first)
            next_report = 128 * CHUNK
            while True:
                block = image.read(CHUNK)
                if not block:
                    break
                source_hash.update(block)
                os.write(fd, pad(block))
                written += len(block)
                if written >= next_report:
                    log(f"written {written // CHUNK} / {size // CHUNK} MiB")
                    next_report += 128 * CHUNK
        os.fsync(fd)
        os.lseek(fd, 0, os.SEEK_SET)
        os.write(fd, pad(first))
        os.fsync(fd)
        log("write complete, flushed")
    finally:
        os.close(fd)

    time.sleep(3)
    log("reading back to verify")
    read_hash = hashlib.sha256()
    fd = os.open(device, os.O_RDONLY | os.O_BINARY)
    try:
        remaining = size
        while remaining > 0:
            block = os.read(fd, min(CHUNK, remaining + (SECTOR - remaining % SECTOR) % SECTOR))
            if not block:
                raise RuntimeError(f"short read with {remaining} bytes left")
            read_hash.update(block[:remaining])
            remaining -= min(len(block), remaining)
    finally:
        os.close(fd)

    log(f"source sha256    {source_hash.hexdigest()}")
    log(f"read-back sha256 {read_hash.hexdigest()}")
    if source_hash.digest() != read_hash.digest():
        log("RESULT: FAILED, the stick does not match the image")
        return 1
    log("RESULT: OK, the stick matches the image")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # stdout only, so the caller's transcript records it
        log(f"RESULT: FAILED, {type(exc).__name__}: {exc}")
        sys.exit(1)
