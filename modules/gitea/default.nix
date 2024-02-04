{ config, pkgs, lib, ... }:
with lib;
let cfg = config.lmh01.gitea;
in {
  options.lmh01.gitea = {
    enable = mkEnableOption "activate gitea";
    port = mkOption {
      type = types.int;
      default = 3000;
      description = "port to run the application on";
    };
    domain = mkOption {
      type = with types; nullOr str;
      default = null;
      description = "the default url";
    };
  };


  config = mkIf cfg.enable {
    services.gitea = {
      enable = true;
      stateDir = "${config.lmh01.storage}/gitea";
      settings.server = {
        ROOT_URL = "https://${cfg.domain}";
        DOMAIN = cfg.domain;
        COOKIE_SECURE = true;
        HTTP_PORT = cfg.port;
        PROTOCOL = "https";
        CERT_FILE = "${config.lmh01.storage}/gitea/ssl/cert.pem";
        KEY_FILE = "${config.lmh01.storage}/gitea/ssl/key.pem";
      };
      settings.service = {
        DISABLE_REGISTRATION = true;
      };
      settings.webhook = {
        ALLOWED_HOST_LIST = "external,loopback";
      };
    };
    networking.firewall.allowedTCPPorts = [
      cfg.port # used by home assistant
    ];
  };
}
