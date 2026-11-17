#!/bin/bash
# Starts xrdp (unless ENABLE_RDP=0), then runs the given command (default: zsh).

# Publish the whole container ENV (incl. any -e overrides) in /etc/environment,
# so RDP sessions (started via PAM/pam_env) get the same PATH, EDITOR, etc.
# Per-process / per-login variables are skipped.
env | grep -vE '^(HOME|USER|LOGNAME|HOSTNAME|PWD|OLDPWD|SHLVL|_|TERM|ENABLE_RDP)=' \
  | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' \
  | sudo tee /etc/environment >/dev/null

if [[ "${ENABLE_RDP:-1}" == 1 ]]; then
  sudo install -d -m 700 -o "$(id -u)" -g "$(id -g)" "/run/user/$(id -u)"
  sudo mkdir -p /run/xrdp
  sudo rm -f /run/xrdp/*.pid /var/run/xrdp/*.pid      # stale pids from last stop

  [[ -f /etc/xrdp/rsakeys.ini ]] || sudo xrdp-keygen xrdp /etc/xrdp/rsakeys.ini >/dev/null
  if [[ ! -f /etc/xrdp/cert.pem ]]; then
    sudo openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=$(hostname)" \
      -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem 2>/dev/null
  fi
  # xrdp drops privileges to xrdp:xrdp after binding the port, so it must be
  # able to read the TLS key, otherwise every client connection fails.
  if getent group xrdp >/dev/null; then
    sudo chown root:xrdp /etc/xrdp/key.pem /etc/xrdp/rsakeys.ini
    sudo chmod 640 /etc/xrdp/key.pem /etc/xrdp/rsakeys.ini
  fi

  sudo xrdp-sesman
  sudo xrdp
  sleep 1
  pgrep -x xrdp >/dev/null && pgrep -x xrdp-sesman >/dev/null \
    || echo "entrypoint: xrdp failed to start (see /var/log/xrdp*.log)" >&2
fi

exec "$@"
