#!/usr/bin/env bash
set -Eeo pipefail

pretty_logs="${PRETTY_LOGS:-true}"
case "${pretty_logs,,}" in
    false|0|no|off|raw)
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

RESET=$'\033[0m'
BOLD=$'\033[1m'
BLUE=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
DIM=$'\033[2m'

mkdir -p "${LOG_DIR}"
: > "${BOOT_LOG}"
touch "${SESSION_MARKER}"

# Keep clean-console output on the original Pterodactyl descriptors.
exec 3>&1 4>&2

printf '%s\n' "${BLUE}${BOLD}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${RESET}" >&3
printf '%s\n' "${BLUE}${BOLD}â•‘              FARMING SIMULATOR 25 SERVER                  â•‘${RESET}" >&3
printf '%s\n' "${BLUE}${BOLD}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${RESET}" >&3
printf '%s\n' "${GREEN}â— Pterodactyl container: ONLINE${RESET}" >&3
printf '%s\n' "${YELLOW}â— Game server: OFFLINE â€” waiting for the web panel${RESET}" >&3
printf '%s\n' "" >&3
printf '%s\n' "${BOLD}Quick links${RESET}" >&3
printf '%s\n' "  Admin panel : http://${PUBLIC_HOST}:${WEB_PORT}" >&3
printf '%s\n' "  noVNC       : http://${PUBLIC_HOST}:${VNC_PORT}/vnc.html?autoconnect=1&resize=remote" >&3
printf '%s\n' "  Game address: ${PUBLIC_HOST}:${GAME_PORT}" >&3
printf '%s\n' "" >&3
printf '%s\n' "${DIM}Set â€œPretty consoleâ€ to OFF in Startup to show every raw log line.${RESET}" >&3
printf '%s\n' "------------------------------------------------------------" >&3

# Hide Wine, VNC, DBus, Firefox, and desktop noise in a file.
exec >> "${BOOT_LOG}" 2>&1

# Surface only useful service startup messages.
(
    panel_announced=0

    while IFS= read -r line; do
        case "${line}" in
            "FS25 wrapper ready")
                # Keep the egg's startup completion marker visible.
                printf '%s\n' "FS25 wrapper ready"
                ;;
            *"[FS25 CONFIG] Pterodactyl Startup settings applied."*)
                printf '%s\n' "${GREEN}âœ“ Startup settings applied to FS25${RESET}"
                ;;
            *"[FS25 CONFIG] Server name:"*)
                printf '%s\n' "${BLUE}${line}${RESET}"
                ;;
            *"[FS25 CONFIG] Crossplay:"*|*"[FS25 CONFIG] Game password:"*|*"[FS25 CONFIG] Players:"*|*"[FS25 CONFIG] Map:"*|*"[FS25 CONFIG] Port:"*)
                printf '%s\n' "${DIM}${line}${RESET}"
                ;;
            *"Waiting for the webserver to start"*)
                printf '%s\n' "${YELLOW}â€¦ Starting FS25 web administration${RESET}"
                ;;
            *"Webserver link up"*)
                if [[ "${panel_announced}" -eq 0 ]]; then
                    panel_announced=1
                    printf '%s\n' "${GREEN}âœ“ Web panel is now available${RESET}"
                    printf '%s\n' "  Open: http://${PUBLIC_HOST}:${WEB_PORT}"
                    printf '%s\n' "${YELLOW}  Game server is OFFLINE â€” click Start in the web panel.${RESET}"
                fi
                ;;
            *"ERROR:"*|*"FATAL:"*|*"Traceback"*|*"Unhandled exception"*)
                printf '%s\n' "${RED}âœ– ${line}${RESET}"
                ;;
        esac
    done < <(tail -n 0 -F "${BOOT_LOG}" 2>/dev/null)
) >&3 &

# Show game process state transitions.
(
    last_state=""

    while true; do
        if pgrep -fa '[F]armingSimulator2025Game.exe' >/dev/null 2>&1; then
            state="starting"
        else
            state="offline"
        fi

        if [[ "${state}" != "${last_state}" ]]; then
            if [[ "${state}" == "starting" ]]; then
                printf '%s\n' "${YELLOW}â— Game process: STARTING â€” loading savegame/map${RESET}"
            elif [[ -n "${last_state}" ]]; then
                printf '%s\n' "${RED}â— Game server: OFFLINE${RESET}"
            fi
            last_state="${state}"
        fi

        sleep 3
    done
) >&3 &

# Follow only the current session's rotating game log and filter startup spam.
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
            printf '%s\n' "" >&3
            printf '%s\n' "${BLUE}${BOLD}FS25 GAME CONSOLE${RESET}" >&3
            printf '%s\n' "${DIM}Following: $(basename "${current_log}")${RESET}" >&3
            printf '%s\n' "------------------------------------------------------------" >&3

            (
                tail -n +1 -F -- "${current_log}" 2>/dev/null |
                awk \
                    -v reset="${RESET}" \
                    -v blue="${BLUE}" \
                    -v green="${GREEN}" \
                    -v yellow="${YELLOW}" \
                    -v red="${RED}" \
                    -v host="${PUBLIC_HOST}" \
                    -v port="${GAME_PORT}" '
                    /^Available mod:/ { next }
                    /Register configuration/ { next }
                    /Register workAreaType/ { next }
                    /\.i3d \([0-9.]+ ms\)$/ { next }
                    /^  Setting / { next }
                    /^  (Recommended Window Size|UI Scaling Factor|3D Scaling Factor|View Distance Factor|LOD Distance Factor|Foliage|Shadow|Texture|Max\. Number|AMD |Intel |DLSS |DRS )/ { next }
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
                        print blue "â—† Farming Simulator 25 dedicated server launched" reset
                        fflush()
                        next
                    }

                    /Game-Version:/ {
                        line=$0
                        sub(/^[[:space:]]+/, "", line)
                        print blue "â—† " line reset
                        fflush()
                        next
                    }

                    /Starting dedicated server without an admin password/ {
                        print yellow "âš  In-game admin password is empty" reset
                        fflush()
                        next
                    }

                    /Starting multiplayer server game/ {
                        print yellow "â— Multiplayer session is starting" reset
                        fflush()
                        next
                    }

                    /Started network game \(/ {
                        print green "â— Game server: ONLINE" reset
                        print green "  Join address: " host ":" port reset
                        fflush()
                        next
                    }

                    /STARTING MP Game/ { next }

                    /Info: Loading map:/ {
                        line=$0
                        sub(/^.*Info: Loading map:[[:space:]]*/, "", line)
                        print yellow "â€¦ Loading map: " line reset
                        fflush()
                        next
                    }

                    /Loading savegame|Savegame loaded|Saving|saved successfully|Game saved/ {
                        print green "âœ“ " $0 reset
                        fflush()
                        next
                    }

                    /connected|disconnected| joined | left the game|kicked|banned/ {
                        print blue "â—† " $0 reset
                        fflush()
                        next
                    }

                    /Error|ERROR|Exception|failed|Failure/ {
                        print red "âœ– " $0 reset
                        fflush()
                        next
                    }

                    /Warning|WARNING/ {
                        print yellow "âš  " $0 reset
                        fflush()
                        next
                    }

                    /^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ {
                        print $0
                        fflush()
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
) >&3 &

exec /usr/local/bin/ptero-entrypoint.sh
