{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.lmh01.programs.sway;
  start-sway = pkgs.writeShellScriptBin "start-sway" /* sh */
    ''
      export WLR_DRM_NO_MODIFIERS=1
      dbus-launch --sh-syntax --exit-with-session ${pkgs.sway}/bin/sway
    '';
in
{

  options.lmh01.programs.sway.enable = mkEnableOption "activate sway";

  config = mkIf cfg.enable {

    home.packages = [
      start-sway
    ];

    wayland.windowManager.sway = {
      enable = true;
      config = {
        modifier = "Mod4";
        terminal = "konsole";
      };
    };

  };
}
