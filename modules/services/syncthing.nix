{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.services.syncthing;
in
{

  options.lmh01.services.syncthing = {
    enable = mkEnableOption "activate syncthing";
  };

  config = mkIf cfg.enable {

    # TODO create clobal username config and add in the user name variable here
    services = {
      syncthing = {
        enable = true;
        user = "louis";
        dataDir = "/home/louis/Documents"; # Default folder for new synced folders
        configDir = "/home/louis/Documents/.config/syncthing"; # Folder for Syncthing's settings and keys
      };
    };

    # Open syncthing ports
    networking.firewall.allowedTCPPorts = [ 8384 22000 ];
    networking.firewall.allowedUDPPorts = [ 22000 21027 ];

  };
}
