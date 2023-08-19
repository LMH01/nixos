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
      bottom
      fastfetch
      firefox
      font-awesome
      gitui
      hashcat
      kate
      neofetch
      nvtop
      signal-desktop
      tldr
      tree
      unzip
      xclip
    ];

    programs = {
      starship.enable = true;
      zoxide.enable = true;
    };

    services = {
      flameshot.enable = true;
    };

  };

}
