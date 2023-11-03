{ config, lib, ... }:
with lib;
let cfg = config.lmh01.wireguard;
in {
  options.lmh01.wireguard.enable = mkEnableOption "activate wireguard";
  config = mkIf cfg.enable {
    networking = {
      wireguard.enable = true;
      nat = {
        enable = true;
        enableIPv6 = true;
      };
      firewall = {
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [ 53 51820 ];
        logReversePathDrops = true;
      };
    };
  };
}

