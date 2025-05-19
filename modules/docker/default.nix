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
      # disabled for now as otherwise shutdown hangs while waiting for s6-svscan
      liveRestore = false;
      # pinned to docker_26 for now as docker 27.x and 28.x in NixOS include a bug that causes random 'unexpected EOF's when pulling docker images, which then leads to the docker daemon crashing (and stopping all containers).
      package = pkgs.docker_26;
    };

    virtualisation.oci-containers = {
      backend = "docker";
    };

    # TODO maybe move louis into user variable which makes it easier to change the user
    users.extraUsers.louis.extraGroups =
      [ "docker" ];

  };
}
