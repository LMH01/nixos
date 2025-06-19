{ config, pkgs, lib, ... }:
with lib;
let cfg = config.lmh01.nextcloud;
# this module is currently experimental
in {
  options.lmh01.nextcloud.enable = mkEnableOption "activate nextcloud";
  config = mkIf cfg.enable {
    sops.secrets = {
      "nextcloud/password" = {
        owner = "louis";
      };
      "nginx/dhparam" = {
        owner = "nginx";
      };
      "nginx/sslCertificate" = {
        owner = "nginx";
      };
      "nginx/sslCertificateKey" = {
        owner = "nginx";
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
      https = true;
    };
    services.nginx = {
      virtualHosts."localhost" = {
        listen = [{ addr = "127.0.0.1"; port = 11808; }];
        addSSL = true;
        sslCertificate = config.sops.secrets."nginx/sslCertificate".path;
        sslCertificateKey = config.sops.secrets."nginx/sslCertificateKey".path;
      };
      sslDhparam = config.sops.secrets."nginx/dhparam".path;
    };
  };
}
