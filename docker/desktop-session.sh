#!/usr/bin/env bash
set -Eeuo pipefail

export HOME="${HOME:-/home/app}"
export DISPLAY="${DISPLAY:-:1}"

EXTENSION_DIR="${EXTENSION_DIR:-/opt/gujumpgate-core}"
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
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/FoundZiGu/GuJumpgate.git}"
AUTO_PULL_LATEST_CODE="${AUTO_PULL_LATEST_CODE:-true}"
GLOBAL_PROXY="${GLOBAL_PROXY:-}"
GIT_PROXY="${GIT_PROXY:-}"
CONFIG_PROXY="${CONFIG_PROXY:-}"
EFFECTIVE_GIT_PROXY="${GIT_PROXY:-$GLOBAL_PROXY}"
EFFECTIVE_CONFIG_PROXY="${CONFIG_PROXY:-$GLOBAL_PROXY}"
CHROMIUM_PROXY_BYPASS_LIST="${CHROMIUM_PROXY_BYPASS_LIST:-localhost;127.0.0.1;::1;<local>}"

mkdir -p "$CHROME_USER_DATA_DIR" "$DOWNLOAD_DIR" "$HOME/.vnc" /tmp/gujumpgate

is_truthy() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_remote_head_branch() {
  git_cmd -C "$EXTENSION_DIR" remote set-head origin --auto >/dev/null 2>&1 || true
  git_cmd -C "$EXTENSION_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##'
}

git_cmd() {
  local args=(git)
  if [[ -n "$EFFECTIVE_GIT_PROXY" ]]; then
    args+=(-c "http.proxy=$EFFECTIVE_GIT_PROXY" -c "https.proxy=$EFFECTIVE_GIT_PROXY")
  fi
  "${args[@]}" "$@"
}

add_file_repo_safe_directory() {
  if [[ "$GIT_REPO_URL" != file://* ]]; then
    return 0
  fi

  local repo_path="${GIT_REPO_URL#file://}"
  if [[ -z "$repo_path" ]]; then
    return 0
  fi

  git_cmd config --global --add safe.directory "$repo_path" >/dev/null 2>&1 || true
  git_cmd config --global --add safe.directory "$repo_path/.git" >/dev/null 2>&1 || true
}

sync_cloned_repo_to_extension_dir() {
  local source_dir="$1"

  rsync -a --delete \
    --exclude '/data/account-run-history.txt' \
    --exclude '/data/account-run-history.json' \
    --exclude '/data/hotmail-helper-start.log' \
    "$source_dir"/ "$EXTENSION_DIR"/
}

update_existing_git_repo() {
  git_cmd config --global --add safe.directory "$EXTENSION_DIR" >/dev/null 2>&1 || true

  local current_remote
  current_remote="$(git_cmd -C "$EXTENSION_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ "$current_remote" != "$GIT_REPO_URL" ]]; then
    echo "Setting git origin to $GIT_REPO_URL"
    git_cmd -C "$EXTENSION_DIR" remote remove origin >/dev/null 2>&1 || true
    git_cmd -C "$EXTENSION_DIR" remote add origin "$GIT_REPO_URL"
  fi

  echo "Checking latest GuJumpgate code from $GIT_REPO_URL"
  if [[ -n "$EFFECTIVE_GIT_PROXY" ]]; then
    echo "Using Git proxy: $EFFECTIVE_GIT_PROXY"
  fi
  git_cmd -C "$EXTENSION_DIR" fetch --prune origin

  local branch
  branch="$(git_cmd -C "$EXTENSION_DIR" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -z "$branch" ]]; then
    branch="$(resolve_remote_head_branch)"
  fi
  if [[ -z "$branch" ]]; then
    echo "Unable to determine git branch; keeping current extension code." >&2
    return 0
  fi

  local remote_ref="origin/$branch"
  if ! git_cmd -C "$EXTENSION_DIR" rev-parse --verify --quiet "$remote_ref" >/dev/null; then
    echo "Remote branch $remote_ref not found; keeping current extension code." >&2
    return 0
  fi

  local local_rev remote_rev merge_base
  local_rev="$(git_cmd -C "$EXTENSION_DIR" rev-parse HEAD)"
  remote_rev="$(git_cmd -C "$EXTENSION_DIR" rev-parse "$remote_ref")"

  if [[ "$local_rev" == "$remote_rev" ]]; then
    echo "GuJumpgate code is already up to date on $branch."
    return 0
  fi

  merge_base="$(git_cmd -C "$EXTENSION_DIR" merge-base HEAD "$remote_ref" || true)"
  if [[ "$merge_base" != "$local_rev" ]]; then
    echo "Remote has changes but local branch cannot fast-forward; keeping current extension code." >&2
    return 0
  fi

  echo "Updating GuJumpgate code: $local_rev -> $remote_rev"
  git_cmd -C "$EXTENSION_DIR" pull --ff-only origin "$branch"
}

clone_repo_into_extension_dir() {
  local clone_dir="/tmp/gujumpgate/source-clone"

  echo "Cloning GuJumpgate code from $GIT_REPO_URL"
  if [[ -n "$EFFECTIVE_GIT_PROXY" ]]; then
    echo "Using Git proxy: $EFFECTIVE_GIT_PROXY"
  fi
  rm -rf "$clone_dir"
  git_cmd clone --depth=1 "$GIT_REPO_URL" "$clone_dir"
  sync_cloned_repo_to_extension_dir "$clone_dir"
  rm -rf "$clone_dir"
}

maybe_update_extension_code() {
  if ! is_truthy "$AUTO_PULL_LATEST_CODE"; then
    echo "Auto pull latest code is disabled."
    return 0
  fi

  if [[ -z "$GIT_REPO_URL" ]]; then
    echo "AUTO_PULL_LATEST_CODE is enabled but GIT_REPO_URL is empty; keeping current extension code." >&2
    return 0
  fi

  mkdir -p "$EXTENSION_DIR"
  git_cmd config --global --add safe.directory "$EXTENSION_DIR" >/dev/null 2>&1 || true
  add_file_repo_safe_directory

  if git_cmd -C "$EXTENSION_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    update_existing_git_repo
  else
    clone_repo_into_extension_dir
  fi
}

apply_runtime_proxy() {
  if [[ -z "$EFFECTIVE_CONFIG_PROXY" ]]; then
    echo "Runtime proxy is disabled."
    return 0
  fi

  export http_proxy="$EFFECTIVE_CONFIG_PROXY"
  export https_proxy="$EFFECTIVE_CONFIG_PROXY"
  export all_proxy="$EFFECTIVE_CONFIG_PROXY"
  export HTTP_PROXY="$EFFECTIVE_CONFIG_PROXY"
  export HTTPS_PROXY="$EFFECTIVE_CONFIG_PROXY"
  export ALL_PROXY="$EFFECTIVE_CONFIG_PROXY"
  export no_proxy="${NO_PROXY:-localhost,127.0.0.1,::1}"
  export NO_PROXY="$no_proxy"
  echo "Using runtime proxy: $EFFECTIVE_CONFIG_PROXY"
}

maybe_update_extension_code
apply_runtime_proxy

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
  local proxy_args=()
  if [[ -n "$CHROMIUM_EXTRA_ARGS" ]]; then
    read -r -a extra_args <<< "$CHROMIUM_EXTRA_ARGS"
  fi
  if [[ -n "$EFFECTIVE_CONFIG_PROXY" ]]; then
    proxy_args=("--proxy-server=$EFFECTIVE_CONFIG_PROXY" "--proxy-bypass-list=$CHROMIUM_PROXY_BYPASS_LIST")
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
      "${proxy_args[@]}" \
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
