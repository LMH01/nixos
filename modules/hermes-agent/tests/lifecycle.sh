#!/usr/bin/env bash
# Exercise lifecycle and recovery using fake Docker/systemd commands only.
set -euo pipefail

helper=$(realpath "$1")
assets=$(realpath "$2")
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
export REAL_ID
REAL_ID=$(command -v id)
mkdir -p "$test_root/bin"

printf '#!%s\n' "$BASH" > "$test_root/bin/id"
cat >> "$test_root/bin/id" <<'SH'
if [[ "$*" == -u ]]; then
  printf '%s\n' "${FAKE_UID:-0}"
else
  exec "$REAL_ID" "$@"
fi
SH

printf '#!%s\n' "$BASH" > "$test_root/bin/systemctl"
cat >> "$test_root/bin/systemctl" <<'SH'
set -euo pipefail
printf 'systemctl %s\n' "$*" >> "$FAKE_DIR/calls"
case "$1" in
  is-active) test -f "$FAKE_DIR/active" ;;
  stop)
    rm -f "$FAKE_DIR/active" "$FAKE_DIR/running"
    [[ ! -f "$FAKE_DIR/fail-stop" ]] || exit 43
    ;;
  start) touch "$FAKE_DIR/active" "$FAKE_DIR/running" ;;
  reset-failed) : ;;
  *) printf 'Unexpected systemctl command: %s\n' "$*" >&2; exit 99 ;;
esac
SH

printf '#!%s\n' "$BASH" > "$test_root/bin/docker"
cat >> "$test_root/bin/docker" <<'SH'
set -euo pipefail
[[ "${DOCKER_HOST:-}" == "unix://$HA_DOCKER_SOCKET" && -z "${DOCKER_CONTEXT:-}" ]]
printf 'docker %s\n' "$*" >> "$FAKE_DIR/calls"
case "$1" in
  container)
    [[ "$2" == inspect ]]
    test -f "$FAKE_DIR/exists"
    printf '[{"Name":"/hermes-test","Config":{"Labels":{"org.lmh01.hermes-agent.preserve":"true"}}}]\n'
    ;;
  inspect)
    test -f "$FAKE_DIR/exists"
    if [[ "$*" == *'.State.Running'* ]]; then
      if [[ -f "$FAKE_DIR/running" ]]; then echo true; else echo false; fi
    elif [[ "$*" == *'.Config.Labels'* ]]; then
      if [[ -f "$FAKE_DIR/unlabelled" ]]; then echo false; else echo true; fi
    else
      printf '[{"Name":"/hermes-test","HostConfig":{"RestartPolicy":{"Name":"no"}}}]\n'
    fi
    ;;
  start|attach) touch "$FAKE_DIR/running" ;;
  stop) rm -f "$FAKE_DIR/running" ;;
  create) touch "$FAKE_DIR/exists"; echo fake-container ;;
  commit) echo sha256:fake-image ;;
  image)
    case "$2" in
      save)
        [[ ! -f "$FAKE_DIR/fail-save" ]] || exit 42
        shift 2
        [[ "$1" == --output ]]
        printf 'fake saved container image\n' > "$2"
        ;;
      inspect) echo sha256:fake-image ;;
      load|rm) : ;;
      *) printf 'Unexpected docker image command: %s\n' "$*" >&2; exit 99 ;;
    esac
    ;;
  exec)
    if [[ "$*" == *--container-configure* && -f "$FAKE_DIR/fail-configure" ]]; then exit 71; fi
    ;;
  cp|ps) : ;;
  *) printf 'Unexpected docker command: %s\n' "$*" >&2; exit 99 ;;
esac
SH
chmod +x "$test_root/bin/"*
export PATH="$test_root/bin:$PATH"
export HA_CONTAINER=hermes-test HA_IMAGE=local/hermes-test:initial HA_ASSETS="$assets"
export HA_SERVICE=hermes-test.service HA_TIMEZONE=UTC HA_BACKUP_KEEP=3
export HA_UID HA_GID
HA_UID=$("$REAL_ID" -u)
HA_GID=$("$REAL_ID" -g)

new_case() {
  unset HA_RUNTIME HA_POLICY_FILE HA_LOCAL_ENABLED
  export FAKE_DIR="$test_root/$1"
  export HA_STATE_DIR="$FAKE_DIR/state"
  export HA_DOCKER_SOCKET="$FAKE_DIR/docker.sock"
  mkdir -p "$HA_STATE_DIR/home" "$HA_STATE_DIR/workspace" "$HA_STATE_DIR/backups"
  : > "$FAKE_DIR/calls"
  python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.close()' "$HA_DOCKER_SOCKET"
}

run() { bash "$helper" "$@"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; cat "$FAKE_DIR/calls" >&2; exit 1; }
expect_failure() {
  if run "$@" > "$FAKE_DIR/output" 2>&1; then
    fail "command unexpectedly succeeded: $*"
  fi
}
assert_no_container_mutation() {
  if grep -Eq '^docker (create|build|rm|start|stop|commit|image (load|rm)) ' "$FAKE_DIR/calls"; then
    fail 'read/refusal path mutated container state'
  fi
}

new_case missing
expect_failure service-run
assert_no_container_mutation
grep -Fq 'does not exist' "$FAKE_DIR/output"

new_case unlabelled
touch "$FAKE_DIR/exists" "$FAKE_DIR/unlabelled"
expect_failure service-run
assert_no_container_mutation

new_case start-existing
touch "$FAKE_DIR/exists"
export DOCKER_HOST=tcp://unrelated-daemon:2375 DOCKER_CONTEXT=unrelated-context
run service-run
unset DOCKER_HOST DOCKER_CONTEXT
grep -Eq '^docker start .*--attach' "$FAKE_DIR/calls"
if grep -Eq '^docker (create|build|rm) ' "$FAKE_DIR/calls"; then fail 'startup recreated the environment'; fi

new_case adopt-running
touch "$FAKE_DIR/exists" "$FAKE_DIR/running"
run service-run
grep -Fq 'docker attach --sig-proxy=false hermes-test' "$FAKE_DIR/calls"
if grep -Eq '^docker (create|build|rm|stop) ' "$FAKE_DIR/calls"; then fail 'startup disturbed a running environment'; fi

new_case missing-workspace
touch "$FAKE_DIR/exists"
rmdir "$HA_STATE_DIR/workspace"
expect_failure service-run
assert_no_container_mutation

new_case existing-provision
touch "$FAKE_DIR/exists"
expect_failure provision
assert_no_container_mutation

new_case configure-failure
touch "$FAKE_DIR/exists" "$FAKE_DIR/active" "$FAKE_DIR/running" "$FAKE_DIR/fail-configure"
mkdir -p "$HA_STATE_DIR/home/.hermes" "$FAKE_DIR/runtime"
touch "$HA_STATE_DIR/home/.hermes/.container-installed" "$HA_STATE_DIR/home/.hermes/.container-gateway-ready"
touch "$FAKE_DIR/runtime/hermes" "$FAKE_DIR/runtime/launcher.py" "$FAKE_DIR/policy.json"
export HA_LOCAL_ENABLED=1 HA_RUNTIME="$FAKE_DIR/runtime" HA_POLICY_FILE="$FAKE_DIR/policy.json"
expect_failure configure-local
[[ -f "$FAKE_DIR/active" && -f "$FAKE_DIR/running" ]] || fail 'routing configuration failure left service stopped'
[[ -f "$HA_STATE_DIR/home/.hermes/.container-gateway-ready" ]] || fail 'routing configuration failure lost readiness marker'
[[ -z "$(find "$HA_STATE_DIR" -maxdepth 1 -name '.runtime.*' -print -quit)" ]] || fail 'routing configuration failure leaked staging state'

new_case explicit-cloud
touch "$FAKE_DIR/exists" "$FAKE_DIR/running"
run chat --chatgpt --cli
grep -Fq 'hermes chat --provider openai-codex --model gpt-6.1-sol --cli' "$FAKE_DIR/calls"

new_case backup-running
touch "$FAKE_DIR/exists" "$FAKE_DIR/active" "$FAKE_DIR/running"
printf 'retained user data\n' > "$HA_STATE_DIR/home/important"
printf 'retained code\n' > "$HA_STATE_DIR/workspace/code"
run backup
[[ -f "$FAKE_DIR/active" && -f "$FAKE_DIR/running" ]] || fail 'successful backup did not restart service'
[[ -L "$HA_STATE_DIR/backups/latest" ]] || fail 'snapshot not atomically published'
snapshot=$(readlink -f "$HA_STATE_DIR/backups/latest")
(cd "$snapshot" && sha256sum --check SHA256SUMS)
grep -Fq 'LABEL org.lmh01.hermes-agent.preserve=true' "$FAKE_DIR/calls"

# A failed new snapshot must retain the previous complete one and recover uptime.
touch "$FAKE_DIR/fail-save"
expect_failure backup
[[ -f "$FAKE_DIR/active" && -f "$FAKE_DIR/running" ]] || fail 'failed backup left the service stopped'
[[ "$(readlink -f "$HA_STATE_DIR/backups/latest")" == "$snapshot" ]] || fail 'failed backup replaced latest'
[[ -z "$(find "$HA_STATE_DIR" -maxdepth 1 -name '.backup.*' -print -quit)" ]] || fail 'failed snapshot leaked staging directory'
rm "$FAKE_DIR/fail-save"

# Even a partial failure while stopping must restore the previous service state.
touch "$FAKE_DIR/fail-stop"
expect_failure backup
[[ -f "$FAKE_DIR/active" && -f "$FAKE_DIR/running" ]] || fail 'stop failure did not restore service'
[[ "$(readlink -f "$HA_STATE_DIR/backups/latest")" == "$snapshot" ]] || fail 'stop failure replaced latest'
rm "$FAKE_DIR/fail-stop"

# Local retention is bounded, and latest is always complete.
for ((iteration = 0; iteration < 3; iteration++)); do run backup; done
count=$(find "$HA_STATE_DIR/backups" -maxdepth 1 -type d -name 'backup-*' | wc -l)
[[ "$count" -eq 3 ]] || fail "expected three retained snapshots, got $count"
snapshot=$(readlink -f "$HA_STATE_DIR/backups/latest")

# Refuse destructive restore paths before loading an image or creating a container.
: > "$FAKE_DIR/calls"
expect_failure restore "$snapshot"
assert_no_container_mutation
rm "$FAKE_DIR/exists" "$FAKE_DIR/active" "$FAKE_DIR/running"
: > "$FAKE_DIR/calls"
expect_failure restore "$snapshot"
assert_no_container_mutation
[[ -f "$HA_STATE_DIR/home/important" ]] || fail 'restore damaged existing data'

# Explicit restore reconstructs both mounted data and a stopped container.
rm "$HA_STATE_DIR/home/important" "$HA_STATE_DIR/workspace/code"
run restore "$snapshot"
[[ -f "$HA_STATE_DIR/home/important" && -f "$HA_STATE_DIR/workspace/code" ]] || fail 'restore lost mounted data'
[[ -f "$FAKE_DIR/exists" && ! -f "$FAKE_DIR/running" && ! -f "$FAKE_DIR/active" ]] || fail 'restore unexpectedly started gateway'

new_case backup-stopped
touch "$FAKE_DIR/exists"
run backup
[[ ! -f "$FAKE_DIR/active" && ! -f "$FAKE_DIR/running" ]] || fail 'backup started a stopped environment'
snapshot=$(readlink -f "$HA_STATE_DIR/backups/latest")
printf 'corrupted archive\n' >> "$snapshot/container-image.tar"
rm "$FAKE_DIR/exists"
: > "$FAKE_DIR/calls"
expect_failure restore "$snapshot"
assert_no_container_mutation

new_case setup-tty
touch "$FAKE_DIR/exists" "$FAKE_DIR/running"
run setup
grep -Fq 'docker exec -it --user root' "$FAKE_DIR/calls"

new_case requires-root
touch "$FAKE_DIR/exists"
export FAKE_UID=1000
expect_failure backup
assert_no_container_mutation
unset FAKE_UID

printf 'Hermes lifecycle, backup failure recovery, retention, and restore checks passed.\n'
