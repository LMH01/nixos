{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.services.nginx;
in
{

  options.lmh01.services.nginx = {
    enable = mkEnableOption "activate nginx";
    enable_acme = mkEnableOption "enable acme";
  };

  config = mkIf cfg.enable {
    
    # setup sops
    sops.secrets = {
      "hetzner-api" = { };
      "nginx/dhparam" = {
        owner = "nginx";
      };
    };

    services.nginx = {
        enable = true;
	# increase max body size to allow video upload to immich
	clientMaxBodySize = "5000m";
        recommendedOptimisation = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        sslDhparam = config.sops.secrets."nginx/dhparam".path;
    };

    security.acme = mkIf cfg.enable_acme {
      acceptTerms = true;
      defaults.email = "lmh01+acme@skl2.de";
      # required because otherwise local DNS Server interrupts challenge
      defaults.dnsResolver = "8.8.8.8:53";
      certs."${config.lmh01.domain}" = {
        domain = config.lmh01.domain;
        extraDomainNames = [ "*.${config.lmh01.domain}" ];
        dnsProvider = "hetzner";
        environmentFile = config.sops.secrets."hetzner-api".path;
        webroot = null;
      };
    };

    # required for nginx to be able to read the certificate
    users.users.nginx.extraGroups = [ "acme" ];

    # Open ports
    networking.firewall.allowedTCPPorts = [ 80 443 ];
    networking.firewall.allowedUDPPorts = [ 80 443 ];

  };
}
