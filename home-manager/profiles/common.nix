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
    nvim
    starship
    tmux
    zsh
  ];

  config = {

    # Packages to install on all systems
    home.packages = with pkgs; [
      bat
      bottom
      calc
      cifs-utils
      dnsutils
      fastfetch # Commented out because it causes the build to fail (something is broken)
      gdb
      gitui
      glances
      gping
      httpie
      lldb
      man-pages
      man-pages-posix
      nix-init
      nix-top
      nix-tree
      openssl
      restic
      rsync
      tldr
      tree
      smartmontools
      srm
      sshfs
      s-tui
      sysz
      tokei
      unzip
      wireguard-tools

      mayniklas.gen-module # create a new module with a template
      mayniklas.mtu-check # MTU of a network
      mayniklas.vs-fix # fix for vscode remote SSH (replaces the node binary with a symlink into the nix store)
    ] ++ lib.optionals (system-config.nixpkgs.hostPlatform.system == "x86_64-linux") [ ];

    # Programs to install on all systems
    programs = {
      zoxide.enable = true;
    };

    lmh01.programs = {
      direnv.enable = true;
      nvim.enable = true;
      starship.enable = true;
    };

    # Services to start on all systems
    services = { };

    # Home-manager nixpkgs config
    nixpkgs = {
      # Allow "unfree" licenced packages
      config = { 
        allowUnfree = true; 
        permittedInsecurePackages = [ "electron-25.9.0" ];
      };
      overlays = [
        flake-self.overlays.default
        flake-self.inputs.bonn-mensa.overlays.default
        flake-self.inputs.mayniklas.overlays.mayniklas
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
