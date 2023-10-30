{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.lmh01.oneko;
in
{
  options.lmh01.oneko.enable = mkEnableOption "activate oneko";
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ oneko ];
    systemd.user.services.oneko = {
      description = "oneko";
      serviceConfig.PassEnvironment = "DISPLAY";
      script = ''
        oneko
      '';
      path = with pkgs; [ oneko ];
      wantedBy = [ "multi-user.target" ]; # starts after (next) login
    };
  };
}
