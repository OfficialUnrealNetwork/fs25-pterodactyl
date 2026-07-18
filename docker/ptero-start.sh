#!/bin/bash
set -Eeuo pipefail

export HOME=/home/container
export USER=container
export WINEPREFIX="${WINEPREFIX:-/home/container/.fs25server}"
export DISPLAY="${DISPLAY:-:0}"

# Pterodactyl injects SERVER_PORT from the primary allocation.
export SERVER_PORT="${SERVER_PORT:-10823}"
export SERVER_NAME="${SERVER_NAME:-My FS25 Server}"
export SERVER_PASSWORD="${SERVER_PASSWORD:-}"
export SERVER_ADMIN="${SERVER_ADMIN:-ChangeMe-Admin}"
export SERVER_PLAYERS="${SERVER_PLAYERS:-8}"
export SERVER_MAP="${SERVER_MAP:-MapUS}"
export SERVER_DIFFICULTY="${SERVER_DIFFICULTY:-3}"
export SERVER_REGION="${SERVER_REGION:-en}"
export SERVER_CROSSPLAY="${SERVER_CROSSPLAY:-true}"
export SERVER_PAUSE="${SERVER_PAUSE:-2}"
export SERVER_SAVE_INTERVAL="${SERVER_SAVE_INTERVAL:-180.000000}"
export SERVER_STATS_INTERVAL="${SERVER_STATS_INTERVAL:-31536000}"
export WEB_USERNAME="${WEB_USERNAME:-admin}"
export WEB_PASSWORD="${WEB_PASSWORD:-ChangeMe-Web}"
export WEB_DARKMODE="${WEB_DARKMODE:-false}"
export VNC_PASSWORD="${VNC_PASSWORD:-ChangeMe-VNC}"
export WEBPAGE_TITLE="${WEBPAGE_TITLE:-Farming Simulator 25 Server}"
export AUTOSTART_SERVER="${AUTOSTART_SERVER:-false}"
export AUTO_INSTALL="${AUTO_INSTALL:-true}"

mkdir -p /home/container/{installer,dlc,game,config,setup-logs,.vnc}

echo "============================================================"
echo " Farming Simulator 25 - Pterodactyl Wine Server"
echo " Primary game port : ${SERVER_PORT}/TCP+UDP"
echo " noVNC desktop     : allocation 6080/TCP"
echo " Web administration: allocation 7999/TCP"
echo " Startup mode      : ${AUTOSTART_SERVER}"
echo "============================================================"

profile_root="${WINEPREFIX}/drive_c/users/container/Documents/My Games/FarmingSimulator2025"
server_config="${profile_root}/dedicated_server/dedicatedServerConfig.xml"
installer_found=false

shopt -s nullglob nocaseglob
installer_candidates=(/home/container/installer/FarmingSimulator25_*_ESD.img)
shopt -u nullglob nocaseglob
if (( ${#installer_candidates[@]} > 0 )); then
    installer_found=true
fi

# Launch the upstream interactive setup after the desktop is available.
# The license prompt is completed through noVNC. A marker prevents the
# helper from being launched repeatedly once setup generated its config.
if [[ "${AUTO_INSTALL,,}" == "true" && ! -f "$server_config" ]]; then
    if [[ "$installer_found" == "true" ]]; then
        (
            sleep 12
            echo "[FS25] Starting interactive installer. Open noVNC on port 6080."
            /usr/local/bin/setup_fs25.sh 2>&1 | tee -a /home/container/setup-logs/setup.log
        ) &
    else
        echo "[FS25] No ESD .img/.iso found in /home/container/installer."
        echo "[FS25] Upload the GIANTS installer, then restart with AUTO_INSTALL=true."
    fi
fi

echo "FS25 wrapper ready"

# The upstream script starts Xvnc, noVNC, Xfce, the FS25 web server, and
# optionally dedicatedServer.exe according to AUTOSTART_SERVER.
exec /bin/bash /usr/local/bin/start.sh
