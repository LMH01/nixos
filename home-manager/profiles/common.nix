{ lib, pkgs, flake-self, config, ... }:
with lib;
{

  imports = with flake-self.homeManagerModules; [
    git
    zsh
  ];

  config = {

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
