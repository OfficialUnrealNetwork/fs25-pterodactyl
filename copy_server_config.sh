#!/usr/bin/env bash
set -euo pipefail

WINEPREFIX="${WINEPREFIX:-${HOME}/.fs25server}"
TEMPLATE_DIR="/home/nobody/.build/fs25"

GAME_DIR="${WINEPREFIX}/drive_c/Program Files (x86)/Farming Simulator 2025"
PROFILE_DIR="${WINEPREFIX}/drive_c/users/nobody/Documents/My Games/FarmingSimulator2025/dedicated_server"

GAME_CONFIG="${GAME_DIR}/dedicatedServer.xml"
SERVER_CONFIG="${PROFILE_DIR}/dedicatedServerConfig.xml"

if [[ ! -d "${GAME_DIR}" ]]; then
    echo "ERROR: Farming Simulator 25 is not installed at ${GAME_DIR}"
    exit 1
fi

mkdir -p "${PROFILE_DIR}"

if [[ ! -s "${GAME_CONFIG}" ]]; then
    echo "Creating initial dedicatedServer.xml"
    cp "${TEMPLATE_DIR}/default_dedicatedServer.xml" "${GAME_CONFIG}"
else
    echo "Keeping existing dedicatedServer.xml"
fi

if [[ ! -s "${SERVER_CONFIG}" ]]; then
    echo "Creating initial dedicatedServerConfig.xml"
    cp "${TEMPLATE_DIR}/default_dedicatedServerConfig.xml" "${SERVER_CONFIG}"
else
    echo "Keeping existing dedicatedServerConfig.xml"
fi
