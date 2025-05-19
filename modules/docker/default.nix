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
      # enabled for now as otherwise shutdown hangs while waiting for s6-svscan
      liveRestore = false;
      package = pkgs.docker_28;
    };

    virtualisation.oci-containers = {
      backend = "docker";
    };

    # TODO maybe move louis into user variable which makes it easier to change the user
    users.extraUsers.louis.extraGroups =
      [ "docker" ];

  };
}
