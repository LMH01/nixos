# Base stuff that should be setup the same on all my systems
{ lib, pkgs, flake-self, config, system-config, ... }:
with lib;
{

  options.lmh01.options = {
    type = mkOption {
      type = types.enum [ "desktop" "laptop" "server" ];
      default = system-config.lmh01.options.type;
      example = "server";
    };
  };

  imports = with flake-self.homeManagerModules; [
    direnv
    git
    zsh
  ];

  config = {

    # Packages to install on all systems
    home.packages = with pkgs; [
      bottom
      fastfetch
      gdb
      gitui
      lldb
      man-pages
      man-pages-posix
      restic
      tldr
      tree
      unzip
    ] ++ lib.optionals (system-config.nixpkgs.hostPlatform.system == "x86_64-linux") [ ];

    # Programs to install on all systems
    programs = {
      starship.enable = true;
      zoxide.enable = true;
    };
    
    lmh01.programs = {
      direnv.enable = true;
    };

    # Services to start on all systems
    services = { };

    # Home-manager nixpkgs config
    nixpkgs = {
      # Allow "unfree" licenced packages
      config = { allowUnfree = true; };
      overlays = [
        # our packages
        flake-self.overlays.default
      ];
    };

    # Include man-pages
    manual.manpages.enable = true;

    home = {
      # This value determines the Home Manager release that your
      # configuration is compatible with. This helps avoid breakage
      # when a new Home Manager release introduces backwards
      # incompatible changes.
      #
      # You can update Home Manager without changing this value. See
      # the Home Manager release notes for a list of state version
      # changes in each release.
      stateVersion = "23.11";
    };

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;

  };

}
