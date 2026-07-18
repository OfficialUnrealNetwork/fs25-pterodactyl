#!/usr/bin/env bash

GAME_DIR="/home/container/game/Farming Simulator 2025"
PROFILE_DIR="/home/container/config/FarmingSimulator2025/dedicated_server"
GAME_CONFIG="${GAME_DIR}/dedicatedServer.xml"
SERVER_CONFIG="${PROFILE_DIR}/dedicatedServerConfig.xml"

TEMPLATE_DIR=""
for candidate in \
    "/home/container/.build/fs25" \
    "/opt/ptero-fs25-build/fs25" \
    "/home/nobody/.build/fs25"
do
    if [[ -d "${candidate}" ]]; then
        TEMPLATE_DIR="${candidate}"
        break
    fi
done

if [[ ! -d "${GAME_DIR}" ]]; then
    echo "[FS25 CONFIG] ERROR: Farming Simulator 25 installation was not found."
    return 1 2>/dev/null || exit 1
fi

mkdir -p "${PROFILE_DIR}"

if [[ ! -s "${GAME_CONFIG}" ]]; then
    if [[ -z "${TEMPLATE_DIR}" || ! -f "${TEMPLATE_DIR}/default_dedicatedServer.xml" ]]; then
        echo "[FS25 CONFIG] ERROR: Web configuration template was not found."
        return 1 2>/dev/null || exit 1
    fi
    echo "[FS25 CONFIG] Creating dedicatedServer.xml"
    cp "${TEMPLATE_DIR}/default_dedicatedServer.xml" "${GAME_CONFIG}"
else
    echo "[FS25 CONFIG] Preserving existing dedicatedServer.xml"
fi

if [[ ! -s "${SERVER_CONFIG}" ]]; then
    if [[ -z "${TEMPLATE_DIR}" || ! -f "${TEMPLATE_DIR}/default_dedicatedServerConfig.xml" ]]; then
        echo "[FS25 CONFIG] ERROR: Game configuration template was not found."
        return 1 2>/dev/null || exit 1
    fi
    echo "[FS25 CONFIG] Creating dedicatedServerConfig.xml"
    cp "${TEMPLATE_DIR}/default_dedicatedServerConfig.xml" "${SERVER_CONFIG}"
else
    echo "[FS25 CONFIG] Preserving existing dedicatedServerConfig.xml"
fi

/usr/local/bin/apply-pterodactyl-config.py || {
    echo "[FS25 CONFIG] ERROR: Could not apply Pterodactyl Startup settings."
    return 1 2>/dev/null || exit 1
}
