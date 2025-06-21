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
      "hetzner-api" = { };
    };

    services.nginx = {
        enable = true;
        recommendedOptimisation = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        sslDhparam = config.sops.secrets."nginx/dhparam".path;
    };


    # currently untested if it works as intended
    security.acme = {
      acceptTerms = true;
      defaults.email = "lmh01+acme@skl2.de";
      certs."${config.lmh01.domain}" = {
        domain = config.lmh01.domain;
        extraDomainNames = [ "*.${config.lmh01.domain}" ];
        dnsProvider = "hetzner";
        environmentFile = config.sops.secrets."hetzner-api".path;
        webroot = null;
      };
    };

    # Open syncthing ports
    networking.firewall.allowedTCPPorts = [ 80 443 ];
    networking.firewall.allowedUDPPorts = [ 80 443 ];

  };
}