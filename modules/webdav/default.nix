{ lib, config, ... }:
with lib;
let cfg = config.lmh01.webdav;
in
{

  options.lmh01.webdav = {
    enable = mkEnableOption "activate webdav";
    enable_nginx = mkEnableOption "enable nginx";
  };

  config = mkIf cfg.enable {

    sops.secrets."webdav/config.yaml" = { owner = "louis"; };


    services.webdav = {
      enable = true;
      configFile = config.sops.secrets."webdav/config.yaml".path;
      user = "louis";
    };
    
    services.nginx.virtualHosts."webdav.${config.lmh01.domain}" = mkIf cfg.enable_nginx {
      forceSSL = true;
      useACMEHost = "${config.lmh01.domain}";
      locations."/" = {
        proxyPass = "http://127.0.0.1:22808";
      };
    };

  };
}



