"""Install the pinned official Linux editor and only the Web release template."""
from pathlib import Path
import hashlib
import os
import platform
import shutil
import tempfile
import urllib.request
import zipfile

VERSION = "4.7"
BASE = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable"
ASSETS = {
    f"Godot_v{VERSION}-stable_linux.x86_64.zip": "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c",
    f"Godot_v{VERSION}-stable_export_templates.tpz": "9714459dc071907c0f3d5f17d608faf69e7cda21331fc5d39c4503ffa4e99eec",
}


def main():
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        raise SystemExit("This installer is for the GitHub Linux x86_64 runner.")
    data = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    binary = data / "poke-journey-godot" / VERSION / "godot"
    template = data / "godot/export_templates" / f"{VERSION}.stable/web_nothreads_release.zip"
    with tempfile.TemporaryDirectory(prefix="poke-journey-godot-") as tmp:
        for name, expected in ASSETS.items():
            target = binary if name.endswith("linux.x86_64.zip") else template
            if target.is_file():
                continue
            archive = Path(tmp) / name
            digest = hashlib.sha256()
            request = urllib.request.Request(f"{BASE}/{name}", headers={"User-Agent": "poke-journey-ci"})
            print(f"Downloading official {name}", flush=True)
            with urllib.request.urlopen(request, timeout=60) as response, archive.open("wb") as output:
                while chunk := response.read(1024 * 1024):
                    output.write(chunk)
                    digest.update(chunk)
            if digest.hexdigest() != expected:
                raise SystemExit(f"SHA-256 mismatch for {name}")
            member = f"Godot_v{VERSION}-stable_linux.x86_64" if target == binary else "templates/web_nothreads_release.zip"
            target.parent.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(archive) as bundle, bundle.open(member) as source, target.open("wb") as output:
                shutil.copyfileobj(source, output)
            if target == binary:
                target.chmod(0o755)
            archive.unlink()
    (template.parent / "version.txt").write_text(f"{VERSION}.stable\n")
    print(f"Godot editor: {binary}", flush=True)


if __name__ == "__main__":
    main()
