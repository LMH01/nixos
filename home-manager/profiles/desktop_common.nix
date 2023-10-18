# This file contains stuff that should be setup the same on all my desktop systems
{ lib, pkgs, flake-self, config, system-config, ... }:
with lib;
{

  imports = with flake-self.homeManagerModules; [
    i3
    latex
    rust
    sway
    vscode
  ];

  config = {

    # Packages to install on all desktop systems
    home.packages = with pkgs; [
      _1password-gui
      alacritty
      anki
      beauty-line-icon-theme
      discord
      dracula-theme
      firefox
      fira-code
      font-awesome
      kate
      obsidian
      signal-desktop
      xclip
      #(pkgs.callPackage ../../pkgs/alpha_tui {})
    ] ++ lib.optionals (system-config.nixpkgs.hostPlatform.system == "x86_64-linux") [ ];

    # Programs to install on all desktop systems
    programs = { };

    # Services to enable on all systems
    services = {
      flameshot.enable = true;
      syncthing.enable = true;
    };

    lmh01.programs = {
      i3.enable = true;
      latex.enable = true;
      rust.enable = true;
      #sway.enable = true;
    };
  };

}
