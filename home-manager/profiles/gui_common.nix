# Shared stuff for all my systems that use a graphical user interface (= my laptop and desktop systems)
{ lib, pkgs, flake-self, config, system-config, ... }:
with lib;
{

  imports = with flake-self.homeManagerModules; [
    ctf-tools
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
      bonn-mensa
      discord
      dracula-theme
      fira-code
      firefox
      font-awesome
      gimp
      kdePackages.kate
      kdePackages.kleopatra
      mongodb-compass
      obsidian
      openvpn
      postman
      pympress
      qmk
      screen-message
      signal-desktop
      thunderbird
      vial
      vlc
      xclip

      mayniklas.set-performance

      #lmh01.alpha_tui
      #(pkgs.callPackage ../../pkgs/alpha_tui {})
    ] ++ lib.optionals (system-config.nixpkgs.hostPlatform.system == "x86_64-linux") [ ];

    # Programs to install on all desktop systems
    programs = { };

    # Services to enable on all systems
    services = {
      flameshot.enable = true;
    };

    lmh01.ctf-tools.enable = true;
    lmh01.programs = {
      i3.enable = true;
      latex.enable = true;
      rust.enable = true;
      #sway.enable = true; currently a WIP
    };
  };

}
