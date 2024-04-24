{ lib, pkgs, config, flake-self, ... }:
with lib;
let
  cfg = config.lmh01.programs.i3;
  suspend-pc = pkgs.writeShellScriptBin "suspend-pc" /* sh */
    ''
      i3lock -i ${./wallpaper.png} && systemctl suspend
    '';
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
      suspend-pc
    ]
    ++ lib.optionals (config.lmh01.options.type == "desktop") [ ]
    ++ lib.optionals (config.lmh01.options.type == "laptop") [ ];

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

      config = rec{
        # Set modifier to WIN
        modifier = "Mod4";

        menu = "${pkgs.rofi}/bin/rofi -show combi";

        terminal = "${pkgs.konsole}/bin/konsole";

        defaultWorkspace = "workspace number 1";

        bars = [
          {
            fonts = {
              names = [ "FontAwesome" ];
              size = 11.0;
            };
            position = "top";
            statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs ~/.config/i3status-rust/config-top.toml";
          }
        ];

        startup = [
          {
            command = "${pkgs.feh}/bin/feh --bg-fill ${./wallpaper.png}";
            always = false;
            notification = false;
          }
        ];

        keybindings = lib.mkOptionDefault (
          (lib.attrsets.mergeAttrsList [

            # general keybindings not specific to laptop or desktop
            (lib.optionalAttrs true {
                                           
              "Mod1+space" = "exec ${pkgs.rofi}/bin/rofi -show combi";
              "${modifier}+Mod1+space" = "exec ${pkgs.rofi}/bin/rofi -show emoji";
              "${modifier}+Shift+x" = "kill";

              "${modifier}+Shift+Tab" = "workspace prev";
              "${modifier}+Tab" = "workspace next";

              # keybindings for split keyboard
              "${modifier}+space" = "exec ${pkgs.rofi}/bin/rofi -show combi";
              "${modifier}+Escape" = "kill";
              "${modifier}+BackSpace" = "exec ${terminal}";

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
              "${modifier}+Shift+s" = "exec ${pkgs.flameshot}/bin/flameshot gui";

              "${modifier}+l" = "exec i3lock -i ${./wallpaper.png}";

            })

            # desktop specific keybindings
            (lib.optionalAttrs (config.lmh01.options.type == "desktop") { })

            # laptop specific keybindings
            (lib.optionalAttrs (config.lmh01.options.type == "laptop") {
              "XF86MonBrightnessUp" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
              "XF86MonBrightnessDown" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
            })

          ])
        );

      };

    };
  };
}
