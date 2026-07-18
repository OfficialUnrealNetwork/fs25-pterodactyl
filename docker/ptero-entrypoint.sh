#!/bin/bash
set -Eeuo pipefail

export HOME=/home/container
export USER=container
export WINEPREFIX="${WINEPREFIX:-/home/container/.fs25server}"
export DISPLAY="${DISPLAY:-:0}"

cd /home/container
mkdir -p installer dlc game config setup-logs .vnc

# The Pterodactyl volume hides files baked into /home/container, so restore
# the upstream desktop/config templates on first boot.
if [ ! -d /home/container/.build ] && [ -d /opt/ptero-fs25-build ]; then
    cp -a /opt/ptero-fs25-build /home/container/.build
fi

# Wings may pass the startup command as container arguments or through the
# STARTUP environment variable, depending on its configuration.
if (( $# > 0 )); then
    START_CMD="$*"
else
    START_CMD="${STARTUP:-bash /usr/local/bin/ptero-start.sh}"
fi

# Convert any remaining {{VARIABLE}} placeholders to shell-style
# ${VARIABLE} placeholders before execution.
START_CMD="$(printf '%s' "$START_CMD" | sed -e 's/{{/${/g' -e 's/}}/}/g')"

exec /bin/bash -lc "$START_CMD"
