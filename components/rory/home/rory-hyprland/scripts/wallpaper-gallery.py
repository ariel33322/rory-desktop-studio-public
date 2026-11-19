#!/usr/bin/env python3
"""List local wallpaper files that have a Qt image reader on this system."""

import json
import os
import sys


SUPPORTED_EXTENSIONS = {
    ".3fr", ".apng", ".arw", ".avif", ".bmp", ".cr2", ".cr3", ".dcr",
    ".dds", ".dib", ".dng", ".erf", ".exr", ".fff", ".gif", ".hdr",
    ".heic", ".heif", ".icns", ".ico", ".iff", ".iiq", ".j2c", ".j2k",
    ".jfif", ".jng", ".jp2", ".jpe", ".jpeg", ".jpf", ".jpg", ".jpm",
    ".jpx", ".jxl", ".k25", ".kdc", ".kra", ".lbm", ".mef", ".mng",
    ".mos", ".mrw", ".nef", ".nrw", ".orf", ".pbm", ".pcx", ".pef",
    ".pfm", ".pgm", ".pic", ".png", ".ppm", ".psd", ".pxr", ".qoi",
    ".raf", ".ras", ".raw", ".rgb", ".rgba", ".rw2", ".rwl", ".sct",
    ".sr2", ".srf", ".srw", ".svg", ".svgz", ".tga", ".tif", ".tiff",
    ".tim", ".wbmp", ".webp", ".xbm", ".xcf", ".xpm", ".x3f",
}


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else ""
    paths = []
    try:
        with os.scandir(folder) as entries:
            paths = sorted(
                (entry.path for entry in entries
                 if not entry.name.startswith(".")
                 and entry.is_file()
                 and os.path.splitext(entry.name)[1].lower() in SUPPORTED_EXTENSIONS),
                key=str.casefold,
            )
    except OSError:
        pass
    paths.sort(key=str.casefold)
    print(json.dumps(paths, ensure_ascii=False))


if __name__ == "__main__":
    main()
