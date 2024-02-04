{ config, lib, ... }:
with lib;
let cfg = config.lmh01.woodpecker;
in {
  options.lmh01.woodpecker = {
    enable = mkEnableOption "activate woodpecker";
    domain = mkOption {
      type = with types; nullOr str;
      default = null;
      description = "the default url";
    };
  };
  config = mkIf cfg.enable {
    services.woodpecker-server = {
      enable = true;
      environment = {
        WOODPECKER_HOST = "https://${cfg.domain}:8100";
        WOODPECKER_OPEN = "true";
        WOODPECKER_GITEA = "true";
        WOODPECKER_GITEA_URL = "http://${config.lmh01.gitea.domain}:3000";
        WOODPECKER_GITEA_SKIP_VERIFY = "true"; # skip verification because certificate is self signed
        WOODPECKER_SERVER_ADDR_TLS = ":8100";
      };
      environmentFile = "${config.lmh01.secrets}/woodpecker/environment";
    };

    services.woodpecker-agents.agents.docker = {
      enable = true;
      environment = {
        WOODPECKER_SERVER = "${cfg.domain}:9000";
        WOODPECKER_MAX_WORKFLOWS = "1";
        WOODPECKER_BACKEND = "docker";
        WOODPECKER_HEALTHCHECK = "false";
      };
      # contains the secret required to register the agent
      environmentFile = [ "${config.lmh01.secrets}/woodpecker/environment" ];
      extraGroups = [ "docker" ];
    };

    networking.firewall.allowedTCPPorts = [
      8000 # hhtp
      8100 # https port
    ];
  };
}
