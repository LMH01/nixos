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
      feh
      flameshot
      i3lock
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

        defaultWorkspace = "workspace number 1";

        bars = [
          {
            fonts = ["FontAwesome 11"];
            position = "top";
            statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs ~/.config/i3status-rust/config-top.toml";
          }
        ];

        startup = [
          {
            # TODO Currently the wallpaper has to be copied to that location manually, 
            # it would be a good idea to create a package that sets the wallpaper automatically.
            # Then the image file could also be moved into that package
            command = "${pkgs.feh}/bin/feh --bg-fill ~/.wallpaper.png .wallpaper.png"; 
            always = false;
            notification = false;
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

            "${modifier}+l" = "exec i3lock -i ~/.wallpaper.png";
          };

      };

    };
  };
}
