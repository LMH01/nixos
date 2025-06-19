{ config, pkgs, lib, ... }:
with lib;
let cfg = config.lmh01.nextcloud;
in {
  options.lmh01.nextcloud.enable = mkEnableOption "activate nextcloud";
  config = mkIf cfg.enable {
    sops.secrets = {
      "nextcloud/password" = {
        owner = "louis";
      };
    };
    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud31;
      hostName = "localhost";
      phpExtraExtensions = all: [ all.smbclient ];
      config = { 
        adminpassFile = config.sops.secrets."nextcloud/password".path;
        dbtype = "sqlite";
      };
    };
    services.nginx.virtualHosts."localhost".listen = [{ addr = "127.0.0.1"; port = 11808; }];
  };
}
