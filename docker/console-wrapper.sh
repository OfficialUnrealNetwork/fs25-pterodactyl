#!/usr/bin/env bash
set -Eeo pipefail

LOG_DIR="/home/container/config/FarmingSimulator2025"
BOOT_LOG="${LOG_DIR}/pterodactyl-startup.log"
SESSION_MARKER="/tmp/fs25-console-session-start"

mkdir -p "${LOG_DIR}"
: > "${BOOT_LOG}"
touch "${SESSION_MARKER}"

# Preserve the real Pterodactyl console descriptors.
exec 3>&1 4>&2

# Send all noisy Wine, VNC and desktop output into a file.
exec >> "${BOOT_LOG}" 2>&1

cat >&3 <<EOF
============================================================
 Farming Simulator 25 Server
 Game port: ${SERVER_PORT:-10823}
 Web panel: port 7999
============================================================
[FS25] Starting web administration...
EOF

# Show only useful container startup messages.
(
    tail -n 0 -F "${BOOT_LOG}" 2>/dev/null |
    awk '
        /Preserving existing/ ||
        /Creating initial/ ||
        /Waiting for the webserver/ ||
        /Webserver link up/ ||
        /Starting game/ ||
        /ERROR:/ ||
        /FATAL:/ {
            print;
            fflush();
        }
    '
) >&3 &

# Follow only logs created or changed during this container session.
(
    current_log=""
    tail_pid=""

    while true; do
        newest_log="$(
            find "${LOG_DIR}" -maxdepth 1 -type f \
                \( -name 'log.txt' -o -name 'log_*.txt' \) \
                -newer "${SESSION_MARKER}" \
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

            {
                echo ""
                echo "[FS25] Game process started"
                echo "[FS25] Log: $(basename "${current_log}")"
                echo "------------------------------------------------------------"
            } >&3

            (
                tail -n +1 -F -- "${current_log}" 2>/dev/null |
                awk '
                    /^Available mod:/ { next }
                    /Register configuration/ { next }
                    /Register workAreaType/ { next }
                    /\.i3d \([0-9.]+ ms\)$/ { next }
                    /^  Setting / { next }
                    /DirectStorage/ { next }
                    /GDeflate/ { next }
                    /Glycin/ { next }
                    /DBus/ { next }
                    /ALSA/ { next }
                    /glxtest/ { next }
                    /Sandbox:/ { next }
                    /XKEYBOARD/ { next }
                    /_XSERVTrans/ { next }

                    /Farming Simulator 25 \(Server\)/ ||
                    /Game-Version:/ ||
                    /Starting dedicated server/ ||
                    /Starting multiplayer server/ ||
                    /Started network game/ ||
                    /STARTING MP Game/ ||
                    /Loading map:/ ||
                    /Loading savegame/ ||
                    /Savegame/ ||
                    /Saving/ ||
                    /saved/ ||
                    /connected/ ||
                    /disconnected/ ||
                    /joined/ ||
                    /left the game/ ||
                    /kicked/ ||
                    /banned/ ||
                    /Error/ ||
                    /ERROR/ ||
                    /Warning/ ||
                    /WARNING/ ||
                    /failed/ ||
                    /Exception/ {
                        print;
                        fflush();
                    }
                '
            ) >&3 &

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
