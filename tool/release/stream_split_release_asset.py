#!/usr/bin/env python3
"""Stream verified release parts to stdout without storing the archive."""

import hashlib
import json
import re
import subprocess
import sys


tag, repo, manifest_path, archive = sys.argv[1:]
with open(manifest_path, encoding="utf-8") as source:
    manifest = json.load(source)

parts = manifest.get("parts")
if (manifest.get("schemaVersion") != 1 or manifest.get("archive") != archive
        or not isinstance(parts, list) or not parts):
    raise ValueError("invalid split release manifest")

for index, part in enumerate(parts):
    if (part.get("name") != f"{archive}.part-{index:03d}"
            or type(part.get("size")) is not int or part["size"] <= 0
            or not re.fullmatch(r"[0-9a-f]{64}", part.get("sha256", ""))):
        raise ValueError(f"invalid part metadata at index {index}")

archive_hash = hashlib.sha256()
archive_size = 0
for part in parts:
    process = subprocess.Popen([
        "gh", "release", "download", tag, "--repo", repo,
        "--pattern", part["name"], "--output", "-",
    ], stdout=subprocess.PIPE)
    part_hash = hashlib.sha256()
    part_size = 0
    try:
        while chunk := process.stdout.read(1024 * 1024):
            part_size += len(chunk)
            if part_size > part["size"]:
                raise ValueError(f"part size mismatch: {part['name']}")
            part_hash.update(chunk)
            archive_hash.update(chunk)
            sys.stdout.buffer.write(chunk)
        if process.wait() != 0:
            raise RuntimeError(f"part download failed: {part['name']}")
    finally:
        process.stdout.close()
        if process.poll() is None:
            process.kill()
            process.wait()
    if part_size != part["size"] or part_hash.hexdigest() != part["sha256"]:
        raise ValueError(f"part checksum or size mismatch: {part['name']}")
    archive_size += part_size

if (archive_size != manifest.get("size")
        or archive_hash.hexdigest() != manifest.get("sha256")):
    raise ValueError(f"archive checksum or size mismatch: {archive}")
