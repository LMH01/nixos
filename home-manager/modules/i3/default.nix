{ lib, pkgs, config, flake-self, ... }:
with lib;
let cfg = config.lmh01.programs.i3;
in
{

  imports = with flake-self.homeManagerModules; [
    i3status-rust
    rofi
  ];

  options.lmh01.programs.i3.enable = mkEnableOption "activate i3";

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      arandr
      flameshot
      konsole
      playerctl # musik controlls for pipewire/pulse
    ];

    services = {
      dunst.enable = true; # notification daemon
      network-manager-applet.enable = true;
      pasystray.enable = true;
    };

    # i3 status rust
    lmh01.programs.i3status-rust.enable = true;
    # rofi
    lmh01.programs.rofi.enable = true;

    xsession.enable = true;
    xsession.scriptPath = ".hm-xsession";

    xsession.windowManager.i3 = {
      enable = true;

      package = pkgs.i3-gaps;

      config = {
        # Set modifier to WIN
        modifier = "Mod4";

        menu = "${pkgs.rofi}/bin/rofi -show combi";

        terminal = "${pkgs.konsole}/bin/konsole";

        bars = [
          {
            fonts = ["Iosevka 11"];
            position = "top";
            statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs ~/.config/i3status-rust/config-top.toml";
          }
        ];

        keybindings =
          let modifier = config.xsession.windowManager.i3.config.modifier;
          in
          lib.mkOptionDefault {

            "Mod1+space" = "exec ${pkgs.rofi}/bin/rofi -show combi";
            "${modifier}+Mod1+space" = "exec ${pkgs.rofi}/bin/rofi -show emoji";

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

            "Print" = "exec flameshot gui";
            "${modifier}+Shift+s" = "exec flameshot gui";
          };

      };

    };
  };
}
