#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$ROOT_DIR/mods-config.yaml"
BUILD_DIR="$ROOT_DIR/build"
MODS_DIR="$BUILD_DIR/mods"

rm -rf "$BUILD_DIR"
mkdir -p "$MODS_DIR"

# Parse config with python3 (available on ubuntu-latest)
PACK_NAME=$(python3 -c "
import yaml, sys
with open('$CONFIG') as f:
    c = yaml.safe_load(f)
print(c['pack_name'])
")
PACK_VERSION=$(python3 -c "
import yaml, sys
with open('$CONFIG') as f:
    c = yaml.safe_load(f)
print(c['pack_version'])
")
MC_VERSION=$(python3 -c "
import yaml, sys
with open('$CONFIG') as f:
    c = yaml.safe_load(f)
print(c['minecraft_version'])
")
FABRIC_VERSION=$(python3 -c "
import yaml, sys
with open('$CONFIG') as f:
    c = yaml.safe_load(f)
print(c['fabric_loader_version'])
")

echo "Building $PACK_NAME v$PACK_VERSION"
echo "Minecraft $MC_VERSION / Fabric Loader $FABRIC_VERSION"

# Download mods and compute hashes
FILES_JSON="[]"

python3 -c "
import yaml, sys
with open('$CONFIG') as f:
    c = yaml.safe_load(f)
for m in c['mods']:
    print(m['name'] + '|' + m['file'] + '|' + m['url'] + '|' + m['env']['client'] + '|' + m['env']['server'])
" | while IFS='|' read -r name file url client server; do
    echo "  Downloading $name ..."
    curl -sL -o "$MODS_DIR/$file" "$url"

    sha1=$(shasum -a 1 "$MODS_DIR/$file" 2>/dev/null | cut -d' ' -f1 || sha1sum "$MODS_DIR/$file" | cut -d' ' -f1)
    sha512=$(shasum -a 512 "$MODS_DIR/$file" 2>/dev/null | cut -d' ' -f1 || sha512sum "$MODS_DIR/$file" | cut -d' ' -f1)
    filesize=$(wc -c < "$MODS_DIR/$file" | tr -d ' ')

    echo "$file|$sha1|$sha512|$filesize|$url|$client|$server" >> "$BUILD_DIR/mod_hashes.txt"
done

# Generate modrinth.index.json
python3 << 'PYEOF'
import json, os

build_dir = os.environ.get("BUILD_DIR", "build")
config_path = os.environ.get("CONFIG", "mods-config.yaml")

import yaml
with open(config_path) as f:
    config = yaml.safe_load(f)

hashes_file = os.path.join(build_dir, "mod_hashes.txt")
files = []
with open(hashes_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split("|")
        filename, sha1, sha512, filesize, url, client, server = parts
        files.append({
            "path": f"mods/{filename}",
            "hashes": {
                "sha1": sha1,
                "sha512": sha512
            },
            "env": {
                "client": client,
                "server": server
            },
            "downloads": [url],
            "fileSize": int(filesize)
        })

index = {
    "formatVersion": 1,
    "game": "minecraft",
    "versionId": config["pack_version"],
    "name": config["pack_name"],
    "summary": "jln-hut.page Minecraft サーバー推奨MODパック",
    "files": files,
    "dependencies": {
        "minecraft": config["minecraft_version"],
        "fabric-loader": config["fabric_loader_version"]
    }
}

output_path = os.path.join(build_dir, "modrinth.index.json")
with open(output_path, "w") as f:
    json.dump(index, f, indent=2, ensure_ascii=False)

print(f"Generated {output_path} with {len(files)} mods")
PYEOF

# Create overrides directory (empty)
mkdir -p "$BUILD_DIR/overrides"

# Build mrpack (zip)
cd "$BUILD_DIR"
zip -r "$ROOT_DIR/jln-hut-modpack.mrpack" modrinth.index.json overrides/

echo ""
echo "Built: $ROOT_DIR/jln-hut-modpack.mrpack"
