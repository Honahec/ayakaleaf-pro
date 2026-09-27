#!/bin/bash
set -euo pipefail
umask 077

secret_file=/var/lib/overleaf/deployment-secrets.env
marker=/var/lib/overleaf/.deployment-secrets-initialized

validate() {
  if [[ ! -f "$secret_file" || -L "$secret_file" || $(stat -c %u "$secret_file") != 0 || $(stat -c %a "$secret_file") != 600 ]]; then
    echo 'Persistent deployment secrets are missing, symlinked, or have unsafe ownership/mode' >&2
    exit 1
  fi
  local -a lines
  mapfile -t lines < "$secret_file"
  if [[ ${#lines[@]} != 2 || ! ${lines[0]} =~ ^OVERLEAF_INVITE_TOKEN_SECRET=([0-9a-f]{64})$ ]]; then
    echo 'Invalid persistent invite secret' >&2
    exit 1
  fi
  export OVERLEAF_INVITE_TOKEN_SECRET="${BASH_REMATCH[1]}"
  if [[ ! ${lines[1]} =~ ^OVERLEAF_SESSION_SECRET=([0-9a-f]{64})$ ]]; then
    echo 'Invalid persistent session secret' >&2
    exit 1
  fi
  export OVERLEAF_SESSION_SECRET="${BASH_REMATCH[1]}"
}

case "${1:-}" in
  init)
    if [[ ! -e "$secret_file" && ! -L "$secret_file" ]]; then
      if [[ -e "$marker" || -L "$marker" ]]; then
        echo 'Previously initialized secrets disappeared: refusing to rotate them' >&2
        exit 1
      fi
      tmp=$(mktemp "${secret_file}.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      printf 'OVERLEAF_INVITE_TOKEN_SECRET=%s\nOVERLEAF_SESSION_SECRET=%s\n' \
        "$(openssl rand -hex 32)" "$(openssl rand -hex 32)" > "$tmp"
      mv "$tmp" "$secret_file"
      trap - EXIT
    fi
    validate
    if [[ -L "$marker" || ( -e "$marker" && ( ! -f "$marker" || $(stat -c %u "$marker") != 0 || $(stat -c %a "$marker") != 600 ) ) ]]; then
      echo 'Invalid deployment secrets initialization marker' >&2
      exit 1
    fi
    if [[ ! -e "$marker" ]]; then
      : > "$marker"
    fi
    ;;
  run)
    if [[ ! -f "$marker" || -L "$marker" ]]; then
      echo 'Deployment secrets have not been initialized' >&2
      exit 1
    fi
    validate
    socket=/var/run/ayakaleaf-docker/docker.sock
    if [[ ! -S "$socket" ]]; then
      echo 'Docker socket is not ready' >&2
      exit 1
    fi
    ln -sfn "$socket" /var/run/docker.sock
    # CLSI uses stat (without -L) on /var/run/docker.sock to grant www-data
    # its socket group. Match the link's gid to the target's gid.
    chown -h "0:$(stat -c %g "$socket")" /var/run/docker.sock
    exec /sbin/my_init
    ;;
  exec)
    if [[ ! -f "$marker" || -L "$marker" || $# -lt 2 ]]; then
      echo 'Initialized secrets and a command are required' >&2
      exit 1
    fi
    validate
    shift
    exec "$@"
    ;;
  *) echo 'Usage: ensure-secrets.sh init|run|exec command [args...]' >&2; exit 2 ;;
esac
