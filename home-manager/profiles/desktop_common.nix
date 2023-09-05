# This file contains stuff that should be setup the same on all my desktop systems
{ lib, pkgs, flake-self, config, system-config, ... }:
with lib;
{

  imports = with flake-self.homeManagerModules; [
    vscode
    latex
  ];

  config = {

    # Packages to install on all desktop systems
    home.packages = with pkgs; [
      _1password-gui
      alacritty
      beauty-line-icon-theme
      discord
      dracula-theme
      firefox
      font-awesome
      kate
      obsidian
      signal-desktop
      xclip
    ] ++ lib.optionals (system-config.nixpkgs.hostPlatform.system == "x86_64-linux") [ ];

    # Programs to install on all desktop systems
    programs = { };

    # Services to enable on all systems
    services = {
      flameshot.enable = true;
      syncthing.enable = true;
    };

    lmh01.programs = {
      latex.enable = true;
    };
  };

}
