#!/bin/bash
set -e

TEMPLATE_DIR="/home/nobody/.build/fs25"
RUNTIME_USER="${USER:-nobody}"

GAME_DIR="${HOME}/.fs25server/drive_c/Program Files (x86)/Farming Simulator 2025"
PROFILE_DIR="${HOME}/.fs25server/drive_c/users/${RUNTIME_USER}/Documents/My Games/FarmingSimulator2025/dedicated_server"

GAME_CONFIG="${GAME_DIR}/dedicatedServer.xml"
SERVER_CONFIG="${PROFILE_DIR}/dedicatedServerConfig.xml"

if [ ! -d "${GAME_DIR}" ]; then
    echo "ERROR: Farming Simulator 25 is not installed."
    exit 1
fi

mkdir -p "${PROFILE_DIR}"

if [ ! -s "${GAME_CONFIG}" ]; then
    echo "Creating initial dedicatedServer.xml"
    cp "${TEMPLATE_DIR}/default_dedicatedServer.xml" "${GAME_CONFIG}"
else
    echo "Preserving existing dedicatedServer.xml"
fi

if [ ! -s "${SERVER_CONFIG}" ]; then
    echo "Creating initial dedicatedServerConfig.xml"
    cp "${TEMPLATE_DIR}/default_dedicatedServerConfig.xml" "${SERVER_CONFIG}"
else
    echo "Preserving existing dedicatedServerConfig.xml"
fi
