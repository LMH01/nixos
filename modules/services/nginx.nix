{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.services.nginx;
in
{

  options.lmh01.services.nginx = {
    enable = mkEnableOption "activate nginx";
  };

  config = mkIf cfg.enable {
    
    # setup sops
    sops.secrets = {
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

    services.nginx = {
        enable = true;
        recommendedOptimisation = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        sslDhparam = config.sops.secrets."nginx/dhparam".path;
    };

    # Open syncthing ports
    networking.firewall.allowedTCPPorts = [ 80 443 ];
    networking.firewall.allowedUDPPorts = [ 80 443 ];

  };
}