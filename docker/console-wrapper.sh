#!/usr/bin/env bash
set -Eeo pipefail

case "${PRETTY_LOGS:-true}" in
    false|FALSE|0|no|NO|off|OFF|raw|RAW)
        echo "[FS25] Raw container console enabled."
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

# Keep Wine/VNC/browser/DBus startup noise out of the visible console.
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
print_console " Boot log  : ${BOOT_LOG}"
print_console " Game logs : ${LOG_DIR}/log_*.txt"
print_console "------------------------------------------------------------"

# Show useful container/web-panel startup status.
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
                printf '%s\n' "[GAME] STARTING - full FS25 log follows below" >&3
            else
                printf '%s\n' "[GAME] OFFLINE" >&3
            fi
            previous="${current}"
        fi

        sleep 3
    done
) &

# Follow the complete current-session FS25 dated log with no filtering.
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

            printf '%s\n' "" >&3
            printf '%s\n' "============================================================" >&3
            printf '%s\n' " FULL FS25 GAME LOG" >&3
            printf '%s\n' " ${current_log}" >&3
            printf '%s\n' "============================================================" >&3

            # Print every line already in the file, then continue following it.
            tail -n +1 -F -- "${current_log}" >&3 2>&4 &
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
