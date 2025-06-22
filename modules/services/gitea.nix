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
    enable_nginx = mkEnableOption "enable nginx";
  };

  config = mkIf cfg.enable {
    services.gitea = {
      enable = true;
      stateDir = "${config.lmh01.storage}/gitea";
      settings.server = {
        ROOT_URL = "https://git.${config.lmh01.domain}:${toString cfg.port}";
        DOMAIN = config.lmh01.domain;
        COOKIE_SECURE = true;
        HTTP_PORT = cfg.port;
      };
      settings.service = {
        DISABLE_REGISTRATION = true;
      };
      settings.webhook = {
        ALLOWED_HOST_LIST = "external,loopback";
      };
    };
    services.nginx.virtualHosts."git.${config.lmh01.domain}" = mkIf cfg.enable_nginx {
      forceSSL = true;
      useACMEHost = "${config.lmh01.domain}";
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
      };
    };
  };
}
