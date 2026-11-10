"""Open the HGSS map explorer at 384×216. Does not load player saves."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--header', type=int, default=60, help='HGSS map header ID, default New Bark Town')
    parser.add_argument('--pallet', action='store_true', help='Open the isolated Pallet Town sample with current player and HUD')
    parser.add_argument('--style', action='store_true', help='Open Johto with the candidate common style, current player and HUD')
    args = parser.parse_args()
    godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
    if not godot:
        mac = Path('/Applications/Godot.app/Contents/MacOS/Godot')
        if mac.is_file(): godot = str(mac)
    if not godot: parser.error('Godot executable not found; set GODOT_BIN')
    env = dict(os.environ, HGSS_HEADER=str(args.header))
    scene = 'res://scenes/hgss_pallet_sample.tscn' if args.pallet else 'res://scenes/visual_style_sample.tscn' if args.style else 'res://scenes/johto_map_preview.tscn'
    raise SystemExit(subprocess.run([godot, '--path', str(ROOT), '--windowed', '--resolution', '384x216',
                                     scene], cwd=ROOT, env=env).returncode)


if __name__ == '__main__': main()
