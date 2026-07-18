#!/bin/bash
set -Eeuo pipefail

INSTALL_DIR="/home/container/installer"
UPSTREAM_SETUP="/usr/local/bin/setup_fs25-upstream.sh"
mkdir -p "$INSTALL_DIR"

find_installer() {
    local direct candidate link_name

    for direct in "$INSTALL_DIR/FarmingSimulator2025.exe" "$INSTALL_DIR/Setup.exe"; do
        if [[ -f "$direct" ]]; then
            printf '%s\n' "$direct"
            return 0
        fi
    done

    candidate="$(find "$INSTALL_DIR" -type f \( -iname 'FarmingSimulator2025.exe' -o -iname 'Setup.exe' \) -print -quit 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
        link_name="$INSTALL_DIR/$(basename "$candidate")"
        if [[ "$candidate" != "$link_name" ]]; then
            ln -sfn "$candidate" "$link_name"
        fi
        printf '%s\n' "$link_name"
        return 0
    fi

    return 1
}

installer="$(find_installer || true)"

if [[ -z "$installer" ]]; then
    shopt -s nullglob nocaseglob
    archives=(
        "$INSTALL_DIR"/FarmingSimulator25_*_ESD.img
        "$INSTALL_DIR"/FarmingSimulator25_*_ESD.iso
        "$INSTALL_DIR"/FarmingSimulator25_*_ESD.zip
    )
    shopt -u nullglob nocaseglob

    if (( ${#archives[@]} == 0 )); then
        echo "[FS25] ERROR: No FS25 ESD IMG, ISO, ZIP, Setup.exe, or FarmingSimulator2025.exe was found in $INSTALL_DIR."
        echo "[FS25] Files currently visible to the container:"
        find "$INSTALL_DIR" -maxdepth 2 -type f -printf '  %p (%s bytes)\n' 2>/dev/null || true
        exit 1
    fi

    if (( ${#archives[@]} > 1 )); then
        echo "[FS25] ERROR: More than one FS25 installer archive was found. Keep only one:"
        printf '  %s\n' "${archives[@]}"
        exit 1
    fi

    archive="${archives[0]}"
    echo "[FS25] Found installer archive: $archive"
    echo "[FS25] Extracting the archive. This can take a long time and requires substantial free disk space."

    if ! command -v 7z >/dev/null 2>&1; then
        echo "[FS25] ERROR: 7z is not installed in the image."
        exit 1
    fi

    7z x -y "$archive" -o"$INSTALL_DIR"

    installer="$(find_installer || true)"
    if [[ -z "$installer" ]]; then
        echo "[FS25] ERROR: Extraction completed, but Setup.exe or FarmingSimulator2025.exe was not found."
        echo "[FS25] Extracted files visible near the installer root:"
        find "$INSTALL_DIR" -maxdepth 3 -type f -printf '  %p\n' 2>/dev/null | head -n 100 || true
        exit 1
    fi
fi

echo "[FS25] Installer executable ready: $installer"

if [[ ! -x "$UPSTREAM_SETUP" ]]; then
    echo "[FS25] ERROR: The upstream setup helper is missing: $UPSTREAM_SETUP"
    exit 1
fi

exec "$UPSTREAM_SETUP"
