{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.docker;
in
{

  options.lmh01.docker = { enable = mkEnableOption "activate docker"; };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [ docker-compose ];

    virtualisation.docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    virtualisation.oci-containers = {
      backend = "docker";
    };

    # TODO maybe move louis into user variable which makes it easier to change the user
    users.extraUsers.louis.extraGroups =
      [ "docker" ];

  };
}
