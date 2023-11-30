{ config, pkgs, lib, ... }:
with lib;
let cfg = config.lmh01.jellyfin;
in {
  options.lmh01.jellyfin.enable = mkEnableOption "activate jellyfin";
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      jellyfin-ffmpeg
    ];
    services = {
      jellyfin = {
        # package = pkgs.cudapkgs.jellyfin;
        enable = true;
        openFirewall = true;
      };
    };
  };
}