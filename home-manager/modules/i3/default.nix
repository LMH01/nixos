{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.programs.i3;
in
{

  options.lmh01.programs.i3.enable = mkEnableOption "activate i3";

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      i3status-rust
      arandr
      rofi
      konsole
    ];

    services = {
      network-manager-applet.enable = true;
      pasystray.enable = true;
    };

    xsession.enable = true;
    xsession.scriptPath = ".hm-xsession";

    xsession.windowManager.i3 = {
      enable = true;

      package = pkgs.i3-gaps;

      config = {
        # Set modifier to WIN
        modifier = "Mod4";

        menu = "${pkgs.rofi}/bin/rofi";

        terminal = "${pkgs.konsole}/bin/konsole";

        bars = [{
          position = "top";
          # TODO Replace with i3status-rust
          statusCommand = "${pkgs.i3status}/bin/i3status";
        }];

        keybindings =
          let modifier = config.xsession.windowManager.i3.config.modifier;
          in
          lib.mkOptionDefault {

            "${modifier}+d" = "exec dmenu_run";

            "${modifier}+Shift+Escape" = "exec xkill";

            "${modifier}+t" =
              "exec ${pkgs.rofi}/bin/rofi -show run -lines 7 -eh 1 -bw 0  -fullscreen -padding 200";

            "${modifier}+Shift+x" = "exec xscreensaver-command -lock";

            "${modifier}+Shift+Tab" = "workspace prev";

            "${modifier}+Tab" = "workspace next";

            "XF86AudioLowerVolume" =
              "exec --no-startup-id pactl set-sink-volume 0 -5%"; # decrease sound volume

            "XF86AudioMute" =
              "exec --no-startup-id pactl set-sink-mute 0 toggle"; # mute sound

            "XF86AudioNext" = "exec playerctl next";

            "XF86AudioPlay" = "exec playerctl play-pause";

            "XF86AudioPrev" = "exec playerctl previous";

            "XF86AudioRaiseVolume" =
              "exec --no-startup-id pactl set-sink-volume 0 +5% #increase sound volume";

            "XF86AudioStop" = "exec playerctl stop";

            "XF86MonBrightnessDown" =
              "exec xbacklight -dec 20"; # decrease screen brightness

            "XF86MonBrightnessUp" =
              "exec xbacklight -inc 20"; # increase screen brightness

            "Print" = "exec gnome-screenshot -c -i";
          };

      };

    };
  };
}
