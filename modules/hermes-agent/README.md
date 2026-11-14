# Persistent Hermes coding environment

Sunwing runs Hermes in a long-lived Debian container. NixOS manages the container's
startup, shutdown, and local snapshots. Provisioning is explicit: neither booting
nor rebuilding NixOS creates or replaces the container.

The container has a normal Linux userspace, a `hermes` user with passwordless
`sudo`, and Docker CLI, Compose, and Buildx. Its Docker socket is the **host's**
socket: commands can manage the host's containers and files with root-equivalent
authority. This access is intentional.

## First installation

From the repository root, build and activate the Sunwing configuration:

```sh
sudo nixos-rebuild switch --flake "path:$PWD#sunwing"
sudo hermes-container provision
hermes-container setup
```

The explicit `path:` includes new files even before they are tracked by Git.
Provisioning builds the pinned Debian base with development tools, creates the
container, and runs the official noninteractive Hermes source installer inside
it. The initial download requires internet access and may take several minutes.

The setup wizard needs your model provider credentials and the messaging
platform you want to use. Also configure the platform's allowed users. Credentials
stay in the container's persisted home; do not put them in Nix expressions or
commit them to this repository.

If installation is interrupted, the partial container and files are retained.
Resume with:

```sh
sudo hermes-container install
hermes-container setup
```

The gateway waits for setup to complete. The initial NixOS service can report a
missing container before provisioning; it never silently substitutes a fresh
environment for a missing one.

## Daily use

```sh
hermes-container chat                       # Interactive Hermes session
hermes-container shell                      # Shell as the Hermes user
hermes-container exec hermes doctor         # Run an arbitrary command inside
hermes-container status
sudo systemctl restart hermes-agent.service
journalctl -u hermes-agent.service -f
```

Both CLI sessions and the messaging gateway use the same home and configuration.
Hermes's terminal backend is `local` with `home_mode: real`: its commands run in
this Linux environment and use the same home as the interactive shell.
Configure Git identity and repository authentication inside it, then clone
projects into `/var/lib/hermes-agent/workspace`. Concurrent tasks share this
environment; separate branches/worktrees help keep their edits independent.

The container uses bridge networking with outbound internet and LAN access. No
ports are published on the Hermes container by default. It can publish ports on
the additional containers it starts through the host daemon. Check LAN DNS and
VPN routing with the actual destinations you plan to use.

## Local inference

Local inference is the default route for new chats and is saved in Hermes's
persistent profile. It uses the existing manually started llama.cpp server with
the model identifier
`/home/louis/.lmstudio/models/unsloth/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-IQ3_XXS.gguf`
and a 100,000-token context. The host's Docker bridge listener at
`172.17.0.1:11434` proxies to `127.0.0.1:11434`; Hermes never starts or stops
llama.cpp or runs its launch script. Start and manage that server as before.
Its launch command remains in
`/home/louis/Documents/git/local-llm-toolbox/llama-cpp/start_llama-cpp_qwen3.8-27b-IQ3_XSS_single-gpu_no-vision.sh`;
no change to its loopback binding is needed. If it is stopped, local requests
fail until you start it manually.

The local route uses a single active local agent at a time (parallelism 1).
Vision, model-based media, and speech services are unavailable. Task delegation
and optional background inference are disabled, and model requests cannot fall
back to a cloud provider.
Ordinary Hermes tools and internet/LAN access remain available. The container
also retains access to the host Docker socket described above. These are
inference routing controls, not a comprehensive network sandbox.

CLI chats and the messaging gateway continue to use the same persistent Hermes
profile, history, home, and workspace. To start one new chat on ChatGPT while
keeping the saved default local, use:

```sh
hermes-container chat --chatgpt
```

Within an active chat, Hermes's native model command can switch that
conversation with `/model chatgpt` or `/model qwen-local`. These switches are
for the current conversation; the next chat still starts local.

After a Hermes update, explicitly reapply the local integration to the existing
container:

```sh
sudo hermes-container configure-local
```

This root maintenance operation stops and restores the container's current
running state while updating the routing wrapper; it keeps the same persistent
container and profile. The wrapper refuses to start if an update changes the
native launcher interface it depends on. Retest both local inference and
ChatGPT switching after each native Hermes update.

## Docker workflows

From a container shell:

```sh
docker version
docker compose version
cd /var/lib/hermes-agent/workspace
```

The workspace has the same absolute path on the host and inside Hermes. Docker
resolves bind-mount source paths on the host, so keep projects and their Compose
files there when mounting project files into additional containers. Files only
in the Hermes root filesystem are not available as host bind-mount sources.

Use identifying names and labels for containers created for coding tasks, and
clean up those resources specifically. Additional containers use the host's
Docker network namespaces; `localhost` inside Hermes refers to Hermes itself.

## Persistence and updates

| State | Storage |
| --- | --- |
| Debian packages, `/opt/hermes`, and system changes | Existing container's writable filesystem |
| `/home/hermes`, including configuration, credentials, memory, and sessions | `/var/lib/hermes-agent/home` on the host |
| Coding workspace | `/var/lib/hermes-agent/workspace` on both sides |
| Local recovery snapshots | `/var/lib/hermes-agent/backups` on the host |

Stopping, restarting, rebooting, and rebuilding preserve the same container.
Changing the module's image or container settings does not migrate an existing
environment. Settings captured when the container was created require a planned
backup and recovery/migration procedure to change.

Update software inside the environment after taking a backup:

```sh
sudo hermes-container backup
hermes-container shell
# Inside the container:
sudo apt-get update
sudo apt-get upgrade
hermes update
exit
sudo systemctl restart hermes-agent.service
```

The container and its recovery images carry
`org.lmh01.hermes-agent.preserve=true`. The NixOS Docker pruning job excludes that
label, including while the container is stopped. Manual removal or unfiltered
Docker cleanup can still destroy it. Removing the container loses system changes
unless they have been backed up; mounting the home alone is not a full backup.

## Backup and recovery

A daily systemd timer runs `hermes-container backup`; its schedule and retention
are configurable under `lmh01.hermes-agent.backup`. The latest three complete
snapshots are retained by default. Manual backups use the same command. A snapshot
stops the environment, captures its filesystem image and creation metadata, and
archives the persistent home and workspace as a single recovery set. It restores
the previous running state even if backup fails. `backups/latest` points to the
last complete snapshot.

Snapshots contain credentials and source code and are stored with restrictive
permissions. A local snapshot does not protect against losing this machine.
Sunwing currently has no configured Restic backup destinations. Add the complete
`/var/lib/hermes-agent/backups` directory to an existing encrypted Restic job once
its repository is configured, for example:

```nix
services.restic.backups.my-existing-job.paths = [
  "/var/lib/hermes-agent/backups"
];
```

Backups of Hermes do not include unrelated host containers, or the volumes of
additional containers it launches. Add separate backups for those workloads if
they acquire important state.

Recovery is explicit and refuses to overwrite an existing container or nonempty
home/workspace directories:

```sh
sudo hermes-container restore /path/to/complete-snapshot
sudo systemctl start hermes-agent.service
```

Keep the snapshot's original data safe and stop the service before any deliberate
replacement. Restore does not start the gateway automatically, allowing you to
inspect the environment before messaging integrations reconnect. Retest package
availability, workspace files, credentials, Docker access, and gateway operation
after recovery.

## Development checks

Build the helper (including ShellCheck) without activating the host:

```sh
nix build --no-link --impure --expr '
  let f = builtins.getFlake ("path:" + toString ./.);
  in builtins.head (builtins.filter (p: p.name == "hermes-container")
    f.nixosConfigurations.sunwing.config.environment.systemPackages)
'
```

Run the isolated lifecycle checks:

```sh
nix build --no-link --impure --expr '
  let
    f = builtins.getFlake ("path:" + toString ./.);
    pkgs = import f.inputs.nixpkgs {};
  in import ./modules/hermes-agent/tests { inherit pkgs; }
'
```

These checks use mocked Docker/systemd commands and do not create containers or
change host services. A live image build, Hermes installation, network access,
and messaging onboarding still need validation during first provisioning.
