set -Eeuo pipefail

readonly preserve_label=org.lmh01.hermes-agent.preserve
readonly marker_installed=/home/hermes/.hermes/.container-installed
readonly marker_gateway_ready=/home/hermes/.hermes/.container-gateway-ready

die() { printf 'hermes-container: %s\n' "$*" >&2; exit 1; }
need_root() { [[ "$(id -u)" -eq 0 ]] || die "this operation must run as root"; }
need_var() { [[ -n "${!1:-}" ]] || die "required environment variable $1 is empty"; }

for variable in HA_CONTAINER HA_STATE_DIR HA_IMAGE HA_UID HA_GID HA_DOCKER_SOCKET HA_TIMEZONE HA_ASSETS HA_SERVICE; do
  need_var "$variable"
done

# Administrative helpers always target this machine, regardless of shell context.
export DOCKER_HOST="unix://$HA_DOCKER_SOCKET"
unset DOCKER_CONTEXT DOCKER_TLS_VERIFY DOCKER_TLS

readonly home_dir="$HA_STATE_DIR/home"
readonly workspace_dir="$HA_STATE_DIR/workspace"
readonly backups_dir="$HA_STATE_DIR/backups"
readonly lock_file="$HA_STATE_DIR/.container-admin.lock"
readonly backup_keep="${HA_BACKUP_KEEP:-3}"
[[ "$backup_keep" =~ ^[1-9][0-9]*$ ]] || die 'HA_BACKUP_KEEP must be a positive integer'

assert_mount_sources() {
  [[ -d "$home_dir" ]] || die "missing home bind source: $home_dir"
  [[ -d "$workspace_dir" ]] || die "missing workspace bind source: $workspace_dir"
  [[ -S "$HA_DOCKER_SOCKET" ]] || die "missing Docker socket: $HA_DOCKER_SOCKET"
}

container_exists() { docker container inspect "$HA_CONTAINER" >/dev/null 2>&1; }
container_running() {
  [[ "$(docker inspect --format '{{.State.Running}}' "$HA_CONTAINER" 2>/dev/null || true)" == true ]]
}

assert_managed_container() {
  container_exists || die "container $HA_CONTAINER does not exist; run provision first"
  [[ "$(docker inspect --format "{{ index .Config.Labels \"$preserve_label\" }}" "$HA_CONTAINER")" == true ]] \
    || die "container $HA_CONTAINER lacks the preservation label; refusing to manage it"
}

with_admin_lock() {
  need_root
  install -d -m 0700 "$backups_dir"
  exec 9>"$lock_file"
  flock -n 9 || die "another provision, backup, or restore operation is running"
}

create_container() {
  local image="$1"
  docker create \
    --name "$HA_CONTAINER" \
    --hostname "$HA_CONTAINER" \
    --restart=no \
    --stop-timeout=60 \
    --label "$preserve_label=true" \
    --env "TZ=$HA_TIMEZONE" \
    --env "HERMES_TIMEZONE=$HA_TIMEZONE" \
    --workdir "$workspace_dir" \
    --mount "type=bind,src=$home_dir,dst=/home/hermes" \
    --mount "type=bind,src=$workspace_dir,dst=$workspace_dir" \
    --mount "type=bind,src=$HA_DOCKER_SOCKET,dst=$HA_DOCKER_SOCKET" \
    "$image" gateway >/dev/null
}

exec_hermes() {
  docker exec --workdir "$workspace_dir" --user root "$HA_CONTAINER" gosu hermes env \
    HOME=/home/hermes \
    PATH=/usr/local/bin:/home/hermes/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin \
    "$@"
}

stage_runtime() {
  if [[ -z "${HA_RUNTIME:-}" ]]; then
    [[ "${HA_LOCAL_ENABLED:-0}" != 1 ]] || die 'local routing assets are not configured'
    return
  fi
  [[ -f "$HA_RUNTIME/hermes" && -f "$HA_RUNTIME/launcher.py" && -f "$HA_POLICY_FILE" ]] \
    || die 'local routing assets are incomplete; rebuild the Hermes helper'
  docker cp "$HA_RUNTIME/." "$HA_CONTAINER:/opt/hermes-container"
  docker cp "$HA_POLICY_FILE" "$HA_CONTAINER:/opt/hermes-container/policy.json"
  docker cp "$HA_RUNTIME/hermes" "$HA_CONTAINER:/usr/local/bin/hermes"
  docker cp "$HA_ASSETS/entrypoint.sh" "$HA_CONTAINER:/usr/local/sbin/hermes-container-entrypoint"
  docker cp "$HA_ASSETS/shellrc" "$HA_CONTAINER:/opt/hermes-container/shellrc"
}

wait_for_container_ready() {
  local attempt
  for ((attempt = 0; attempt < 30; attempt++)); do
    if docker exec --user root "$HA_CONTAINER" sh -c 'command -v gosu >/dev/null 2>&1' >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done
  printf 'hermes-container: container did not become ready; inspect it with: docker logs %s\n' "$HA_CONTAINER" >&2
  return 1
}

install_hermes() {
  assert_managed_container
  assert_mount_sources
  local started_here=false install_result
  if ! container_running; then
    docker start "$HA_CONTAINER" >/dev/null
    started_here=true
  fi

  if wait_for_container_ready; then
    :
  else
    install_result=$?
    [[ "$started_here" == false ]] || docker stop "$HA_CONTAINER" >/dev/null || true
    return "$install_result"
  fi

  if ! docker exec --user root "$HA_CONTAINER" test -f "$marker_installed"; then
    printf 'Installing Hermes Agent from the official Linux source installer...\n'
    if {
      # The installer and updater can replace their checkout; its parent must be writable.
      exec_hermes bash -o pipefail -c 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --non-interactive --dir /opt/hermes/agent' &&
      exec_hermes hermes config set terminal.backend local &&
      exec_hermes hermes config set terminal.home_mode real &&
      exec_hermes hermes config set terminal.cwd "$workspace_dir" &&
      docker exec --user root "$HA_CONTAINER" install -D -m 0644 /dev/null "$marker_installed"
    }; then
      :
    else
      install_result=$?
      [[ "$started_here" == false ]] || docker stop "$HA_CONTAINER" >/dev/null || true
      return "$install_result"
    fi
  fi

  if [[ "$started_here" == true ]]; then docker stop "$HA_CONTAINER" >/dev/null; fi
  printf 'Hermes source installation is ready. The gateway starts after interactive setup.\n'
}

provision() {
  with_admin_lock
  assert_mount_sources
  if container_exists; then die "container $HA_CONTAINER already exists; refusing to overwrite it"; fi
  [[ -f "$HA_ASSETS/Dockerfile" ]] || die "container assets not found under $HA_ASSETS"

  docker build \
    --build-arg "HERMES_UID=$HA_UID" \
    --build-arg "HERMES_GID=$HA_GID" \
    --tag "$HA_IMAGE" \
    "$HA_ASSETS"
  systemctl stop "$HA_SERVICE"
  provision_cleanup() {
    local result=$?
    trap - EXIT
    if [[ "$result" -ne 0 ]] && container_exists && container_running; then
      docker stop "$HA_CONTAINER" >/dev/null || true
    fi
    if [[ "$result" -ne 0 ]]; then
      printf 'Container and data retained. Resume with: sudo hermes-container install\n' >&2
    fi
    exit "$result"
  }
  trap provision_cleanup EXIT
  create_container "$HA_IMAGE"
  install_hermes
  if [[ "${HA_LOCAL_ENABLED:-0}" == 1 ]]; then configure_runtime; fi
  trap - EXIT
  systemctl start "$HA_SERVICE"
  wait_for_container_ready
  printf 'Provisioning complete. Run hermes-container setup to configure messaging.\n'
}

resume_install() {
  with_admin_lock
  assert_managed_container
  assert_mount_sources
  systemctl stop "$HA_SERVICE"
  install_hermes
  if [[ "${HA_LOCAL_ENABLED:-0}" == 1 ]]; then configure_runtime; fi
  systemctl start "$HA_SERVICE"
  wait_for_container_ready
}

configure_runtime() {
  [[ "${HA_LOCAL_ENABLED:-0}" == 1 ]] || die 'local model integration is disabled'
  assert_managed_container
  assert_mount_sources
  [[ -f "$home_dir/.hermes/.container-installed" ]] || die 'install Hermes before configuring local routing'

  runtime_restart_mode=none
  runtime_configured=false
  runtime_temp_dir="$(mktemp -d "$HA_STATE_DIR/.runtime.XXXXXX")"
  runtime_ready_file="$home_dir/.hermes/.container-gateway-ready"
  if systemctl is-active --quiet "$HA_SERVICE"; then
    runtime_restart_mode=systemd
  elif container_running; then
    runtime_restart_mode=docker
  fi
  runtime_cleanup() {
    local result=$?
    trap - EXIT
    if container_running; then docker stop "$HA_CONTAINER" >/dev/null || result=1; fi
    if [[ -f "$runtime_temp_dir/gateway-ready" ]]; then
      mv -- "$runtime_temp_dir/gateway-ready" "$runtime_ready_file" || result=1
    elif [[ "$runtime_configured" == true ]]; then
      install -D -m 0644 /dev/null "$runtime_ready_file" || result=1
    fi
    rm -rf -- "$runtime_temp_dir" || result=1
    if [[ "$runtime_restart_mode" == systemd ]]; then
      systemctl start "$HA_SERVICE" || result=1
    elif [[ "$runtime_restart_mode" == docker ]]; then
      docker start "$HA_CONTAINER" >/dev/null || result=1
    fi
    return "$result"
  }
  # Globals remain available to the EXIT trap if a configuration step fails.
  runtime_on_exit() {
    local exit_result=$?
    runtime_cleanup || exit_result=$?
    exit "$exit_result"
  }
  trap runtime_on_exit EXIT
  systemctl stop "$HA_SERVICE"
  if container_running; then docker stop "$HA_CONTAINER" >/dev/null; fi
  if [[ -f "$runtime_ready_file" ]]; then mv -- "$runtime_ready_file" "$runtime_temp_dir/gateway-ready"; fi
  stage_runtime
  docker start "$HA_CONTAINER" >/dev/null
  wait_for_container_ready
  exec_hermes /usr/local/bin/hermes --container-configure
  runtime_configured=true
  runtime_cleanup
  printf 'Local inference is the default; llama-server remains manually controlled.\n'
}

setup_hermes() {
  assert_managed_container
  container_running || die "start $HA_SERVICE before running interactive setup"
  docker exec --user root "$HA_CONTAINER" test -f "$marker_installed" \
    || die 'Hermes is not installed yet; run sudo hermes-container install'
  docker exec -it --user root "$HA_CONTAINER" gosu hermes env \
    HOME=/home/hermes \
    PATH=/usr/local/bin:/home/hermes/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin \
    hermes setup
  docker exec --user root "$HA_CONTAINER" install -D -m 0644 /dev/null "$marker_gateway_ready"
  printf 'Gateway setup is complete. The running service will start the messaging gateway.\n'
}

service_run() {
  assert_managed_container
  assert_mount_sources
  if container_running; then
    exec docker attach --sig-proxy=false "$HA_CONTAINER"
  fi
  stage_runtime
  exec docker start --attach "$HA_CONTAINER"
}

service_stop() {
  assert_managed_container
  if container_running; then docker stop "$HA_CONTAINER"; fi
}

require_running() {
  assert_managed_container
  container_running || die "start $HA_SERVICE before using Hermes"
}

service_status() {
  if ! container_exists; then printf 'Container %s is not provisioned.\n' "$HA_CONTAINER"; return 3; fi
  docker inspect --format 'container={{.Name}} running={{.State.Running}} image={{.Image}} preserve={{index .Config.Labels "org.lmh01.hermes-agent.preserve"}}' "$HA_CONTAINER"
  docker ps -a --filter "name=^/${HA_CONTAINER}$" --format 'status={{.Status}}'
}

prune_snapshots() {
  local latest snapshot kept=1
  local -a snapshots
  latest="$(readlink -f "$backups_dir/latest")"
  mapfile -d '' -t snapshots < <(
    find "$backups_dir" -mindepth 1 -maxdepth 1 -type d -name 'backup-*' -printf '%T@ %p\0' \
      | sort -z -nr | cut -z -d ' ' -f 2-
  )
  for snapshot in "${snapshots[@]}"; do
    [[ "$snapshot" != "$latest" ]] || continue
    if ((kept < backup_keep)); then
      ((kept += 1))
    else
      rm -rf -- "$snapshot"
    fi
  done
}

backup() {
  with_admin_lock
  assert_managed_container
  assert_mount_sources

  local was_active=false was_running=false stamp temp_dir='' final_dir checkpoint
  backup_restart_mode=none
  backup_temp_dir=
  backup_checkpoint=
  backup_latest_tmp=
  backup_cleanup() {
    local result=$?
    trap - EXIT
    [[ -z "$backup_temp_dir" ]] || rm -rf -- "$backup_temp_dir"
    [[ -z "$backup_latest_tmp" ]] || rm -f -- "$backup_latest_tmp"
    if [[ -n "$backup_checkpoint" ]]; then
      docker image rm "$backup_checkpoint" >/dev/null || result=1
    fi
    if [[ "$backup_restart_mode" == systemd ]]; then
      systemctl start "$HA_SERVICE" || result=1
    elif [[ "$backup_restart_mode" == docker ]]; then
      docker start "$HA_CONTAINER" >/dev/null || result=1
    fi
    exit "$result"
  }
  trap backup_cleanup EXIT

  systemctl is-active --quiet "$HA_SERVICE" && was_active=true
  container_running && was_running=true
  if [[ "$was_active" == true ]]; then
    backup_restart_mode=systemd
    systemctl stop "$HA_SERVICE"
  elif [[ "$was_running" == true ]]; then
    backup_restart_mode=docker
    docker stop "$HA_CONTAINER" >/dev/null
  fi

  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  checkpoint="local/hermes-agent:checkpoint-$stamp-$$"
  temp_dir="$(mktemp -d "$HA_STATE_DIR/.backup.XXXXXX")"
  backup_temp_dir="$temp_dir"
  final_dir="$backups_dir/backup-$stamp-$$"

  docker inspect "$HA_CONTAINER" > "$temp_dir/container-inspect.json"
  backup_checkpoint="$checkpoint"
  docker commit --change "LABEL $preserve_label=true" "$HA_CONTAINER" "$checkpoint" >/dev/null
  docker image save --output "$temp_dir/container-image.tar" "$checkpoint"
  tar --numeric-owner --acls --xattrs -czf "$temp_dir/home.tar.gz" -C "$HA_STATE_DIR" home
  tar --numeric-owner --acls --xattrs -czf "$temp_dir/workspace.tar.gz" -C "$HA_STATE_DIR" workspace
  jq -n \
    --arg createdAt "$stamp" \
    --arg container "$HA_CONTAINER" \
    --arg image "$checkpoint" \
    --arg imageId "$(docker image inspect --format '{{.Id}}' "$checkpoint")" \
    --arg stateDir "$HA_STATE_DIR" \
    --arg home "$home_dir" \
    --arg workspace "$workspace_dir" \
    --arg dockerSocket "$HA_DOCKER_SOCKET" \
    --arg timezone "$HA_TIMEZONE" \
    --arg service "$HA_SERVICE" \
    --arg uid "$HA_UID" \
    --arg gid "$HA_GID" \
    --arg label "$preserve_label=true" \
    '{createdAt:$createdAt,container:$container,image:$image,imageId:$imageId,stateDir:$stateDir,home:$home,workspace:$workspace,dockerSocket:$dockerSocket,timezone:$timezone,service:$service,uid:($uid|tonumber),gid:($gid|tonumber),label:$label}' \
    > "$temp_dir/runtime-settings.json"
  (cd "$temp_dir" && sha256sum container-image.tar home.tar.gz workspace.tar.gz container-inspect.json runtime-settings.json > SHA256SUMS)
  chmod -R go-rwx "$temp_dir"
  mv "$temp_dir" "$final_dir"
  temp_dir=
  backup_temp_dir=
  local latest_tmp="$backups_dir/.latest.$$"
  backup_latest_tmp="$latest_tmp"
  ln -s "$(basename "$final_dir")" "$latest_tmp"
  mv -Tf "$latest_tmp" "$backups_dir/latest"
  backup_latest_tmp=
  prune_snapshots
  printf 'Recovery snapshot saved to %s\n' "$final_dir"
  backup_cleanup
}

restore() {
  with_admin_lock
  [[ $# -le 1 ]] || die 'restore accepts at most one backup directory'
  local backup_dir="${1:-$backups_dir/latest}" image saved
  [[ -d "$backup_dir" ]] || die "backup does not exist: $backup_dir"
  (cd "$backup_dir" && sha256sum --check SHA256SUMS)
  [[ ! -e "$HA_STATE_DIR/home" || -z "$(find "$HA_STATE_DIR/home" -mindepth 1 -print -quit)" ]] \
    || die "refusing to overwrite nonempty home directory: $HA_STATE_DIR/home"
  [[ ! -e "$HA_STATE_DIR/workspace" || -z "$(find "$HA_STATE_DIR/workspace" -mindepth 1 -print -quit)" ]] \
    || die "refusing to overwrite nonempty workspace directory: $HA_STATE_DIR/workspace"
  if container_exists; then die "container $HA_CONTAINER already exists; remove or rename it explicitly before restore"; fi
  systemctl is-active --quiet "$HA_SERVICE" && die "$HA_SERVICE must be stopped before restore"
  # Cancel a pending restart of a previously failed, missing-container unit.
  systemctl stop "$HA_SERVICE"

  saved="$backup_dir/runtime-settings.json"
  for key in stateDir dockerSocket timezone service uid gid; do
    local current expected
    case "$key" in
      stateDir) current="$HA_STATE_DIR" ;;
      dockerSocket) current="$HA_DOCKER_SOCKET" ;;
      timezone) current="$HA_TIMEZONE" ;;
      service) current="$HA_SERVICE" ;;
      uid) current="$HA_UID" ;;
      gid) current="$HA_GID" ;;
    esac
    expected="$(jq -r ".$key" "$saved")"
    [[ "$current" == "$expected" ]] || die "current $key ($current) differs from the snapshot ($expected)"
  done
  image="$(jq -r .image "$saved")"

  install -d -m 0700 "$home_dir" "$workspace_dir"
  tar --numeric-owner --same-owner --same-permissions --acls --xattrs -xzf "$backup_dir/home.tar.gz" -C "$HA_STATE_DIR"
  tar --numeric-owner --same-owner --same-permissions --acls --xattrs -xzf "$backup_dir/workspace.tar.gz" -C "$HA_STATE_DIR"
  docker image load --input "$backup_dir/container-image.tar"
  [[ "$(docker image inspect --format '{{.Id}}' "$image")" == "$(jq -r .imageId "$saved")" ]] \
    || die 'loaded image does not match the snapshot image ID'
  create_container "$image"
  printf 'Recovery restored to a stopped container. Review %s/container-inspect.json, then start %s when ready.\n' "$backup_dir" "$HA_SERVICE"
}

interactive_command() {
  require_running
  case "$1" in
    chat)
      shift
      local -a route_args=()
      case "${1:-}" in
        --chatgpt) shift; route_args=(--provider openai-codex --model "${HA_CLOUD_MODEL:-gpt-6.1-sol}") ;;
        --local) shift ;;
      esac
      exec docker exec --workdir "$workspace_dir" -it --user root "$HA_CONTAINER" gosu hermes env \
        HOME=/home/hermes PATH=/usr/local/bin:/home/hermes/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin \
        hermes chat "${route_args[@]}" "$@"
      ;;
    shell)
      shift
      [[ $# -eq 0 ]] || die 'shell takes no arguments'
      local -a shell_args=(-l)
      if [[ -n "${HA_RUNTIME:-}" ]]; then shell_args=(--rcfile /opt/hermes-container/shellrc -i); fi
      exec docker exec --workdir "$workspace_dir" -it --user root "$HA_CONTAINER" gosu hermes env \
        HOME=/home/hermes PATH=/usr/local/bin:/home/hermes/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin bash "${shell_args[@]}"
      ;;
    exec) shift; [[ $# -gt 0 ]] || die 'exec requires a command'; exec_hermes "$@" ;;
  esac
}

case "${1:-help}" in
  provision) shift; [[ $# -eq 0 ]] || die 'provision takes no arguments'; provision ;;
  install) shift; [[ $# -eq 0 ]] || die 'install takes no arguments'; resume_install ;;
  configure-local) shift; [[ $# -eq 0 ]] || die 'configure-local takes no arguments'; with_admin_lock; configure_runtime ;;
  setup) shift; [[ $# -eq 0 ]] || die 'setup takes no arguments'; setup_hermes ;;
  service-run) shift; [[ $# -eq 0 ]] || die 'service-run takes no arguments'; service_run ;;
  service-stop) shift; [[ $# -eq 0 ]] || die 'service-stop takes no arguments'; service_stop ;;
  status) shift; [[ $# -eq 0 ]] || die 'status takes no arguments'; service_status ;;
  backup) shift; [[ $# -eq 0 ]] || die 'backup takes no arguments'; backup ;;
  restore) shift; restore "$@" ;;
  chat|shell|exec) interactive_command "$@" ;;
  help|-h|--help)
    cat <<EOF
Usage: hermes-container COMMAND

  provision          Build and create the persistent container, then install Hermes once
  install            Resume/retry the source install in an existing managed container
  configure-local    Install/update local routing in the existing container (root; restarts Hermes)
  setup              Run Hermes' interactive setup and enable gateway startup
  service-run        Start and attach to the existing container (systemd ExecStart)
  service-stop       Stop the existing container (systemd ExecStop)
  status             Show container state
  chat [ARGS...]     Run the interactive Hermes CLI (local by default)
  chat --chatgpt     Use ChatGPT for this conversation; saved default stays local
  shell              Open a login shell as hermes
  exec COMMAND...    Run a command as hermes
  backup             Save a full root image plus home/workspace and inspect settings
  restore [DIR]      Restore latest or named snapshot without starting it
EOF
    ;;
  *) die "unknown command: $1 (try hermes-container help)" ;;
esac
