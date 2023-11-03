{ config, lib, ... }:
with lib;
let cfg = config.lmh01.wg-sn;
in {
  options.lmh01.wg-sn.enable = mkEnableOption "activate wg-sn";
  config = mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = [ 51820 ];
    networking.firewall.checkReversePath = mkForce false;
    networking.wireguard.interfaces = {
      wg-link = {
        ips = [ "10.0.1.2/24" "fdc9:281f:04d7:9eea::2/64" ];
        privateKeyFile = "${config.lmh01.secrets}/wg-sn-louis.private";
        peers = [
          {
            publicKey = "p3ZnR7XTY8dO+zmUzMQUjVQHQwWFxIUTu9jvcuuUrQc=";
            presharedKeyFile = "${config.lmh01.secrets}/wg-sn-louis.preshared";
            allowedIPs = [ "10.0.1.0/24" "fdc9:281f:04d7:9eea::1/64" ];
            endpoint = "alinkbetweennets.de:51820";
            persistentKeepalive = 25;
          }
        ];
      };
    };
  };
}
