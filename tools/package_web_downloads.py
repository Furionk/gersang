"""Versioned static chunks; no server code or gameplay/save mutation."""
import hashlib
import json
from pathlib import Path
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path)
parser.add_argument("--chunk-mib", type=int, choices=range(1, 5), default=2)
args = parser.parse_args()
chunk_bytes = args.chunk_mib * 1024 * 1024
output = args.output.resolve()
source = Path(__file__).resolve().parent.parent
files = [output / "index.wasm", output / "index.pck"]
release = hashlib.sha256(b"".join(hashlib.sha256(p.read_bytes()).digest() for p in files) + (b"" if args.chunk_mib == 2 else str(args.chunk_mib).encode())).hexdigest()[:16]
folder = output / "downloads" / release
folder.mkdir(parents=True, exist_ok=True)
manifest = {"version": 1, "release": release, "files": []}
for path in files:
    data = path.read_bytes()
    record = {"name": path.name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "parts": []}
    for index, offset in enumerate(range(0, len(data), chunk_bytes)):
        chunk = data[offset:offset + chunk_bytes]
        name = f"{path.name}.{index:04d}.bin"
        (folder / name).write_bytes(chunk)
        record["parts"].append({"name": name, "bytes": len(chunk), "sha256": hashlib.sha256(chunk).hexdigest()})
    manifest["files"].append(record)
(folder / "manifest.json").write_text(json.dumps(manifest, separators=(",", ":")), encoding="utf-8")
loader = (source / "features/web/download_loader.js").read_bytes()
loader_name = "download-loader." + hashlib.sha256(loader).hexdigest()[:16] + ".js"
(output / loader_name).write_bytes(loader)
html_path = output / "index.html"
html = html_path.read_text(encoding="utf-8")
if "__GERSANG_LOADER__" not in html or "__GERSANG_MANIFEST__" not in html:
    raise RuntimeError("Export shell is missing versioned download placeholders")
html_path.write_text(html.replace("__GERSANG_LOADER__", loader_name).replace("__GERSANG_MANIFEST__", f"downloads/{release}/manifest.json"), encoding="utf-8")
(output / ".htaccess").write_text('''# Static Godot web assets, scoped to /gersang/ only.
AddType application/wasm .wasm
AddType application/octet-stream .pck .bin
# Small binary segments do not need streaming compression.
<IfModule mod_setenvif.c>
SetEnvIfNoCase Request_URI "\\.(bin|pck|wasm)$" no-gzip=1
</IfModule>
<IfModule mod_headers.c>
<Files "index.html">
Header set Cache-Control "no-cache, must-revalidate"
</Files>
</IfModule>
''', encoding="utf-8")
# Read every written segment and reconstruct each complete asset before delivery.
for record in manifest["files"]:
    joined = b"".join((folder / part["name"]).read_bytes() for part in record["parts"])
    if len(joined) != record["bytes"] or hashlib.sha256(joined).hexdigest() != record["sha256"]:
        raise RuntimeError("Packaged asset verification failed: " + record["name"])
print(f"WEB_SEGMENTS_VERIFIED release={release} chunks={sum(len(f['parts']) for f in manifest['files'])}")
