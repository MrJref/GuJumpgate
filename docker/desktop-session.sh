#!/usr/bin/env bash
set -Eeuo pipefail

export HOME="${HOME:-/home/app}"
export DISPLAY="${DISPLAY:-:1}"

EXTENSION_DIR="${EXTENSION_DIR:-/opt/gujumpgate}"
CHROME_USER_DATA_DIR="${CHROME_USER_DATA_DIR:-/home/app/.config/chromium-gujumpgate}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/home/app/Downloads}"
RESOLUTION="${RESOLUTION:-1440x900}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
VNC_PASSWORD="${VNC_PASSWORD:-}"
HOTMAIL_HELPER_HOST="${HOTMAIL_HELPER_HOST:-127.0.0.1}"
HOTMAIL_HELPER_PORT="${HOTMAIL_HELPER_PORT:-17373}"
START_HOTMAIL_HELPER="${START_HOTMAIL_HELPER:-1}"
START_URL="${START_URL:-chrome://extensions/}"
CHROMIUM_BIN="${CHROMIUM_BIN:-chromium}"
CHROMIUM_EXTRA_ARGS="${CHROMIUM_EXTRA_ARGS:-}"

mkdir -p "$CHROME_USER_DATA_DIR" "$DOWNLOAD_DIR" "$HOME/.vnc" /tmp/gujumpgate

if [[ ! -f "$EXTENSION_DIR/manifest.json" ]]; then
  echo "Extension manifest not found: $EXTENSION_DIR/manifest.json" >&2
  exit 1
fi

pids=()

cleanup() {
  trap - EXIT INT TERM
  if ((${#pids[@]} > 0)); then
    kill "${pids[@]}" 2>/dev/null || true
  fi
  pkill -P $$ 2>/dev/null || true
  wait 2>/dev/null || true
}

trap cleanup EXIT INT TERM

start_bg() {
  "$@" &
  pids+=("$!")
}

echo "Starting Xvfb display $DISPLAY with resolution $RESOLUTION"
start_bg Xvfb "$DISPLAY" -screen 0 "${RESOLUTION}x24" -nolisten tcp

for _ in {1..80}; do
  if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

start_bg fluxbox

if [[ -n "$VNC_PASSWORD" ]]; then
  x11vnc -storepasswd "$VNC_PASSWORD" "$HOME/.vnc/passwd" >/dev/null
  start_bg x11vnc -display "$DISPLAY" -rfbport "$VNC_PORT" -forever -shared -repeat -noxdamage -passwdfile "$HOME/.vnc/passwd" -listen 0.0.0.0
else
  start_bg x11vnc -display "$DISPLAY" -rfbport "$VNC_PORT" -forever -shared -repeat -noxdamage -nopw -listen 0.0.0.0
fi

start_bg websockify --web=/usr/share/novnc "$NOVNC_PORT" "127.0.0.1:$VNC_PORT"

if [[ "$START_HOTMAIL_HELPER" != "0" && "$START_HOTMAIL_HELPER" != "false" ]]; then
  echo "Starting Hotmail helper on http://$HOTMAIL_HELPER_HOST:$HOTMAIL_HELPER_PORT"
  start_bg python3 "$EXTENSION_DIR/scripts/hotmail_helper.py" --host "$HOTMAIL_HELPER_HOST" --port "$HOTMAIL_HELPER_PORT"
fi

launch_chromium() {
  local extra_args=()
  if [[ -n "$CHROMIUM_EXTRA_ARGS" ]]; then
    read -r -a extra_args <<< "$CHROMIUM_EXTRA_ARGS"
  fi

  while true; do
    "$CHROMIUM_BIN" \
      --no-sandbox \
      --disable-dev-shm-usage \
      --disable-gpu \
      --password-store=basic \
      --user-data-dir="$CHROME_USER_DATA_DIR" \
      --download-default-directory="$DOWNLOAD_DIR" \
      --load-extension="$EXTENSION_DIR" \
      --disable-extensions-except="$EXTENSION_DIR" \
      "${extra_args[@]}" \
      --new-window "$START_URL" || true

    echo "Chromium exited; restarting in 2 seconds."
    sleep 2
  done
}

launch_chromium &
pids+=("$!")

cat <<EOF
GuJumpgate desktop is running.
noVNC: http://<docker-host>:$NOVNC_PORT/vnc.html?autoconnect=1&resize=scale
VNC:   <docker-host>:$VNC_PORT
EOF

wait
