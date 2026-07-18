#!/usr/bin/env bash
set -Eeo pipefail

LOG_DIR="/home/container/config/FarmingSimulator2025"
BOOT_LOG="${LOG_DIR}/pterodactyl-startup.log"

mkdir -p "${LOG_DIR}"
: > "${BOOT_LOG}"

echo "============================================================"
echo " Farming Simulator 25 Server"
echo " Game port: ${SERVER_PORT:-10823}"
echo " Web panel: port 7999"
echo "============================================================"
echo "[FS25] Starting services..."

# Display only useful startup messages.
(
    tail -n 0 -F "${BOOT_LOG}" 2>/dev/null |
    awk '
        /Preserving existing/ ||
        /Webserver link up/ ||
        /Started network game/ ||
        /Starting game/ ||
        /ERROR/ ||
        /Error:/ ||
        /FATAL/ ||
        /Fatal/ ||
        /failed/ {
            print;
            fflush();
        }
    '
) &

# Automatically follow the newest dated FS25 log.
(
    current_log=""
    tail_pid=""

    while true; do
        newest_log="$(
            find "${LOG_DIR}" -maxdepth 1 -type f -name 'log_*.txt' \
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
            echo "[FS25] Following game log: $(basename "${current_log}")"
            echo "------------------------------------------------------------"

            (
                tail -n 0 -F -- "${current_log}" 2>/dev/null |
                awk '
                    /^Available mod:/ { next }
                    /Register configuration/ { next }
                    /Register workAreaType/ { next }
                    /\.i3d \([0-9.]+ ms\)$/ { next }
                    /^  Setting / { next }
                    /^  Recommended Window Size:/ { next }
                    /^  UI Scaling Factor:/ { next }
                    /^  3D Scaling Factor:/ { next }
                    /^  View Distance Factor:/ { next }
                    /^  LOD Distance Factor:/ { next }
                    /^  Foliage/ { next }
                    /^  Shadow/ { next }
                    /^  Texture/ { next }
                    /^  Max\. Number/ { next }
                    /^  AMD / { next }
                    /^  Intel / { next }
                    /^  DLSS / { next }
                    /^  DRS / { next }
                    /GDeflate Compression Support/ { next }
                    /^\[DirectStorage\]/ { next }

                    {
                        print;
                        fflush();
                    }
                '
            ) &

            tail_pid=$!
        fi

        if [[ -n "${tail_pid}" ]] && ! kill -0 "${tail_pid}" 2>/dev/null; then
            tail_pid=""
            current_log=""
        fi

        sleep 2
    done
) &

# Run the real server while storing noisy startup output separately.
exec /usr/local/bin/ptero-entrypoint.sh >> "${BOOT_LOG}" 2>&1
