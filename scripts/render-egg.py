#!/usr/bin/env python3
"""Render a Pterodactyl egg template with the repository's GHCR image."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

IMAGE_PATTERN = re.compile(
    r"^ghcr\.io/[a-z0-9](?:[a-z0-9._-]*[a-z0-9])?/[a-z0-9](?:[a-z0-9._-]*[a-z0-9])?:[a-z0-9][a-z0-9._-]*$"
)


def main() -> int:
    if len(sys.argv) != 4:
        print("Usage: render-egg.py TEMPLATE OUTPUT GHCR_IMAGE", file=sys.stderr)
        return 2

    template_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    image = sys.argv[3].strip().lower()

    if not IMAGE_PATTERN.fullmatch(image):
        print(f"Invalid GHCR image reference: {image}", file=sys.stderr)
        return 1

    data = json.loads(template_path.read_text(encoding="utf-8"))
    docker_images = data.get("docker_images")
    if not isinstance(docker_images, dict) or len(docker_images) != 1:
        print("Template docker_images must contain exactly one image.", file=sys.stderr)
        return 1

    display_name = next(iter(docker_images))
    if not re.fullmatch(r"[A-Za-z0-9_. -]+", display_name):
        print(f"Invalid Pterodactyl Docker image display name: {display_name}", file=sys.stderr)
        return 1

    data["docker_images"] = {display_name: image}
    output_path.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")
    print(f"Generated {output_path} using {image}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
