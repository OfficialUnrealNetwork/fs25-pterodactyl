#!/usr/bin/env python3
"""Apply Pterodactyl Startup variables to active FS25 XML configuration files."""

from __future__ import annotations

import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


GAME_CONFIG = Path(
    "/home/container/config/FarmingSimulator2025/dedicated_server/"
    "dedicatedServerConfig.xml"
)
WEB_CONFIG = Path(
    "/home/container/game/Farming Simulator 2025/dedicatedServer.xml"
)


def env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def bool_text(name: str, default: str = "false") -> str:
    value = env(name, default).strip().lower()
    return "true" if value in {"1", "true", "yes", "on"} else "false"


def update_xml(path: Path, values: dict[str, str]) -> int:
    if not path.is_file():
        raise FileNotFoundError(f"Configuration file does not exist: {path}")

    tree = ET.parse(path)
    root = tree.getroot()
    changed = 0

    for tag, value in values.items():
        node = root.find(f".//{tag}")
        if node is None:
            raise RuntimeError(f"Missing <{tag}> in {path}")

        if (node.text or "") != value:
            node.text = value
            changed += 1

    if changed:
        ET.indent(tree, space="  ")
        temporary = path.with_name(f".{path.name}.pterodactyl.tmp")
        tree.write(temporary, encoding="utf-8", xml_declaration=True)
        temporary.replace(path)

    return changed


def main() -> int:
    game_values = {
        "game_name": env("SERVER_NAME", "My FS25 Server"),
        "admin_password": env("SERVER_ADMIN", "ChangeMe-Admin"),
        "game_password": env("SERVER_PASSWORD", ""),
        "max_player": env("SERVER_PLAYERS", "8"),
        "port": env("SERVER_PORT", "10823"),
        "language": env("SERVER_REGION", "en"),
        "auto_save_interval": env("SERVER_SAVE_INTERVAL", "180.000000"),
        "stats_interval": env("SERVER_STATS_INTERVAL", "31536000"),
        "crossplay_allowed": bool_text("SERVER_CROSSPLAY", "true"),
        "economicDifficulty": env("SERVER_DIFFICULTY", "3"),
        "pause_game_if_empty": env("SERVER_PAUSE", "2"),
        "mapID": env("SERVER_MAP", "MapUS"),
    }

    web_values = {
        "username": env("WEB_USERNAME", "admin"),
        "passphrase": env("WEB_PASSWORD", "ChangeMe-Web"),
    }

    changed = update_xml(GAME_CONFIG, game_values)
    changed += update_xml(WEB_CONFIG, web_values)

    password_state = "ON" if game_values["game_password"] else "OFF"
    crossplay_state = (
        "ON" if game_values["crossplay_allowed"] == "true" else "OFF"
    )

    summary = (
        f'name="{game_values["game_name"]}"'
        f' | players={game_values["max_player"]}'
        f' | crossplay={crossplay_state}'
        f' | password={password_state}'
        f' | map={game_values["mapID"]}'
        f' | port={game_values["port"]}'
        f' | changed={changed}'
    )
    print(f"[FS25 CONFIG] SUMMARY {summary}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[FS25 CONFIG] ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
