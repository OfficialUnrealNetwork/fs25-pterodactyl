#!/usr/bin/env bash
set -Eeo pipefail

LOG_DIR="/home/container/config/FarmingSimulator2025"

echo "============================================================"
echo " FS25 live game console enabled"
echo " Log directory: ${LOG_DIR}"
echo "============================================================"

(
    current_log=""
    tail_pid=""

    echo "[FS25 Console] Waiting for an FS25 dated log file..."

    while true; do
        newest_log="$(
            find "${LOG_DIR}" -maxdepth 2 -type f \
                \( -name 'log_*.txt' -o -name 'log.txt' \) \
                -printf '%T@|%p\n' 2>/dev/null |
            sort -n |
            tail -n 1 |
            cut -d'|' -f2-
        )"

        if [[ -n "${newest_log}" && "${newest_log}" != "${current_log}" ]]; then
            if [[ -n "${tail_pid}" ]]; then
                kill "${tail_pid}" 2>/dev/null || true
                wait "${tail_pid}" 2>/dev/null || true
            fi

            current_log="${newest_log}"

            echo ""
            echo "================ FS25 GAME OUTPUT ================"
            echo "[FS25 Console] Following: ${current_log}"
            echo "=================================================="
            echo ""

            tail -n 25 -F -- "${current_log}" &
            tail_pid=$!
        fi

        if [[ -n "${tail_pid}" ]] && ! kill -0 "${tail_pid}" 2>/dev/null; then
            tail_pid=""
            current_log=""
        fi

        sleep 2
    done
) &

exec /usr/local/bin/ptero-entrypoint.sh
