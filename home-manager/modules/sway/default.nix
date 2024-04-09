{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.lmh01.programs.sway;
  start-sway = pkgs.writeShellScriptBin "start-sway" /* sh */
    ''
      dbus-launch --sh-syntax --exit-with-session ${pkgs.sway}/bin/sway --unsupported-gpu
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
        # Set modifier to WIN
        modifier = "Mod4";

        input = {
          "type:keyboard" = {
            xkb_layout = "de";
          };
          "type:touchpad" = {
            click_method = "clickfinger";
            tap = "enabled";
          };
        };

        terminal = "${pkgs.foot}/bin/foot";
        menu = "${pkgs.rofi}/bin/rofi -show combi";

        keybindings = lib.mkOptionDefault (
          (lib.attrsets.mergeAttrsList [

            # general keybindings not specific to laptop or desktop
            (lib.optionalAttrs true {
              "Mod1+space" = "exec ${pkgs.rofi}/bin/rofi -show combi";
            })

            # desktop specific keybindings
            (lib.optionalAttrs (config.lmh01.options.type == "desktop") { })

            # laptop specific keybindings
            (lib.optionalAttrs (config.lmh01.options.type == "laptop") { })

          ])
        );

      };
    };

  };
}
