"""Launch a native review at the minimum window size from its first frame."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('script', help='Godot review script, relative to the project')
    parser.add_argument('args', nargs=argparse.REMAINDER)
    options = parser.parse_args()
    script = Path(options.script)
    script = script if script.is_absolute() else ROOT / script
    if not script.is_file():
        parser.error(f'Review script does not exist: {script}')
    godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
    if not godot:
        parser.error('Godot executable not found')
    command = [godot, '--path', str(ROOT), '--windowed', '--resolution', '384x216',
               '--position', '10000,10000', '-s', str(script)]
    if options.args:
        command += options.args if options.args[0] == '--' else ['--', *options.args]
    raise SystemExit(subprocess.run(command, cwd=ROOT).returncode)

if __name__ == '__main__':
    main()
