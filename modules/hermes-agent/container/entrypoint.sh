#!/usr/bin/env bash
set -Eeuo pipefail

readonly hermes_user=hermes
readonly hermes_home=/home/hermes
readonly state_dir="${hermes_home}/.hermes"
readonly installed_marker="${state_dir}/.container-installed"
readonly gateway_marker="${state_dir}/.container-gateway-ready"
readonly docker_socket="${HA_DOCKER_SOCKET:-/var/run/docker.sock}"

configure_docker_socket_group() {
  if [[ ! -S "$docker_socket" ]]; then
    printf 'Hermes container: Docker socket %s is not mounted or available yet.\n' "$docker_socket" >&2
    return 0
  fi

  local socket_gid group_name
  socket_gid="$(stat -c '%g' "$docker_socket")"
  group_name="$(getent group "$socket_gid" | cut -d: -f1 || true)"
  if [[ -z "$group_name" ]]; then
    group_name=docker-host
    if getent group "$group_name" >/dev/null; then
      groupmod --gid "$socket_gid" "$group_name"
    else
      groupadd --gid "$socket_gid" "$group_name"
    fi
  fi

  usermod --append --groups "$group_name" "$hermes_user"
}

configure_docker_socket_group

if [[ "${1:-gateway}" == gateway ]]; then
  printf 'Waiting for Hermes installation and interactive setup to complete.\n'
  while [[ ! -f "$installed_marker" ]]; do
    sleep 2
  done
  while [[ ! -f "$gateway_marker" ]]; do
    sleep 2
  done

  exec gosu "$hermes_user" env HOME="$hermes_home" \
    PATH="/usr/local/bin:${hermes_home}/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin" \
    hermes gateway run
fi

exec "$@"
