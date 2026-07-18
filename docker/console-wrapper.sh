#!/usr/bin/env bash
set -Eeuo pipefail

GAME_LOG="/home/container/config/FarmingSimulator2025/log.txt"

echo "============================================================"
echo " FS25 live game console enabled"
echo " Log file: ${GAME_LOG}"
echo "============================================================"

(
    echo "[FS25 Console] Waiting for the game log..."

    while [[ ! -f "${GAME_LOG}" ]]; do
        sleep 1
    done

    echo ""
    echo "================ FS25 GAME OUTPUT ================"
    echo ""

    tail -n 0 -F -- "${GAME_LOG}"
) &

# Keep the actual FS25 startup process in the foreground.
exec /usr/local/bin/ptero-entrypoint.sh
