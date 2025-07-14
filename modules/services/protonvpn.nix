{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.services.protonvpn;
in
{

  options.lmh01.services.protonvpn = {
    enable = mkEnableOption "activate protonvpn";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ 
      protonvpn-gui
    ];
    
    # required for wireguard to work with protonvpn
    # for some reason a normal wg-quick connection does not work for my gui systems currently (while it works for the server systems) (as of 03.07.2025)
    networking.firewall.checkReversePath = false;
  };
}