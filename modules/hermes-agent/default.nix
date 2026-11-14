{ config, lib, pkgs, ... }:

let
  cfg = config.lmh01.hermes-agent;
  preserveLabel = "org.lmh01.hermes-agent.preserve=true";
  localBaseUrl = "http://${cfg.localModel.gatewayAddress}:${toString cfg.localModel.gatewayPort}/v1";
  runtimePolicy = pkgs.writeText "hermes-agent-policy.json" (builtins.toJSON {
    enabled = cfg.localModel.enable;
    base_url = localBaseUrl;
    model = cfg.localModel.model;
    context_length = cfg.localModel.contextLength;
    cloud_model = cfg.localModel.cloudModel;
  });

  assets = pkgs.runCommand "hermes-agent-container-assets" { } ''
    mkdir -p "$out"
    cp -R ${./container}/. "$out/"
  '';

  hermesContainer = pkgs.writeShellApplication {
    name = "hermes-container";
    runtimeInputs = with pkgs; [
      docker
      docker-compose
      coreutils
      curl
      findutils
      gnugrep
      gnutar
      gzip
      jq
      util-linux
      systemd
      bash
    ];
    text = ''
      export HA_CONTAINER=${lib.escapeShellArg cfg.containerName}
      export HA_STATE_DIR=${lib.escapeShellArg cfg.stateDirectory}
      export HA_IMAGE=${lib.escapeShellArg cfg.image}
      export HA_UID=${toString cfg.uid}
      export HA_GID=${toString cfg.gid}
      export HA_BACKUP_KEEP=${toString cfg.backup.keepSnapshots}
      export HA_DOCKER_SOCKET=/var/run/docker.sock
      export HA_TIMEZONE=${lib.escapeShellArg cfg.timeZone}
      export HA_ASSETS=${assets}
      export HA_SERVICE=hermes-agent.service
      export HA_LOCAL_ENABLED=${if cfg.localModel.enable then "1" else "0"}
      export HA_LOCAL_BASE_URL=${lib.escapeShellArg localBaseUrl}
      export HA_CLOUD_MODEL=${lib.escapeShellArg cfg.localModel.cloudModel}
      export HA_RUNTIME=${./runtime}
      export HA_POLICY_FILE=${runtimePolicy}

      ${builtins.readFile ./hermes-container.sh}
    '';
  };
in
{
  options.lmh01.hermes-agent = {
    enable = lib.mkEnableOption "the persistent Hermes Agent container";

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "hermes-agent";
      description = "Docker container name used by the Hermes Agent helper.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hermes-agent";
      description = "Persistent host directory mounted into the Hermes container.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "local/hermes-agent:initial";
      description = "Locally built Hermes Agent image tag.";
    };

    uid = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10000;
      description = "UID used by the unprivileged Hermes user in the container.";
    };

    gid = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10000;
      description = "GID used by the unprivileged Hermes user in the container.";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = if config.time.timeZone == null then "UTC" else config.time.timeZone;
      description = "Timezone passed into the Hermes container.";
    };

    localModel = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Expose the host's local model server to Hermes over the Docker bridge.";
      };

      model = lib.mkOption {
        type = lib.types.str;
        default = "/home/louis/.lmstudio/models/unsloth/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-IQ3_XXS.gguf";
        description = "Exact model identifier reported by the manually started server's /v1/models endpoint.";
      };

      contextLength = lib.mkOption {
        type = lib.types.ints.positive;
        default = 100000;
        description = "Total local context budget, including generated tokens.";
      };

      cloudModel = lib.mkOption {
        type = lib.types.str;
        default = "gpt-6.1-sol";
        description = "ChatGPT model used for an explicitly selected cloud conversation.";
      };

      gatewayAddress = lib.mkOption {
        type = lib.types.str;
        default = "172.17.0.1";
        description = "Host address on the Docker bridge where the local model proxy listens.";
      };

      gatewayPort = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Host port on the Docker bridge where Hermes reaches the local model proxy.";
      };

      upstreamAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Loopback address of the manually managed host model server.";
      };

      upstreamPort = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port of the manually managed host model server.";
      };
    };

    backup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable daily local Hermes state snapshots.";
      };

      calendar = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "systemd calendar expression for local Hermes snapshots.";
      };

      keepSnapshots = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3;
        description = "Number of local Hermes snapshots to retain.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ hermesContainer ];

    # Keep this service attached to the existing container. A NixOS switch
    # must not stop/recreate it when only the unit definition changes.
    systemd.services.hermes-agent = {
      description = "Persistent Hermes Agent container";
      wantedBy = [ "multi-user.target" "docker.service" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      partOf = [ "docker.service" ];
      restartIfChanged = false;
      stopIfChanged = false;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${hermesContainer}/bin/hermes-container service-run";
        ExecStop = "${hermesContainer}/bin/hermes-container service-stop";
        Restart = "always";
        RestartSec = "5s";
        TimeoutStopSec = "90s";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDirectory} 0711 root root -"
      "d ${cfg.stateDirectory}/home 0700 ${toString cfg.uid} ${toString cfg.gid} -"
      "d ${cfg.stateDirectory}/workspace 0700 ${toString cfg.uid} ${toString cfg.gid} -"
      "d ${cfg.stateDirectory}/backups 0700 root root -"
    ];

    systemd.services.hermes-agent-backup = lib.mkIf cfg.backup.enable {
      description = "Create an atomic local Hermes Agent state snapshot";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${hermesContainer}/bin/hermes-container backup";
      };
    };

    # Give the existing Docker container access to the host's already-running
    # model server. The listener is bound only to the Docker bridge gateway;
    # socket activation starts a TCP proxy and never launches llama-server.
    systemd.sockets.hermes-local-model = lib.mkIf cfg.localModel.enable {
      description = "Docker bridge listener for the host local model server";
      wantedBy = [ "multi-user.target" "docker.service" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      partOf = [ "docker.service" ];
      socketConfig = {
        ListenStream = "${cfg.localModel.gatewayAddress}:${toString cfg.localModel.gatewayPort}";
        BindToDevice = "docker0";
      };
    };

    systemd.services.hermes-local-model = lib.mkIf cfg.localModel.enable {
      description = "Proxy Hermes local model connections to the host model server";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      partOf = [ "docker.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd ${cfg.localModel.upstreamAddress}:${toString cfg.localModel.upstreamPort}";
        DynamicUser = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    networking.firewall.interfaces.docker0.allowedTCPPorts = lib.mkIf cfg.localModel.enable [
      cfg.localModel.gatewayPort
    ];

    systemd.timers.hermes-agent-backup = lib.mkIf cfg.backup.enable {
      description = "Daily Hermes Agent state snapshot";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.backup.calendar;
        Persistent = true;
      };
    };

    # Docker's weekly system prune also removes stopped containers. Protect
    # the Hermes container and any tagged recovery images by their label.
    virtualisation.docker.autoPrune.flags = lib.mkAfter [
      "--filter=label!=${preserveLabel}"
    ];

    virtualisation.docker.enable = lib.mkDefault true;

    assertions = [
      {
        assertion = builtins.match "[a-zA-Z0-9][a-zA-Z0-9_.-]*" cfg.containerName != null;
        message = "lmh01.hermes-agent.containerName must be a valid Docker container name.";
      }
      {
        assertion = builtins.match "/[a-zA-Z0-9_./-]+" cfg.stateDirectory != null
          && lib.all (part: !(builtins.elem part [ "" "." ".." ])) (lib.tail (lib.splitString "/" cfg.stateDirectory));
        message = "lmh01.hermes-agent.stateDirectory must be a normalized, non-root absolute path containing only letters, numbers, underscores, dots, slashes and hyphens.";
      }
    ];
  };
}
