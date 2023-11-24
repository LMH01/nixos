{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.steam;
in
{

  options.lmh01.steam = {
    enable = mkEnableOption "activate steam";
  };

  config = mkIf cfg.enable {

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    };
    hardware.opengl.driSupport32Bit = true; # Enables support for 32bit libs that steam uses

  };
}



