{ lib, pkgs, flake-self, config, system-config, ... }:
with lib;
{

  imports = with flake-self.homeManagerModules; [
    vscode
  ];

  config = {

    home.packages = with pkgs; [
      _1password-gui
      alacritty
      discord
      dracula-theme
      beauty-line-icon-theme
      firefox
      font-awesome
      hashcat
      kate
      neofetch
      signal-desktop
      xclip
    ] ++ lib.optionals (system-config.nixpkgs.hostPlatform.system == "x86_64-linux") [ ];

    programs = {

    };

    services = {
      flameshot.enable = true;
    };

  };

}
