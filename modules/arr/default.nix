{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.arr;
in
{

  options.lmh01.arr = {
    enable = mkEnableOption "activate arr stack";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      qbittorrent
    ];

    services = {
      jellyseerr = {
        enable = true;
        openFirewall = true;
      };
      radarr = {
        enable = true;
      };
      sonarr = {
        enable = true;
      };
      prowlarr = {
        enable = true;
      };
    };
  };
}
