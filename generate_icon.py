#!/usr/bin/env python3
"""Generate a simple app icon for MeetingBar using Core Graphics via PyObjC."""
import subprocess
import sys
import os
import tempfile

def generate_icon(output_dir):
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    iconset_dir = tempfile.mkdtemp(suffix=".iconset")

    for size in sizes:
        # Create a simple calendar icon using sips and a temp image
        svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg width="{size}" height="{size}" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="8" y="15" width="84" height="77" rx="12" fill="#1a1a2e"/>
  <rect x="8" y="15" width="84" height="24" rx="12" fill="#e94560"/>
  <rect x="8" y="27" width="84" height="12" fill="#e94560"/>
  <circle cx="28" cy="10" r="5" fill="#555"/>
  <circle cx="72" cy="10" r="5" fill="#555"/>
  <rect x="22" y="50" width="14" height="10" rx="2" fill="#4a4a6a"/>
  <rect x="43" y="50" width="14" height="10" rx="2" fill="#4a4a6a"/>
  <rect x="64" y="50" width="14" height="10" rx="2" fill="#4a4a6a"/>
  <rect x="22" y="68" width="14" height="10" rx="2" fill="#4a4a6a"/>
  <rect x="43" y="68" width="14" height="10" rx="2" fill="#e94560"/>
  <rect x="64" y="68" width="14" height="10" rx="2" fill="#4a4a6a"/>
</svg>'''

        svg_path = os.path.join(iconset_dir, f"temp_{size}.svg")
        with open(svg_path, "w") as f:
            f.write(svg)

        # Convert SVG to PNG using built-in qlmanage or rsvg-convert
        png_name = f"icon_{size}x{size}.png"
        if size <= 512:
            png_name_1x = f"icon_{size}x{size}.png"
        png_path = os.path.join(iconset_dir, png_name)

        # Try using rsvg-convert, then qlmanage as fallback
        converted = False
        for cmd in [
            ["rsvg-convert", "-w", str(size), "-h", str(size), svg_path, "-o", png_path],
            ["sips", "-s", "format", "png", "--resampleWidth", str(size), svg_path, "--out", png_path],
        ]:
            try:
                subprocess.run(cmd, capture_output=True, check=True)
                converted = True
                break
            except (subprocess.CalledProcessError, FileNotFoundError):
                continue

        if not converted:
            # Fallback: create a simple colored PNG with Python
            create_simple_png(png_path, size)

        os.remove(svg_path)

    # Rename files to iconutil format
    rename_map = {
        16: "icon_16x16.png",
        32: "icon_16x16@2x.png",
        64: "icon_32x32@2x.png",
        128: "icon_128x128.png",
        256: "icon_128x128@2x.png",
        512: "icon_256x256@2x.png",
        1024: "icon_512x512@2x.png",
    }

    # Also need these base sizes
    base_sizes = {
        32: "icon_32x32.png",
        256: "icon_256x256.png",
        512: "icon_512x512.png",
    }

    final_iconset = tempfile.mkdtemp(suffix=".iconset")

    for size, name in {**rename_map, **base_sizes}.items():
        src = os.path.join(iconset_dir, f"icon_{size}x{size}.png")
        dst = os.path.join(final_iconset, name)
        if os.path.exists(src):
            subprocess.run(["cp", src, dst])

    # Convert iconset to icns
    icns_path = os.path.join(output_dir, "AppIcon.icns")
    try:
        subprocess.run(["iconutil", "-c", "icns", final_iconset, "-o", icns_path], check=True)
        print(f"Icon created: {icns_path}")
    except subprocess.CalledProcessError:
        print("Warning: iconutil failed, app will use default icon")

    # Cleanup
    subprocess.run(["rm", "-rf", iconset_dir, final_iconset])


def create_simple_png(path, size):
    """Create a minimal valid PNG with a colored rectangle."""
    import struct
    import zlib

    width = height = size
    # Simple: solid dark blue background
    raw_data = b""
    for y in range(height):
        raw_data += b"\x00"  # filter byte
        for x in range(width):
            raw_data += b"\x1a\x1a\x2e\xff"  # RGBA dark blue

    def make_chunk(chunk_type, data):
        chunk = chunk_type + data
        return struct.pack(">I", len(data)) + chunk + struct.pack(">I", zlib.crc32(chunk) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += make_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += make_chunk(b"IDAT", zlib.compress(raw_data))
    png += make_chunk(b"IEND", b"")

    with open(path, "wb") as f:
        f.write(png)


if __name__ == "__main__":
    output = sys.argv[1] if len(sys.argv) > 1 else "."
    generate_icon(output)
