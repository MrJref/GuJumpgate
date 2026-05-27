#!/usr/bin/env bash
set -Eeuo pipefail

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

if [[ "$PUID" =~ ^[0-9]+$ && "$PGID" =~ ^[0-9]+$ ]]; then
  current_gid="$(id -g app)"
  current_uid="$(id -u app)"

  if [[ "$current_gid" != "$PGID" ]]; then
    groupmod -o -g "$PGID" app
  fi

  if [[ "$current_uid" != "$PUID" ]]; then
    usermod -o -u "$PUID" -g "$PGID" app
  fi
fi

install -d -o app -g app \
  /home/app/.cache \
  /home/app/.config \
  /home/app/.config/chromium-gujumpgate \
  /home/app/.vnc \
  /home/app/Downloads \
  /tmp/gujumpgate

install -d -m 1777 /tmp/.X11-unix

if [[ -n "${EXTENSION_DIR:-}" ]]; then
  mkdir -p "$EXTENSION_DIR"
  chown -R app:app "$EXTENSION_DIR" 2>/dev/null || true
fi

chown -R app:app \
  /home/app/.cache \
  /home/app/.config/chromium-gujumpgate \
  /home/app/.vnc \
  /home/app/Downloads \
  "${EXTENSION_DIR:-/opt/gujumpgate-core}" \
  /tmp/gujumpgate

if command -v dbus-daemon >/dev/null 2>&1; then
  mkdir -p /run/dbus
  if [[ ! -S /run/dbus/system_bus_socket ]]; then
    dbus-uuidgen --ensure=/etc/machine-id 2>/dev/null || true
    dbus-daemon --system --fork --nopidfile >/dev/null 2>&1 || \
      echo "Unable to start system DBus; Chromium will continue without it." >&2
  fi
fi

exec gosu app:app "$@"
