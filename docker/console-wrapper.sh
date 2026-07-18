#!/usr/bin/env bash
set -Eeo pipefail

case "${PRETTY_LOGS:-true}" in
    false|FALSE|0|no|NO|off|OFF|raw|RAW)
        echo "[FS25] Raw console mode enabled."
        exec /usr/local/bin/ptero-entrypoint.sh
        ;;
esac

LOG_DIR="/home/container/config/FarmingSimulator2025"
BOOT_LOG="${LOG_DIR}/pterodactyl-startup.log"
SESSION_MARKER="/tmp/fs25-console-session-start"

PUBLIC_HOST="${PUBLIC_HOST:-node1.unrealcorp.net}"
GAME_PORT="${SERVER_PORT:-10823}"
WEB_PORT="7999"
VNC_PORT="6080"

mkdir -p "${LOG_DIR}"
: > "${BOOT_LOG}"
touch "${SESSION_MARKER}"

# Keep the original Pterodactyl console descriptors.
exec 3>&1 4>&2

# Put Wine, VNC, browser, DBus, and desktop noise in a file.
exec >> "${BOOT_LOG}" 2>&1

print_console() {
    printf '%s\n' "$1" >&3
}

print_console ""
print_console "============================================================"
print_console " FARMING SIMULATOR 25"
print_console "============================================================"
print_console " Container : ONLINE"
print_console " Game      : OFFLINE"
print_console " Web panel : STARTING"
print_console ""
print_console " Admin     : http://${PUBLIC_HOST}:${WEB_PORT}"
print_console " Join      : ${PUBLIC_HOST}:${GAME_PORT}"
print_console " noVNC     : http://${PUBLIC_HOST}:${VNC_PORT}/vnc.html"
print_console " Full boot : ${BOOT_LOG}"
print_console " Logs      : PRETTY  (set Pretty console to false for raw)"
print_console "------------------------------------------------------------"

# Print only useful startup events from the hidden boot log.
(
    web_announced=0
    config_announced=0

    tail -n 0 -F "${BOOT_LOG}" 2>/dev/null | while IFS= read -r line; do
        case "${line}" in
            *"[FS25 CONFIG] SUMMARY "*)
                if [[ "${config_announced}" -eq 0 ]]; then
                    config_announced=1
                    summary="${line#*SUMMARY }"
                    printf '[CONFIG] %s\n' "${summary}" >&3
                fi
                ;;

            *"Waiting for the webserver to start"*)
                printf '%s\n' "[WEB] Starting administration panel..." >&3
                ;;

            *"Webserver link up"*)
                if [[ "${web_announced}" -eq 0 ]]; then
                    web_announced=1
                    printf '%s\n' "[WEB] AVAILABLE - http://${PUBLIC_HOST}:${WEB_PORT}" >&3
                    printf '%s\n' "[GAME] OFFLINE - click Start in the web panel" >&3
                    printf '%s\n' "------------------------------------------------------------" >&3
                fi
                ;;

            *"_XSERVTransmkdir:"*|\
            *"Could not get password database information"*|\
            *"Failed to start message bus"*|\
            *"EOF in dbus-launch"*|\
            *"CanCreateUserNamespace"*|\
            *"glxtest:"*|\
            *"Glycin running without sandbox"*|\
            *"Failed to create DBus proxy"*|\
            *"ALSA lib"*|\
            *"websockify/websocket.py"*|\
            *"Could not resolve keysym"*|\
            *"Errors from xkbcomp are not fatal"*|\
            *"mieq: warning"*|\
            *"Broken pipe"*)
                ;;

            *"[FS25 CONFIG] ERROR:"*|\
            *"FATAL:"*|\
            *"Unhandled exception"*|\
            *"Traceback (most recent call last)"*)
                printf '[ERROR] %s\n' "${line}" >&3
                ;;
        esac
    done
) &

# Report game process transitions.
(
    previous="offline"

    while true; do
        if pgrep -fa '[F]armingSimulator2025Game.exe' >/dev/null 2>&1; then
            current="starting"
        else
            current="offline"
        fi

        if [[ "${current}" != "${previous}" ]]; then
            if [[ "${current}" == "starting" ]]; then
                printf '%s\n' "[GAME] STARTING - loading the selected savegame" >&3
            else
                printf '%s\n' "[GAME] OFFLINE" >&3
            fi
            previous="${current}"
        fi

        sleep 3
    done
) &

# Follow only the current session's dated game log.
(
    current_log=""
    tail_pid=""

    while true; do
        newest_log="$(
            find "${LOG_DIR}" -maxdepth 1 -type f \
                -name 'log_*.txt' \
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
            printf '%s\n' "[GAME] Session log: $(basename "${current_log}")" >&3
            printf '%s\n' "[GAME] Full log: ${current_log}" >&3
            printf '%s\n' "[GAME] Pretty mode will summarize repetitive loading lines." >&3

            (
                tail -n +1 -F -- "${current_log}" 2>/dev/null |
                awk -v host="${PUBLIC_HOST}" -v port="${GAME_PORT}" '
                    BEGIN {
                        mods = 0
                        assets = 0
                    }

                    function clean(line) {
                        sub(/^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9][[:space:]]+[0-9:.]+[[:space:]]+/, "", line)
                        sub(/^[[:space:]]+/, "", line)
                        return line
                    }

                    /^Available mod:/ {
                        mods++
                        if (mods % 100 == 0) {
                            print "[LOAD] Scanned " mods " mods..."
                            fflush()
                        }
                        next
                    }

                    /\.i3d \([0-9.]+ ms\)$/ {
                        assets++
                        if (assets % 250 == 0) {
                            print "[LOAD] Loaded " assets " map/assets entries..."
                            fflush()
                        }
                        next
                    }

                    /Register configuration/ { next }
                    /Register workAreaType/ { next }
                    /^  Setting / { next }
                    /\[DirectStorage\]/ { next }
                    /GDeflate Compression Support/ { next }
                    /ImageDescIndexer/ { next }
                    /Hardware Profile/ { next }
                    /Main System/ { next }
                    /^  (CPU:|Virtual Cores:|Memory:|Motherboard|BIOS |OS:)/ { next }
                    /Physics System/ { next }
                    /Sound System/ { next }
                    /Render System/ { next }
                    /Input System/ { next }
                    /Keyboard disabled|Mouse disabled|Gamepad\/Joystick disabled|Force Feedback disabled/ { next }
                    /Platform: loading defaults/ { next }
                    /Used Start Parameters/ { next }
                    /^    (profile|server|name|exe) / { next }

                    /Farming Simulator 25 \(Server\)/ {
                        print "[GAME] Dedicated server launched"
                        fflush()
                        next
                    }

                    /Game-Version:/ {
                        print "[GAME] " clean($0)
                        fflush()
                        next
                    }

                    /Starting dedicated server without an admin password/ {
                        print "[WARNING] In-game admin password is empty"
                        fflush()
                        next
                    }

                    /Starting multiplayer server game/ {
                        print "[GAME] Multiplayer session is starting"
                        fflush()
                        next
                    }

                    /Started network game \(/ {
                        print "[GAME] ONLINE - " host ":" port
                        fflush()
                        next
                    }

                    /STARTING MP Game/ { next }

                    /Info: Loading map:/ {
                        line=clean($0)
                        sub(/^Info: Loading map:[[:space:]]*/, "", line)
                        print "[LOAD] Loading map: " line
                        fflush()
                        next
                    }

                    /Loading savegame|Savegame loaded|Saving|saved successfully|Game saved/ {
                        print "[SAVE] " clean($0)
                        fflush()
                        next
                    }

                    /connected|disconnected| joined | left the game|kicked|banned/ {
                        print "[PLAYER] " clean($0)
                        fflush()
                        next
                    }

                    /Error|ERROR|Exception|failed|Failure/ {
                        print "[ERROR] " clean($0)
                        fflush()
                        next
                    }

                    /Warning|WARNING/ {
                        print "[WARNING] " clean($0)
                        fflush()
                        next
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

exec /usr/local/bin/ptero-entrypoint.sh
