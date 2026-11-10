"""Validate the static Pages artifact before uploading it."""
from pathlib import Path
import json
import re
import sys


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    for name in ["index.html", "index.js", "index.wasm", "index.pck"]:
        path = root / name
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"Missing Web export: {name}")
    html = (root / "index.html").read_text()
    if not re.search(r"const GODOT_THREADS_ENABLED = false;", html):
        raise SystemExit("Pages export must use the single-threaded template.")
    config = json.loads(re.search(r"const GODOT_CONFIG = (\{.*\});", html).group(1))
    if config.get("serviceWorker"):
        raise SystemExit("Unexpected service worker; Pages uses a single-threaded build.")
    (root / ".nojekyll").touch()
    files = [p for p in root.rglob("*") if p.is_file()]
    if any(p.is_symlink() for p in root.rglob("*")):
        raise SystemExit("The Pages artifact must not contain symbolic links.")
    total = sum(p.stat().st_size for p in files)
    if total >= 1_000_000_000:
        raise SystemExit(f"Web export exceeds the 1 GB Pages site limit: {total} bytes")
    print(json.dumps({"files": len(files), "bytes": total, "single_threaded": True}))


if __name__ == "__main__":
    main()
