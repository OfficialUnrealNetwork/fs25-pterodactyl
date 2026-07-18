#!/usr/bin/env bash
set -Eeuo pipefail

GAME_LOG="/home/container/config/FarmingSimulator2025/log.txt"
ENTRYPOINT="/usr/local/bin/ptero-entrypoint.sh"

echo "============================================================"
echo " FS25 live game console enabled"
echo " Log file: ${GAME_LOG}"
echo "============================================================"

"${ENTRYPOINT}" &
SERVER_PID=$!

TAIL_PID=""

stop_server() {
    echo "[FS25 Console] Stopping server processes..."

    if [[ -n "${TAIL_PID}" ]]; then
        kill "${TAIL_PID}" 2>/dev/null || true
    fi

    kill -TERM "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
}

trap stop_server TERM INT

(
    echo "[FS25 Console] Waiting for the game log..."

    while [[ ! -f "${GAME_LOG}" ]]; do
        if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
            exit 0
        fi

        sleep 1
    done

    echo ""
    echo "================ FS25 GAME OUTPUT ================"
    echo ""

    tail -n 0 -F "${GAME_LOG}"
) &

TAIL_PID=$!

set +e
wait "${SERVER_PID}"
EXIT_CODE=$?
set -e

kill "${TAIL_PID}" 2>/dev/null || true
wait "${TAIL_PID}" 2>/dev/null || true

echo "[FS25 Console] Main server process exited with code ${EXIT_CODE}."
exit "${EXIT_CODE}"
